import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as path;

import 'package:clothes_inventory/core/utils/app_paths.dart';
import 'package:clothes_inventory/features/purchase_ocr/data/ocr_logger.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_models.dart';

abstract class PurchaseOcrService {
  Future<String> extractText({required String imagePath});
  Map<String, bool> debugHealthCheck();
  Future<String> getTesseractVersion();
  OcrFailure? getLastFailure();
  void markFingerprintResolved(String fingerprint);
  String getFingerprintResolutionStatus(String fingerprint);
  String getLastFailureResolutionStatus();
  void resetFingerprintCount(String fingerprint);
  Map<String, int> getFingerprintOccurrenceSnapshot();
  Map<String, bool> getFingerprintResolutionSnapshot();
  Map<String, OcrFailure> getFingerprintLastFailureSnapshot();
}

enum OcrFailureCategory { missingFiles, executionFailed, invalidOutput }

extension OcrFailureCategoryX on OcrFailureCategory {
  String get label {
    switch (this) {
      case OcrFailureCategory.missingFiles:
        return 'missing_files';
      case OcrFailureCategory.executionFailed:
        return 'execution_failed';
      case OcrFailureCategory.invalidOutput:
        return 'invalid_output';
    }
  }
}

class OcrFailure implements Exception {
  const OcrFailure({
    required this.userMessage,
    required this.debugMessage,
    required this.category,
    this.type = OcrErrorType.unknown,
    required this.errorCode,
    required this.severity,
    required this.errorFingerprint,
  });

  final String userMessage;
  final String debugMessage;
  final OcrFailureCategory category;
  final OcrErrorType type;
  final String errorCode;
  final OcrErrorSeverity severity;
  final String errorFingerprint;

  @Deprecated('Use errorCode instead.')
  String get code => errorCode;

  String get message => userMessage;
  String get debugDetails => debugMessage;

  @override
  String toString() => userMessage;
}

class OfflinePurchaseOcrService implements PurchaseOcrService {
  OfflinePurchaseOcrService({OcrLogger? logger})
    : _logger = logger ?? const OcrLogger();

  static const _friendlyFailureMessage =
      'Unable to scan invoice. You can still enter it manually.';
  static const _windowsOcrTimeout = Duration(seconds: 20);

  final OcrLogger _logger;
  OcrFailure? _lastFailure;
  final Map<String, bool> _resolvedFingerprintStatus = {};
  final Map<String, int> _fingerprintOccurrenceCount = {};
  final Map<String, OcrFailure> _lastFailureByFingerprint = {};

