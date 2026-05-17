import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:delta_erp/features/expenses/data/expenses_repository.dart';

class ExpensesCsvService {
  const ExpensesCsvService();

  Future<String> exportToCsv({
    required List<ExpenseRecord> rows,
    required double grossExpenses,
    required double netExpenses,
    required bool includeReversals,
    required String targetPath,
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
  }) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
      final valueFormat = NumberFormat('0.00');

      String esc(String value) {
        final escaped = value.replaceAll('"', '""');
        return '"$escaped"';
      }

      final buffer = StringBuffer();
      buffer.writeln('Expenses Export');
      buffer.writeln('Generated At,${dateFormat.format(DateTime.now())}');
      buffer.writeln(
        'From,${fromDate == null ? '' : dateFormat.format(fromDate)}',
      );
      buffer.writeln('To,${toDate == null ? '' : dateFormat.format(toDate)}');
      buffer.writeln('Account Id,${accountId ?? ''}');
      buffer.writeln('Include Reversals,${includeReversals ? 'Yes' : 'No'}');
      buffer.writeln('Gross Expenses,${valueFormat.format(grossExpenses)}');
      buffer.writeln('Net Expenses,${valueFormat.format(netExpenses)}');
      buffer.writeln('Rows,${rows.length}');
      buffer.writeln();
      buffer.writeln('Date,Category,Amount,Payment Method,Notes,Entry Kind');

      for (final row in rows) {
        final entryKind = row.amount >= 0 ? 'Original' : 'Reversal';
        buffer.writeln(
          '${dateFormat.format(row.createdAt)},${esc(row.accountName)},${valueFormat.format(row.amount)},${esc(row.paymentMethod)},${esc(row.notes ?? '')},${esc(entryKind)}',
        );
      }

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      final bytes = utf8.encode('\uFEFF${buffer.toString()}');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting expenses CSV',
        name: 'ExpensesCsvService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
