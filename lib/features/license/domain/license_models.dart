import 'dart:convert';

class LicensePayload {
  const LicensePayload({
    required this.licenseId,
    required this.customerName,
    required this.issuedAt,
    required this.expiresAt,
    required this.machineHash,
    required this.features,
    required this.maxTransfersPerYear,
    required this.appVersionMin,
  });

  final String licenseId;
  final String customerName;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String machineHash;
  final List<String> features;
  final int maxTransfersPerYear;
  final String appVersionMin;

  factory LicensePayload.fromJson(Map<String, dynamic> json) {
    return LicensePayload(
      licenseId: json['licenseId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      machineHash: json['machineHash'] as String? ?? '',
      features: (json['features'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      maxTransfersPerYear: json['maxTransfersPerYear'] as int? ?? 0,
      appVersionMin: json['appVersionMin'] as String? ?? '1.0.0',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'licenseId': licenseId,
      'customerName': customerName,
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'machineHash': machineHash,
      'features': features,
      'maxTransfersPerYear': maxTransfersPerYear,
      'appVersionMin': appVersionMin,
    };
  }
}

class LicenseEnvelope {
  const LicenseEnvelope({
    required this.version,
    required this.payloadBase64,
    required this.signatureBase64,
  });

  final int version;
  final String payloadBase64;
  final String signatureBase64;

  factory LicenseEnvelope.fromJson(Map<String, dynamic> json) {
    return LicenseEnvelope(
      version: json['version'] as int? ?? 1,
      payloadBase64: json['payload'] as String? ?? '',
      signatureBase64: json['signature'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'payload': payloadBase64,
      'signature': signatureBase64,
    };
  }

  String encode() => jsonEncode(toJson());

  static LicenseEnvelope decode(String raw) {
    final dynamic map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('Invalid activation envelope');
    }
    return LicenseEnvelope.fromJson(map);
  }
}

enum LicenseState { checking, active, inactive }

class LicenseValidationResult {
  const LicenseValidationResult({
    required this.isValid,
    required this.code,
    this.isReadOnly = false,
    this.readOnlyReason,
    this.graceDaysLeft,
    this.isTrial = false,
    this.trialDaysLeft,
    this.trialEndsAt,
    this.payload,
    this.message,
  });

  final bool isValid;
  final String code;
  final bool isReadOnly;
  final String? readOnlyReason;
  final int? graceDaysLeft;
  final bool isTrial;
  final int? trialDaysLeft;
  final DateTime? trialEndsAt;
  final LicensePayload? payload;
  final String? message;
}

class LicenseActivationLogEntry {
  const LicenseActivationLogEntry({
    required this.at,
    required this.success,
    required this.code,
    this.message,
  });

  final DateTime at;
  final bool success;
  final String code;
  final String? message;

  factory LicenseActivationLogEntry.fromJson(Map<String, dynamic> json) {
    return LicenseActivationLogEntry(
      at: DateTime.parse(json['at'] as String),
      success: json['success'] as bool? ?? false,
      code: json['code'] as String? ?? 'unknown',
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'at': at.toUtc().toIso8601String(),
      'success': success,
      'code': code,
      'message': message,
    };
  }
}