  @override
  Future<String> extractText({required String imagePath}) async {
    try {
      final String extractedText;
      if (kIsWeb) {
        throw OcrFailure(
          userMessage: _friendlyFailureMessage,
          debugMessage: 'OCR requested on web build.',
          category: OcrFailureCategory.executionFailed,
          type: OcrErrorType.unknown,
          errorCode: 'OCR_999',
          severity: OcrErrorSeverity.medium,
          errorFingerprint: _buildFingerprint(
            type: OcrErrorType.unknown,
            errorCode: OcrErrorType.unknown.stableCode,
            stage: 'runtime',
            imagePath: imagePath,
            fallbackContext: 'platform_web',
          ),
        );
      }

      if (Platform.isAndroid || Platform.isIOS) {
        extractedText = await _extractWithMlKit(imagePath);
        _markLastFailureResolvedAfterSuccess();
        return extractedText;
      }

      if (Platform.isWindows) {
        extractedText = await _extractWithEmbeddedWindowsTesseract(imagePath);
        _markLastFailureResolvedAfterSuccess();
        return extractedText;
      }

      if (Platform.isLinux || Platform.isMacOS) {
        throw OcrFailure(
          userMessage: _friendlyFailureMessage,
          debugMessage: 'OCR desktop bundle is supported on Windows only.',
          category: OcrFailureCategory.executionFailed,
          type: OcrErrorType.unknown,
          errorCode: 'OCR_999',
          severity: OcrErrorSeverity.medium,
          errorFingerprint: _buildFingerprint(
            type: OcrErrorType.unknown,
            errorCode: OcrErrorType.unknown.stableCode,
            stage: 'runtime',
            imagePath: imagePath,
            fallbackContext: 'platform_desktop_unsupported',
          ),
        );
      }

      throw OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage: 'OCR requested on unsupported platform.',
        category: OcrFailureCategory.executionFailed,
        type: OcrErrorType.unknown,
        errorCode: 'OCR_999',
        severity: OcrErrorSeverity.medium,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.unknown,
          errorCode: OcrErrorType.unknown.stableCode,
          stage: 'runtime',
          imagePath: imagePath,
          fallbackContext: 'platform_unsupported',
        ),
      );
    } on OcrFailure catch (failure) {
      _setLastFailure(failure);
      unawaited(_logFailure(failure: failure, imagePath: imagePath));
      rethrow;
    } catch (error) {
      _debugLog('Unexpected OCR failure: $error');
      final failure = OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage: error.toString(),
        category: OcrFailureCategory.executionFailed,
        type: OcrErrorType.unknown,
        errorCode: OcrErrorType.unknown.stableCode,
        severity: OcrErrorType.unknown.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.unknown,
          errorCode: OcrErrorType.unknown.stableCode,
          stage: 'runtime',
          imagePath: imagePath,
          fallbackContext: 'unhandled_exception',
        ),
      );
      _setLastFailure(failure);
      unawaited(_logFailure(failure: failure, imagePath: imagePath));
      throw failure;
    }
  }

  @override
  OcrFailure? getLastFailure() => _lastFailure;

  @override
  void markFingerprintResolved(String fingerprint) {
    if (fingerprint.trim().isEmpty) return;
    _resolvedFingerprintStatus[fingerprint] = true;
  }

  @override
  String getFingerprintResolutionStatus(String fingerprint) {
    if (fingerprint.trim().isEmpty) return 'unresolved';
    final isResolved = _resolvedFingerprintStatus[fingerprint] ?? false;
    return isResolved ? 'resolved' : 'unresolved';
  }

  @override
  String getLastFailureResolutionStatus() {
    final failure = _lastFailure;
    if (failure == null) {
      return 'unresolved';
    }
    return getFingerprintResolutionStatus(failure.errorFingerprint);
  }

  @override
  void resetFingerprintCount(String fingerprint) {
    if (fingerprint.trim().isEmpty) return;
    _fingerprintOccurrenceCount.remove(fingerprint);
  }

  @override
  Map<String, int> getFingerprintOccurrenceSnapshot() {
    return Map<String, int>.unmodifiable(
      Map<String, int>.from(_fingerprintOccurrenceCount),
    );
  }

  @override
  Map<String, bool> getFingerprintResolutionSnapshot() {
    return Map<String, bool>.unmodifiable(
      Map<String, bool>.from(_resolvedFingerprintStatus),
    );
  }

  @override
  Map<String, OcrFailure> getFingerprintLastFailureSnapshot() {
    return Map<String, OcrFailure>.unmodifiable(
      Map<String, OcrFailure>.from(_lastFailureByFingerprint),
    );
  }

  @override
  Map<String, bool> debugHealthCheck() {
    if (!Platform.isWindows) {
      return {
        'tesseract_exists': false,
        'tessdata_exists': false,
        'eng_traineddata': false,
        'ara_traineddata': false,
      };
    }

    final paths = _resolveWindowsOcrPaths();
    return {
      'tesseract_exists': File(paths.tesseractPath).existsSync(),
      'tessdata_exists': Directory(paths.tessdataDirPath).existsSync(),
      'eng_traineddata': File(
        path.join(paths.tessdataDirPath, 'eng.traineddata'),
      ).existsSync(),
      'ara_traineddata': File(
        path.join(paths.tessdataDirPath, 'ara.traineddata'),
      ).existsSync(),
    };
  }

  @override
  Future<String> getTesseractVersion() async {
    if (!Platform.isWindows) {
      return 'Tesseract version check is supported on Windows only.';
    }

    final paths = _resolveWindowsOcrPaths();
    final result = await Process.run(paths.tesseractPath, const [
      '--version',
    ], workingDirectory: paths.ocrDirPath);

    final stdoutText = result.stdout.toString().trim();
    final stderrText = result.stderr.toString().trim();

    if (stdoutText.isNotEmpty) {
      return stdoutText;
    }
    if (stderrText.isNotEmpty) {
      return stderrText;
    }
    return 'No version output returned.';
  }

  Future<String> _extractWithMlKit(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await textRecognizer.processImage(inputImage);
      final text = result.text.trim();

      if (text.isEmpty) {
        throw OcrFailure(
          userMessage: _friendlyFailureMessage,
          debugMessage: 'ML Kit returned empty text.',
          category: OcrFailureCategory.invalidOutput,
          type: OcrErrorType.emptyResult,
          errorCode: 'OCR_006',
          severity: OcrErrorSeverity.medium,
          errorFingerprint: _buildFingerprint(
            type: OcrErrorType.emptyResult,
            errorCode: OcrErrorType.emptyResult.stableCode,
            stage: 'parser',
            imagePath: imagePath,
            fallbackContext: 'mlkit_empty',
          ),
        );
      }

      return text;
    } on OcrFailure {
      rethrow;
    } catch (error) {
      _debugLog('ML Kit OCR error: $error');
      throw OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage: error.toString(),
        category: OcrFailureCategory.executionFailed,
        type: OcrErrorType.unknown,
        errorCode: OcrErrorType.unknown.stableCode,
        severity: OcrErrorType.unknown.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.unknown,
          errorCode: OcrErrorType.unknown.stableCode,
          stage: 'runtime',
          imagePath: imagePath,
          fallbackContext: 'mlkit_exception',
        ),
      );
    } finally {
      textRecognizer.close();
    }
  }

  Future<String> _extractWithEmbeddedWindowsTesseract(String imagePath) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage: 'Image file missing: $imagePath',
        category: OcrFailureCategory.invalidOutput,
        type: OcrErrorType.invalidImage,
        errorCode: OcrErrorType.invalidImage.stableCode,
        severity: OcrErrorType.invalidImage.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.invalidImage,
          errorCode: OcrErrorType.invalidImage.stableCode,
          stage: 'preflight',
          imagePath: imagePath,
          fallbackContext: 'image_missing',
        ),
      );
    }

    final paths = _resolveWindowsOcrPaths();
    _debugLog('OCR base dir: ${paths.baseDirPath}');
    _debugLog('OCR directory: ${paths.ocrDirPath}');
    _debugLog('OCR executable path: ${paths.tesseractPath}');
    _debugLog('OCR tessdata path: ${paths.tessdataDirPath}');

    await _validateWindowsBundle(paths);

    final preparedImagePath = await _prepareImageForWindowsOcr(imagePath);

    try {
      final stopwatch = Stopwatch()..start();
      final result = await Process.run(
        paths.tesseractPath,
        [
          preparedImagePath,
          'stdout',
          '--tessdata-dir',
          paths.tessdataDirPath,
          '-l',
          'eng+ara',
        ],
        workingDirectory: paths.ocrDirPath,
        stdoutEncoding: null,
        stderrEncoding: null,
      ).timeout(_windowsOcrTimeout);
      stopwatch.stop();
      _debugLog('OCR execution duration: ${stopwatch.elapsedMilliseconds}ms');

      final stderrText = _decodeProcessText(result.stderr).trim();
      if (stderrText.isNotEmpty) {
        _debugLog('OCR stderr: $stderrText');
      }

      if (result.exitCode != 0) {
        _debugLog('OCR exit code: ${result.exitCode}');

        final lower = stderrText.toLowerCase();
        if (lower.contains('error opening data file') ||
            lower.contains('failed loading language')) {
          throw OcrFailure(
            userMessage: _friendlyFailureMessage,
            debugMessage: stderrText.isEmpty
                ? 'Tesseract language data could not be loaded.'
                : stderrText,
            category: OcrFailureCategory.missingFiles,
            type: OcrErrorType.missingLanguageData,
            errorCode: OcrErrorType.missingLanguageData.stableCode,
            severity: OcrErrorType.missingLanguageData.severity,
            errorFingerprint: _buildFingerprint(
              type: OcrErrorType.missingLanguageData,
              errorCode: OcrErrorType.missingLanguageData.stableCode,
              stage: 'runtime',
              imagePath: preparedImagePath,
              fallbackContext: 'language_load_failed',
            ),
          );
        }
        if (lower.contains('cannot read input file') ||
            lower.contains('image file')) {
          throw OcrFailure(
            userMessage: _friendlyFailureMessage,
            debugMessage: stderrText.isEmpty
                ? 'Tesseract cannot read image.'
                : stderrText,
            category: OcrFailureCategory.invalidOutput,
            type: OcrErrorType.invalidImage,
            errorCode: OcrErrorType.invalidImage.stableCode,
            severity: OcrErrorType.invalidImage.severity,
            errorFingerprint: _buildFingerprint(
              type: OcrErrorType.invalidImage,
              errorCode: OcrErrorType.invalidImage.stableCode,
              stage: 'runtime',
              imagePath: preparedImagePath,
              fallbackContext: 'image_read_failed',
            ),
          );
        }

        throw OcrFailure(
          userMessage: _friendlyFailureMessage,
          debugMessage: stderrText.isEmpty
              ? 'Tesseract failed with exit code.'
              : stderrText,
          category: OcrFailureCategory.executionFailed,
          type: OcrErrorType.processFailed,
          errorCode: OcrErrorType.processFailed.stableCode,
          severity: OcrErrorType.processFailed.severity,
          errorFingerprint: _buildFingerprint(
            type: OcrErrorType.processFailed,
            errorCode: OcrErrorType.processFailed.stableCode,
            stage: 'runtime',
            imagePath: preparedImagePath,
            fallbackContext: 'exit_code',
          ),
        );
      }

      final text = _decodeProcessText(result.stdout).trim();
      _debugLog('OCR output length: ${text.length}');
      if (text.isEmpty) {
        throw OcrFailure(
          userMessage: _friendlyFailureMessage,
          debugMessage: stderrText.isEmpty
              ? 'Tesseract returned empty stdout.'
              : 'Tesseract returned empty stdout. stderr: $stderrText',
          category: OcrFailureCategory.invalidOutput,
          type: OcrErrorType.emptyResult,
          errorCode: OcrErrorType.emptyResult.stableCode,
          severity: OcrErrorType.emptyResult.severity,
          errorFingerprint: _buildFingerprint(
            type: OcrErrorType.emptyResult,
            errorCode: OcrErrorType.emptyResult.stableCode,
            stage: 'parser',
            imagePath: preparedImagePath,
            fallbackContext: 'stdout_empty',
          ),
        );
      }
      if (_looksCorrupted(text)) {
        throw OcrFailure(
          userMessage: _friendlyFailureMessage,
          debugMessage: 'Tesseract stdout contains invalid characters.',
          category: OcrFailureCategory.invalidOutput,
          type: OcrErrorType.processFailed,
          errorCode: 'OCR_004',
          severity: OcrErrorSeverity.high,
          errorFingerprint: _buildFingerprint(
            type: OcrErrorType.processFailed,
            errorCode: OcrErrorType.processFailed.stableCode,
            stage: 'parser',
            imagePath: preparedImagePath,
            fallbackContext: 'stdout_corrupted',
          ),
        );
      }
      return text;
    } on ProcessException catch (error) {
      _debugLog('OCR process exception: $error');
      throw OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage: error.toString(),
        category: OcrFailureCategory.executionFailed,
        type: OcrErrorType.processFailed,
        errorCode: OcrErrorType.processFailed.stableCode,
        severity: OcrErrorType.processFailed.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.processFailed,
          errorCode: OcrErrorType.processFailed.stableCode,
          stage: 'runtime',
          imagePath: preparedImagePath,
          fallbackContext: 'process_exception',
        ),
      );
    } on TimeoutException catch (error) {
      _debugLog('OCR timeout: $error');
      throw OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage:
            'Tesseract timed out after ${_windowsOcrTimeout.inSeconds}s.',
        category: OcrFailureCategory.executionFailed,
        type: OcrErrorType.timeout,
        errorCode: OcrErrorType.timeout.stableCode,
        severity: OcrErrorType.timeout.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.timeout,
          errorCode: OcrErrorType.timeout.stableCode,
          stage: 'runtime',
          imagePath: preparedImagePath,
          fallbackContext: 'timeout',
        ),
      );
    } on OcrFailure {
      rethrow;
    } catch (error) {
      _debugLog('Unhandled OCR exception: $error');
      throw OcrFailure(
        userMessage: _friendlyFailureMessage,
        debugMessage: error.toString(),
        category: OcrFailureCategory.executionFailed,
        type: OcrErrorType.unknown,
        errorCode: OcrErrorType.unknown.stableCode,
        severity: OcrErrorType.unknown.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.unknown,
          errorCode: OcrErrorType.unknown.stableCode,
          stage: 'runtime',
          imagePath: preparedImagePath,
          fallbackContext: 'runtime_unhandled',
        ),
      );
    } finally {
      await _cleanupPreparedImage(preparedImagePath, originalPath: imagePath);
    }
  }

  Future<String> _prepareImageForWindowsOcr(String originalPath) async {
    final source = File(originalPath);
    if (!await source.exists()) {
      return originalPath;
    }

    final ext = path.extension(originalPath).toLowerCase();
    final safeExt = ext.isEmpty ? '.png' : ext;
    final safeName =
        'ocr_input_${DateTime.now().microsecondsSinceEpoch}$safeExt';
    try {
      final tempDir = await AppPaths.getTempDir();
      final targetPath = path.join(tempDir, safeName);
      await source.copy(targetPath);
      return targetPath;
    } catch (error) {
      _debugLog('Failed to prepare OCR temp image in AppData: $error');
      return originalPath;
    }
  }

  Future<void> _cleanupPreparedImage(
    String preparedPath, {
    required String originalPath,
  }) async {
    if (preparedPath == originalPath) return;
    try {
      final file = File(preparedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort cleanup only.
    }
  }

  _WindowsOcrPaths _resolveWindowsOcrPaths() {
    final baseDir = File(Platform.resolvedExecutable).parent.path;
    final ocrPath = path.join(baseDir, 'ocr');
    final tesseractPath = path.join(ocrPath, 'tesseract.exe');
    final tessdataPath = path.join(ocrPath, 'tessdata');
    return _WindowsOcrPaths(
      baseDirPath: baseDir,
      ocrDirPath: ocrPath,
      tesseractPath: tesseractPath,
      tessdataDirPath: tessdataPath,
    );
  }

  Future<void> _validateWindowsBundle(_WindowsOcrPaths paths) async {
    const missingMessage = _friendlyFailureMessage;

    if (!await File(paths.tesseractPath).exists()) {
      _debugLog('OCR missing executable: ${paths.tesseractPath}');
      throw OcrFailure(
        userMessage: missingMessage,
        debugMessage: 'Missing file: ${paths.tesseractPath}',
        category: OcrFailureCategory.missingFiles,
        type: OcrErrorType.missingExecutable,
        errorCode: OcrErrorType.missingExecutable.stableCode,
        severity: OcrErrorType.missingExecutable.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.missingExecutable,
          errorCode: OcrErrorType.missingExecutable.stableCode,
          stage: 'preflight',
          fallbackContext: 'executable_check',
        ),
      );
    }

    if (!await Directory(paths.tessdataDirPath).exists()) {
      _debugLog('OCR missing tessdata directory: ${paths.tessdataDirPath}');
      throw OcrFailure(
        userMessage: missingMessage,
        debugMessage: 'Missing directory: ${paths.tessdataDirPath}',
        category: OcrFailureCategory.missingFiles,
        type: OcrErrorType.missingTessdata,
        errorCode: OcrErrorType.missingTessdata.stableCode,
        severity: OcrErrorType.missingTessdata.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.missingTessdata,
          errorCode: OcrErrorType.missingTessdata.stableCode,
          stage: 'preflight',
          fallbackContext: 'tessdata_check',
        ),
      );
    }

    final engData = File(path.join(paths.tessdataDirPath, 'eng.traineddata'));
    final araData = File(path.join(paths.tessdataDirPath, 'ara.traineddata'));
    final missingLanguageFiles = <String>[];
    if (!await engData.exists()) {
      missingLanguageFiles.add(engData.path);
    }
    if (!await araData.exists()) {
      missingLanguageFiles.add(araData.path);
    }

    if (missingLanguageFiles.isNotEmpty) {
      _debugLog(
        'OCR missing language data: ${missingLanguageFiles.join(', ')}',
      );
      throw OcrFailure(
        userMessage: missingMessage,
        debugMessage: 'Missing files: ${missingLanguageFiles.join(', ')}',
        category: OcrFailureCategory.missingFiles,
        type: OcrErrorType.missingLanguageData,
        errorCode: OcrErrorType.missingLanguageData.stableCode,
        severity: OcrErrorType.missingLanguageData.severity,
        errorFingerprint: _buildFingerprint(
          type: OcrErrorType.missingLanguageData,
          errorCode: OcrErrorType.missingLanguageData.stableCode,
          stage: 'preflight',
          fallbackContext: 'language_data_check',
        ),
      );
    }

    const dlls = [
      'libcurl-4.dll',
      'libgcc_s_seh-1.dll',
      'libstdc++-6.dll',
      'libwinpthread-1.dll',
      'zlib1.dll',
    ];
    final missingDlls = <String>[];
    for (final dll in dlls) {
      final dllPath = path.join(paths.ocrDirPath, dll);
      if (!await File(dllPath).exists()) {
        missingDlls.add(dllPath);
      }
    }
    if (missingDlls.isNotEmpty) {
      _debugLog('OCR missing DLLs (non-blocking): ${missingDlls.join(', ')}');
    }
  }

  Future<String> debugExtractTextFromSample({required String imagePath}) async {
    _debugLog('Running OCR self-test with image: $imagePath');
    final text = await extractText(imagePath: imagePath);
    _debugLog('OCR self-test extracted text length: ${text.length}');
    return text;
  }

  Future<String> debugRunOcr({required String imagePath}) async {
    return debugExtractTextFromSample(imagePath: imagePath);
  }

  Future<void> _logFailure({
    required OcrFailure failure,
    required String? imagePath,
  }) async {
    try {
      await _logger.logOcrFailure(failure, imagePath);
    } catch (error) {
      _debugLog('Failed to write OCR error log: $error');
    }
  }

  void _setLastFailure(OcrFailure failure) {
    _lastFailure = failure;
    // Recurring fingerprints are automatically marked as unresolved again.
    _resolvedFingerprintStatus[failure.errorFingerprint] = false;
    _fingerprintOccurrenceCount[failure.errorFingerprint] =
        (_fingerprintOccurrenceCount[failure.errorFingerprint] ?? 0) + 1;
    _lastFailureByFingerprint[failure.errorFingerprint] = failure;
  }

  void _markLastFailureResolvedAfterSuccess() {
    final failure = _lastFailure;
    if (failure == null) return;
    _resolvedFingerprintStatus[failure.errorFingerprint] = true;
  }

  String _buildFingerprint({
    required OcrErrorType type,
    required String errorCode,
    required String stage,
    String? imagePath,
    String fallbackContext = 'no_image',
  }) {
    final imageContext = _safeImageContext(imagePath, fallbackContext);
    return '$errorCode|${type.name}|$imageContext|$stage';
  }

  String _safeImageContext(String? imagePath, String fallbackContext) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return fallbackContext;
    }
    final name = path.basename(imagePath).trim();
    if (name.isEmpty) {
      return fallbackContext;
    }
    return name;
  }

  String _decodeProcessText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;

    if (value is List<int>) {
      try {
        return utf8.decode(value, allowMalformed: false);
      } catch (_) {
        try {
          return systemEncoding.decode(value);
        } catch (_) {
          return latin1.decode(value);
        }
      }
    }

    return value.toString();
  }

  bool _looksCorrupted(String text) {
    return text.contains('\uFFFD');
  }

  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[OCR] $message');
    }
  }
}

