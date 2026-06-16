import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

bool textNeedsArabicCodePage(String text) =>
    text.codeUnits.any((codeUnit) => codeUnit > 0x7F);

/// Encodes receipt text for ESC/POS using Latin-1 or Windows-1256.
Uint8List encodeEscPosText(String text, {required bool useArabicCodePage}) {
  if (text.isEmpty) {
    return Uint8List(0);
  }

  if (useArabicCodePage && textNeedsArabicCodePage(text)) {
    final encoding = Charset.getByName('windows-1256') ?? windows1256;
    return Uint8List.fromList(encoding.encode(text));
  }

  return Uint8List.fromList(latin1.encode(text));
}
