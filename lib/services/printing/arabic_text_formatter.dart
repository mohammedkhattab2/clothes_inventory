import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:bidi/bidi.dart' as bidi;

class ArabicTextFormatter {
  const ArabicTextFormatter();

  static final ArabicReshaper _reshaper = ArabicReshaper();
  static final RegExp _arabicRegExp = RegExp(r'[\u0600-\u06FF]');

  String formatArabicText(String input) {
    if (input.isEmpty || !_arabicRegExp.hasMatch(input)) {
      return input;
    }

    final reshaped = _reshaper.reshape(input);
    return String.fromCharCodes(bidi.logicalToVisual(reshaped));
  }

  List<String> formatBatch(Iterable<String> inputs) {
    return inputs.map(formatArabicText).toList(growable: false);
  }
}
