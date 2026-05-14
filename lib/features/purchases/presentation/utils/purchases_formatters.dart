import 'package:easy_localization/easy_localization.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';

double? parseFlexibleNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  const arabicIndicDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  var normalized = trimmed;
  arabicIndicDigits.forEach((key, value) {
    normalized = normalized.replaceAll(key, value);
  });

  normalized = normalized
      .replaceAll('٬', '')
      .replaceAll('٫', '.')
      .replaceAll('،', '.')
      .replaceAll(',', '.');

  return double.tryParse(normalized);
}

int? parseFlexibleInt(String raw) {
  final value = parseFlexibleNumber(raw);
  if (value == null) return null;
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() > 0.000001) {
    return null;
  }
  return rounded.toInt();
}

String formatDraftQuantity(PurchaseDraftItem item) {
  if (item.unitType == UnitType.piece.name) {
    final nearestInt = item.quantity.roundToDouble();
    if ((item.quantity - nearestInt).abs() < 0.000001) {
      return item.quantity.toStringAsFixed(0);
    }
  }
  return item.quantity.toStringAsFixed(0);
}

String formatInvoiceQuantityValue(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.000001) {
    return value.toStringAsFixed(0);
  }

  final withThree = value.toStringAsFixed(3);
  return withThree
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String displayPurchaseInvoiceNumber({
  required int id,
  String? rawInvoiceNumber,
}) {
  final raw = (rawInvoiceNumber ?? '').trim();
  final machineLike = RegExp(r'^[Pp]\d+$').hasMatch(raw);
  if (raw.isEmpty || raw == '-' || machineLike) {
    return '#$id';
  }
  return raw;
}

String buildPurchaseInvoiceLabel({required int id, String? rawInvoiceNumber}) {
  return '${'Invoice'.tr()} ${displayPurchaseInvoiceNumber(id: id, rawInvoiceNumber: rawInvoiceNumber)}';
}