class _WindowsOcrPaths {
  const _WindowsOcrPaths({
    required this.baseDirPath,
    required this.ocrDirPath,
    required this.tesseractPath,
    required this.tessdataDirPath,
  });

  final String baseDirPath;
  final String ocrDirPath;
  final String tesseractPath;
  final String tessdataDirPath;
}

class OcrFingerprintHealthItem {
  const OcrFingerprintHealthItem({
    required this.fingerprint,
    required this.occurrenceCount,
    required this.lastErrorCode,
    required this.severity,
    required this.resolutionStatus,
  });

  final String fingerprint;
  final int occurrenceCount;
  final String lastErrorCode;
  final OcrErrorSeverity severity;
  final String resolutionStatus;
}

class PurchaseOcrObservabilitySnapshot {
  const PurchaseOcrObservabilitySnapshot({
    required this.unresolvedIssues,
    required this.recentlyResolved,
    required this.totalFailures,
    required this.totalResolved,
    required this.unresolvedCount,
    required this.mostFrequentFingerprint,
  });

  final List<OcrFingerprintHealthItem> unresolvedIssues;
  final List<OcrFingerprintHealthItem> recentlyResolved;
  final int totalFailures;
  final int totalResolved;
  final int unresolvedCount;
  final String mostFrequentFingerprint;
}

