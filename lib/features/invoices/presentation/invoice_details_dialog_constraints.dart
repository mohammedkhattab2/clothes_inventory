import 'package:flutter/material.dart';

/// Comfortable invoice details dialog size for desktop/tablet POS layouts.
BoxConstraints invoiceDetailsDialogConstraints(BuildContext context) {
  final sz = MediaQuery.sizeOf(context);
  return BoxConstraints(
    maxWidth: (sz.width * 0.92).clamp(520.0, 920.0),
    maxHeight: (sz.height * 0.85).clamp(480.0, 820.0),
    minWidth: 480,
    minHeight: 400,
  );
}
