import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:clothes_inventory/features/accounts/data/account_statement_repository.dart';

class AccountStatementCsvService {
  const AccountStatementCsvService();

  Future<String> exportToCsv({
    required String accountName,
    required String accountType,
    required List<AccountStatementTransaction> transactions,
    required double finalBalance,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
      final valueFormat = NumberFormat('0.00');

      String esc(String value) {
        final escaped = value.replaceAll('"', '""');
        return '"$escaped"';
      }

      final buffer = StringBuffer();
      buffer.writeln('Account Statement');
      buffer.writeln('Account Name,${esc(accountName)}');
      buffer.writeln('Account Type,${esc(accountType)}');
      buffer.writeln(
        'From,${fromDate == null ? '' : dateFormat.format(fromDate)}',
      );
      buffer.writeln('To,${toDate == null ? '' : dateFormat.format(toDate)}');
      buffer.writeln();
      buffer.writeln('Date,Type,Reference,Debit,Credit,Running Balance');

      for (final tx in transactions) {
        buffer.writeln(
          '${dateFormat.format(tx.createdAt)},${esc(tx.typeLabel)},${esc(tx.referenceLabel)},'
          '${tx.debit == 0 ? '' : valueFormat.format(tx.debit)},'
          '${tx.credit == 0 ? '' : valueFormat.format(tx.credit)},'
          '${valueFormat.format(tx.runningBalance)}',
        );
      }

      buffer.writeln();
      buffer.writeln('Final Balance,${valueFormat.format(finalBalance)}');

      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docsDir.path, 'exports'));
      await exportDir.create(recursive: true);

      final fileName =
          'account_statement_${accountName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(p.join(exportDir.path, fileName));

      final bytes = utf8.encode('\uFEFF${buffer.toString()}');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting account statement CSV',
        name: 'AccountStatementCsvService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
