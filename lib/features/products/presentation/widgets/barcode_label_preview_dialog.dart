import 'package:barcode/barcode.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

/// On-screen preview for a 38×25 mm barcode label (no PDF).
class BarcodeLabelPreviewContent extends StatelessWidget {
  const BarcodeLabelPreviewContent({
    super.key,
    required this.productName,
    required this.barcodeValue,
    this.companyName = '',
    this.amountText = '',
  });

  final String productName;
  final String barcodeValue;
  final String companyName;
  final String amountText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Container(
          width: 228,
          height: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black87),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (companyName.trim().isNotEmpty)
                Text(
                  companyName.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (companyName.trim().isNotEmpty) const SizedBox(height: 4),
              if (productName.trim().isNotEmpty || amountText.trim().isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (amountText.trim().isNotEmpty)
                      Expanded(
                        flex: 2,
                        child: Text(
                          amountText.trim(),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (amountText.trim().isNotEmpty &&
                        productName.trim().isNotEmpty)
                      const SizedBox(width: 4),
                    if (productName.trim().isNotEmpty)
                      Expanded(
                        flex: 3,
                        child: Text(
                          productName.trim(),
                          textAlign: TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              const Spacer(),
              SizedBox(
                height: 36,
                child: CustomPaint(
                  painter: _Code128PreviewPainter(barcodeValue.trim()),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                barcodeValue.trim(),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Code128PreviewPainter extends CustomPainter {
  _Code128PreviewPainter(this.data);

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final bc = Barcode.code128();
    final elements = bc.make(data, width: size.width, height: size.height);
    final paint = Paint()..color = Colors.black;
    for (final element in elements) {
      if (element is! BarcodeBar) continue;
      canvas.drawRect(
        Rect.fromLTWH(element.left, element.top, element.width, element.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Code128PreviewPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

Future<void> showBarcodeLabelPreviewDialog({
  required BuildContext context,
  required String title,
  required String productName,
  required String barcodeValue,
  String companyName = '',
  double? amount,
  Widget? footer,
}) {
  final amountText =
      amount == null ? '' : '${amount.toStringAsFixed(2)} L.E';

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: BarcodeLabelPreviewContent(
                productName: productName,
                barcodeValue: barcodeValue,
                companyName: companyName,
                amountText: amountText,
              ),
            ),
            ?footer,
          ],
        ),
      ),
    ),
  );
}

Future<void> showSingleBarcodeLabelPreviewDialog({
  required BuildContext context,
  required String productName,
  required String barcodeValue,
  String companyName = '',
  double? amount,
}) {
  return showBarcodeLabelPreviewDialog(
    context: context,
    title: 'Preview'.tr(),
    productName: productName,
    barcodeValue: barcodeValue,
    companyName: companyName,
    amount: amount,
  );
}
