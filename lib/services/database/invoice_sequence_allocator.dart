import 'package:sqflite/sqflite.dart';

const _saleType = 'sale';
const _purchaseType = 'purchase';

/// Formats as at least 4 digits (e.g. `0001`; beyond 9999 → `10000`).
String formatSaleInvoiceNumber(int seq) {
  if (seq < 1 || seq > 999999) {
    throw StateError('Sale invoice sequence out of supported range (1–999999).');
  }
  final suffix =
      seq <= 9999 ? seq.toString().padLeft(4, '0') : seq.toString();
  return suffix;
}

/// Formats as at least 4 digits (e.g. `0001`; beyond 9999 → `10000`).
String formatPurchaseInvoiceNumber(int seq) {
  if (seq < 1 || seq > 999999) {
    throw StateError(
      'Purchase invoice sequence out of supported range (1–999999).',
    );
  }
  final suffix =
      seq <= 9999 ? seq.toString().padLeft(4, '0') : seq.toString();
  return suffix;
}

Future<String> allocateSaleInvoiceNumber(Transaction txn) async {
  return _allocate(txn, _saleType, formatSaleInvoiceNumber);
}

Future<String> allocatePurchaseInvoiceNumber(Transaction txn) async {
  return _allocate(txn, _purchaseType, formatPurchaseInvoiceNumber);
}

Future<String> _allocate(
  Transaction txn,
  String docType,
  String Function(int) format,
) async {
  final rows = await txn.query(
    'invoice_sequences',
    columns: ['next_value'],
    where: 'doc_type = ?',
    whereArgs: [docType],
    limit: 1,
  );
  if (rows.isEmpty) {
    throw StateError('Missing invoice sequence row for $docType.');
  }
  final current = (rows.first['next_value'] as num).toInt();
  final updated = await txn.rawUpdate(
    '''
    UPDATE invoice_sequences
    SET next_value = next_value + 1
    WHERE doc_type = ?
    ''',
    [docType],
  );
  if (updated != 1) {
    throw StateError('Failed to advance invoice sequence for $docType.');
  }
  return format(current);
}
