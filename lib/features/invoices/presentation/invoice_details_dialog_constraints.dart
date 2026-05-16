import 'package:flutter/material.dart';

/// Smaller details dialog (~40% of the previous default max size).
BoxConstraints invoiceDetailsDialogConstraints(BuildContext context) {
  final sz = MediaQuery.sizeOf(context);
  final baseMaxW = (sz.width * 0.94).clamp(320.0, 760.0);
  final baseMaxH = (sz.height * 0.88).clamp(360.0, 760.0);
  return BoxConstraints(
    maxWidth: (baseMaxW * 0.4).clamp(280.0, 400.0),
    maxHeight: (baseMaxH * 0.4).clamp(320.0, 560.0),
  );
}
