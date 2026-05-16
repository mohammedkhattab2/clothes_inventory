import 'package:easy_localization/easy_localization.dart';

/// Human-readable label for [payments.payment_method] on an invoice list row.
/// When several payments exist we only know the latest method from SQL (documented on the model).
String invoicePaymentMethodLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return '—';
  }
  switch (raw.trim().toLowerCase()) {
    case 'cash':
      return 'Cash'.tr();
    case 'vodafone_cash':
      return 'Vodafone Cash'.tr();
    case 'visa':
      return 'Visa'.tr();
    case 'cash_and_wallet':
    case 'cash_wallet':
      return 'Cash + Wallet'.tr();
    default:
      return raw.trim();
  }
}

/// Display label when [raw] is a single `payments.payment_method` **or**
/// a comma-separated list from `GROUP_CONCAT(DISTINCT payment_method)` (e.g. cash + wallet).
String invoicePaymentMethodsDisplayLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return '—';
  }
  final trimmed = raw.trim();
  if (!trimmed.contains(',')) {
    return invoicePaymentMethodLabel(trimmed);
  }
  final methods =
      trimmed.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
  if (methods.isEmpty) {
    return '—';
  }
  if (methods.length == 1) {
    return invoicePaymentMethodLabel(methods.first);
  }
  final hasCash = methods.contains('cash');
  final hasWallet = methods.contains('vodafone_cash');
  final hasVisa = methods.contains('visa');
  if (hasCash && hasWallet && methods.length == 2) {
    return 'Cash + Wallet'.tr();
  }
  if (hasCash && hasVisa && methods.length == 2) {
    return '${'Cash'.tr()} + ${'Visa'.tr()}';
  }
  if (hasWallet && hasVisa && methods.length == 2) {
    return '${'Vodafone Cash'.tr()} + ${'Visa'.tr()}';
  }
  final ordered = methods.toList()..sort();
  return ordered.map((e) => invoicePaymentMethodLabel(e)).join(' + ');
}
