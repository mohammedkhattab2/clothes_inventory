import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:delta_erp/features/accounts/data/account_statement_repository.dart';

class AccountStatementCsvService {
  const AccountStatementCsvService();

  Future<String> exportToCsv({
    required String accountName,
    required String accountType,
    required List<AccountStatementTransaction> transactions,
    required double finalBalance,
    required String targetPath,
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

      final file = File(targetPath);
      await file.parent.create(recursive: true);
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
