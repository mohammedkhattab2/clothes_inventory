import 'package:easy_localization/easy_localization.dart';

/// Maps raw DB invoice status values to localized labels.
String localizedInvoiceStatus(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return raw;

  final key = switch (normalized) {
    'completed' => 'invoice.status.completed',
    'partial' => 'invoice.status.partial',
    'cancelled' => 'invoice.status.cancelled',
    'posted' => 'invoice.status.posted',
    'pending' => 'invoice.status.pending',
    _ => null,
  };
  if (key != null) {
    return key.tr();
  }
  return raw;
}
