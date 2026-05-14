import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    stdout.writeln(
      'Usage: dart run tool/generate_license.dart <machineHash> <customerName> <licenseId> <expiresAtIsoUtc>',
    );
    stdout.writeln(
      'Set PRIVATE_KEY_BASE64 in environment (32-byte Ed25519 seed in base64).',
    );
    exit(64);
  }

  final String? privateKeyBase64 = Platform.environment['PRIVATE_KEY_BASE64'];
  if (privateKeyBase64 == null || privateKeyBase64.isEmpty) {
    stderr.writeln('Missing PRIVATE_KEY_BASE64 env var.');
    exit(64);
  }

  final String machineHash = args[0];
  final String customerName = args[1];
  final String licenseId = args[2];
  final String expiresAtIso = args[3];

  final DateTime now = DateTime.now().toUtc();
  final DateTime expiresAt = DateTime.parse(expiresAtIso).toUtc();

  final Map<String, dynamic> payload = <String, dynamic>{
    'licenseId': licenseId,
    'customerName': customerName,
    'issuedAt': now.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'machineHash': machineHash,
    'features': <String>['sales', 'purchases', 'reports'],
    'maxTransfersPerYear': 2,
    'appVersionMin': '1.0.0',
  };

  final List<int> payloadBytes = utf8.encode(jsonEncode(payload));

  final Ed25519 algorithm = Ed25519();
  final List<int> privateSeed = base64Decode(privateKeyBase64);
  final KeyPair keyPair = await algorithm.newKeyPairFromSeed(privateSeed);

  final Signature signature = await algorithm.sign(
    payloadBytes,
    keyPair: keyPair,
  );

  final Map<String, dynamic> envelope = <String, dynamic>{
    'version': 1,
    'payload': base64Encode(payloadBytes),
    'signature': base64Encode(signature.bytes),
  };

  stdout.writeln(jsonEncode(envelope));
}
