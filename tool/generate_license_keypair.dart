import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final Ed25519 algorithm = Ed25519();
  final KeyPair keyPair = await algorithm.newKeyPair();

  final SimpleKeyPairData keyData =
      await keyPair.extract() as SimpleKeyPairData;
  final PublicKey publicKey = await keyPair.extractPublicKey();

  final String privateSeedBase64 = base64Encode(keyData.bytes);
  final String publicKeyBase64 = base64Encode(
    (publicKey as SimplePublicKey).bytes,
  );

  // Keep private seed secret and never commit it.
  stdout.writeln('PRIVATE_KEY_BASE64=$privateSeedBase64');
  stdout.writeln('PUBLIC_KEY_BASE64=$publicKeyBase64');
}
