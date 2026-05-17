import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:delta_erp/features/license/data/license_store.dart';
import 'package:delta_erp/features/license/domain/license_models.dart';
import 'package:delta_erp/features/license/domain/machine_fingerprint_service.dart';

class LicenseService {
  LicenseService(this._store, this._fingerprintService);

  final LicenseStore _store;
  final MachineFingerprintService _fingerprintService;

  // Replace this value with your real Ed25519 public key bytes encoded as base64.
  static const String _publicKeyBase64 =
      'mHRMbrPrkEEgifT0lhYEmsc2dG1KasEm5Mhlj55sX98=';

  static const Duration _allowedClockRollback = Duration(minutes: 5);
  static const Duration _gracePeriodAfterExpiry = Duration(days: 7);
  static const Duration _trialDuration = Duration(days: 3);
  static const String _trialProofPepper =
      'clothes_inventory_trial_proof_v1_local_pepper';

  Future<String> getMachineCode() => _fingerprintService.getMachineCode();

  Future<String> getMachineHash() => _fingerprintService.getMachineHash();

  Future<List<LicenseActivationLogEntry>> getRecentActivationLogs() async {
    final List<String> rawLogs = await _store.loadActivationLogsRaw();
    final List<LicenseActivationLogEntry> parsed =
        <LicenseActivationLogEntry>[];
    for (final raw in rawLogs) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        parsed.add(LicenseActivationLogEntry.fromJson(map));
      } catch (_) {
        // Ignore malformed historical entries.
      }
    }
    return parsed;
  }

  Future<LicenseValidationResult> validateCurrentLicense() async {
    final String? raw = await _store.loadRawLicense();
    if (raw == null || raw.trim().isEmpty) {
      return _validateTrial();
    }

    final LicenseValidationResult envelopeResult = await _validateEnvelope(raw);
    if (_shouldFallbackToTrial(envelopeResult)) {
      final DateTime? trialStartedAt = await _store.loadTrialStartedAtUtc();
      if (trialStartedAt == null) {
        await _store.clearLicense();
        return _validateTrial();
      }
    }

    return envelopeResult;
  }

  bool _shouldFallbackToTrial(LicenseValidationResult result) {
    if (result.isValid) {
      return false;
    }

    return result.code == 'invalid_format' ||
        result.code == 'signature_invalid';
  }

  Future<LicenseValidationResult> checkWritePermission() async {
    final LicenseValidationResult result = await validateCurrentLicense();
    if (!result.isValid) {
      return result;
    }

    if (result.isReadOnly) {
      return LicenseValidationResult(
        isValid: false,
        code: 'read_only_mode',
        payload: result.payload,
        message: result.readOnlyReason ?? 'License is in read-only mode.',
        isReadOnly: true,
        readOnlyReason: result.readOnlyReason,
        graceDaysLeft: result.graceDaysLeft,
      );
    }

    return result;
  }

  Future<LicenseValidationResult> activateFromCode(
    String activationCode,
  ) async {
    final LicenseValidationResult result = await _validateEnvelope(
      activationCode,
    );
    await _recordActivationAttempt(result);
    if (!result.isValid) {
      return result;
    }

    await _store.saveRawLicense(activationCode.trim());
    await _store.saveLastTrustedTimeUtc(DateTime.now().toUtc());
    return result;
  }

  Future<void> _recordActivationAttempt(LicenseValidationResult result) {
    final entry = LicenseActivationLogEntry(
      at: DateTime.now().toUtc(),
      success: result.isValid,
      code: result.code,
      message: result.message,
    );
    return _store.appendActivationLogRaw(jsonEncode(entry.toJson()));
  }

  Future<void> clearLicense() => _store.clearLicense();

  Future<LicenseValidationResult> _validateEnvelope(String raw) async {
    try {
      final LicenseEnvelope envelope = LicenseEnvelope.decode(raw.trim());
      if (envelope.version != 1) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'version_not_supported',
          message: 'Unsupported license format version.',
        );
      }

      final List<int> payloadBytes = base64Decode(envelope.payloadBase64);
      final List<int> signatureBytes = base64Decode(envelope.signatureBase64);

      final bool signatureOk = await _verifySignature(
        payloadBytes,
        signatureBytes,
      );
      if (!signatureOk) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'signature_invalid',
          message: 'License signature is invalid.',
        );
      }

      final Map<String, dynamic> payloadJson =
          jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final LicensePayload payload = LicensePayload.fromJson(payloadJson);

      final String currentMachineHash = await _fingerprintService
          .getMachineHash();
      if (payload.machineHash != currentMachineHash) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'machine_mismatch',
          message: 'License is not valid on this device.',
        );
      }

      final DateTime nowUtc = DateTime.now().toUtc();
      final DateTime? lastTrusted = await _store.loadLastTrustedTimeUtc();
      if (lastTrusted != null &&
          nowUtc.isBefore(lastTrusted.subtract(_allowedClockRollback))) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'clock_rollback',
          message: 'Device time rollback detected.',
        );
      }

      final DateTime expiryUtc = payload.expiresAt.toUtc();
      if (nowUtc.isAfter(expiryUtc)) {
        final DateTime graceEndsAt = expiryUtc.add(_gracePeriodAfterExpiry);
        if (nowUtc.isBefore(graceEndsAt) ||
            nowUtc.isAtSameMomentAs(graceEndsAt)) {
          final int daysLeft = graceEndsAt.difference(nowUtc).inDays;
          return LicenseValidationResult(
            isValid: true,
            code: 'grace_read_only',
            payload: payload,
            isReadOnly: true,
            graceDaysLeft: daysLeft,
            readOnlyReason:
                'License expired. Write operations are disabled during grace period.',
            message: 'License expired. App is running in read-only mode.',
          );
        }

        return const LicenseValidationResult(
          isValid: false,
          code: 'license_expired',
          message: 'License expired.',
        );
      }

      if (lastTrusted == null || nowUtc.isAfter(lastTrusted)) {
        await _store.saveLastTrustedTimeUtc(nowUtc);
      }

      return LicenseValidationResult(
        isValid: true,
        code: 'ok',
        payload: payload,
      );
    } catch (e) {
      debugPrint('License validation error: $e');
      return const LicenseValidationResult(
        isValid: false,
        code: 'invalid_format',
        message: 'Invalid activation code format.',
      );
    }
  }

  Future<LicenseValidationResult> _validateTrial() async {
    try {
      final bool isTrialLocked = await _store.loadTrialLocked();
      if (isTrialLocked) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'trial_locked',
          isTrial: true,
          message: 'Trial is locked. Please activate your license.',
        );
      }

      final DateTime nowUtc = DateTime.now().toUtc();
      final DateTime? lastTrusted = await _store.loadLastTrustedTimeUtc();
      if (lastTrusted != null &&
          nowUtc.isBefore(lastTrusted.subtract(_allowedClockRollback))) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'clock_rollback',
          message: 'Device time rollback detected.',
        );
      }

      final DateTime trialStartUtc = await _store.ensureTrialStartedAtUtc();
      if (trialStartUtc.isAfter(nowUtc.add(_allowedClockRollback))) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'trial_tampered',
          message: 'Trial metadata appears to be tampered.',
        );
      }

      final String machineHash = await _fingerprintService.getMachineHash();
      final String expectedProof = _buildTrialProof(
        trialStartUtc: trialStartUtc,
        machineHash: machineHash,
      );
      final String? storedProof = await _store.loadTrialProof();
      if (storedProof == '__CONFLICT__') {
        return const LicenseValidationResult(
          isValid: false,
          code: 'trial_tampered',
          message: 'Trial metadata conflict detected.',
        );
      }
      if (storedProof == null) {
        await _store.saveTrialProof(expectedProof);
      } else if (storedProof != expectedProof) {
        return const LicenseValidationResult(
          isValid: false,
          code: 'trial_tampered',
          message: 'Trial proof mismatch detected.',
        );
      }

      final DateTime trialEndsAt = trialStartUtc.add(_trialDuration);
      final bool isExpired = nowUtc.isAfter(trialEndsAt);

      if (!isExpired) {
        final int daysLeft = trialEndsAt.difference(nowUtc).inDays;
        if (lastTrusted == null || nowUtc.isAfter(lastTrusted)) {
          await _store.saveLastTrustedTimeUtc(nowUtc);
        }
        return LicenseValidationResult(
          isValid: true,
          code: 'trial_active',
          isTrial: true,
          trialDaysLeft: daysLeft,
          trialEndsAt: trialEndsAt,
          message: 'Free trial is active.',
        );
      }

      await _store.saveTrialLocked(true);
      return LicenseValidationResult(
        isValid: false,
        code: 'trial_expired',
        isTrial: true,
        trialDaysLeft: 0,
        trialEndsAt: trialEndsAt,
        message: 'Free trial expired. Please activate your license.',
      );
    } catch (e) {
      debugPrint('Trial validation error: $e');
      return const LicenseValidationResult(
        isValid: false,
        code: 'trial_error',
        message: 'Unable to validate trial status.',
      );
    }
  }

  String _buildTrialProof({
    required DateTime trialStartUtc,
    required String machineHash,
  }) {
    final String source =
        '${trialStartUtc.toIso8601String()}|$machineHash|$_trialProofPepper';
    final List<int> bytes = utf8.encode(source);
    return base64Encode(sha256.convert(bytes).bytes);
  }

  Future<bool> _verifySignature(List<int> payload, List<int> signature) async {
    final Ed25519 algorithm = Ed25519();
    final List<int> publicKeyBytes = base64Decode(_publicKeyBase64);
    final SimplePublicKey publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );

    return algorithm.verify(
      payload,
      signature: Signature(signature, publicKey: publicKey),
    );
  }
}