class PurchaseOcrObservabilityManager {
  const PurchaseOcrObservabilityManager(this._service);

  final PurchaseOcrService _service;

  PurchaseOcrObservabilitySnapshot buildSnapshot() {
    final occurrences = _service.getFingerprintOccurrenceSnapshot();
    final resolutions = _service.getFingerprintResolutionSnapshot();
    final lastFailures = _service.getFingerprintLastFailureSnapshot();

    final allFingerprints = <String>{
      ...occurrences.keys,
      ...resolutions.keys,
      ...lastFailures.keys,
    };

    final unresolved = <OcrFingerprintHealthItem>[];
    final resolved = <OcrFingerprintHealthItem>[];

    for (final fingerprint in allFingerprints) {
      final occurrenceCount = occurrences[fingerprint] ?? 0;
      final isResolved = resolutions[fingerprint] ?? false;
      final failure = lastFailures[fingerprint];

      final item = OcrFingerprintHealthItem(
        fingerprint: fingerprint,
        occurrenceCount: occurrenceCount,
        lastErrorCode: failure?.errorCode ?? OcrErrorType.unknown.stableCode,
        severity: failure?.severity ?? OcrErrorType.unknown.severity,
        resolutionStatus: isResolved ? 'resolved' : 'unresolved',
      );

      if (isResolved) {
        resolved.add(item);
      } else if (occurrenceCount > 0) {
        unresolved.add(item);
      }
    }

    unresolved.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
    resolved.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));

    final totalFailures = occurrences.values.fold<int>(0, (sum, c) => sum + c);
    final totalResolved = resolved.length;
    final unresolvedCount = unresolved.length;
    final mostFrequentFingerprint = occurrences.entries.isEmpty
        ? 'n/a'
        : (occurrences.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

    return PurchaseOcrObservabilitySnapshot(
      unresolvedIssues: unresolved,
      recentlyResolved: resolved,
      totalFailures: totalFailures,
      totalResolved: totalResolved,
      unresolvedCount: unresolvedCount,
      mostFrequentFingerprint: mostFrequentFingerprint,
    );
  }

  void markResolved(String fingerprint) {
    _service.markFingerprintResolved(fingerprint);
  }

  void resetCount(String fingerprint) {
    _service.resetFingerprintCount(fingerprint);
  }
}
