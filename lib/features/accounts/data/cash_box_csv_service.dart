import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:delta_erp/features/accounts/data/cash_box_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CashBoxCsvService {
  const CashBoxCsvService();

  Future<String> exportToCsv({
    required List<StandaloneCashMovement> rows,
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
      buffer.writeln('Cash Box Standalone Movements');
      buffer.writeln('Generated At,${dateFormat.format(DateTime.now())}');
      buffer.writeln(
        'From,${fromDate == null ? '' : dateFormat.format(fromDate)}',
      );
      buffer.writeln('To,${toDate == null ? '' : dateFormat.format(toDate)}');
      buffer.writeln('Rows,${rows.length}');
      buffer.writeln();
      buffer.writeln('Date,Direction,Amount,Payment Method,Notes');

      for (final row in rows) {
        final direction = row.amount >= 0 ? 'In' : 'Out';
        buffer.writeln(
          '${dateFormat.format(row.createdAt)},${esc(direction)},${valueFormat.format(row.absoluteAmount)},${esc(row.paymentMethod)},${esc(row.notes ?? '')}',
        );
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docsDir.path, 'exports'));
      await exportDir.create(recursive: true);

      final fileName =
          'cash_box_movements_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(p.join(exportDir.path, fileName));

      final bytes = utf8.encode('\uFEFF${buffer.toString()}');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting cash box CSV',
        name: 'CashBoxCsvService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
