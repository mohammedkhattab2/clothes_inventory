import 'package:flutter/widgets.dart';

/// Debounce for POS-style barcode fields (manual typing + USB scanners).
const Duration kPosBarcodeDebounce = Duration(milliseconds: 180);

/// Strip line breaks from scanner suffixes and trim whitespace.
String normalizePosBarcodeInput(String raw) {
  return raw.replaceAll(RegExp(r'[\r\n]+'), '').trim();
}

/// Refocus barcode field after add/clear; selects current text for quick
/// correction when non-empty, or places caret at start when empty.
void refocusBarcodeForNextScan({
  required FocusNode focus,
  required TextEditingController controller,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = focus.context;
    if (ctx == null || !ctx.mounted) return;
    focus.requestFocus();
    final len = controller.text.length;
    controller.selection = TextSelection(baseOffset: 0, extentOffset: len);
  });
}
