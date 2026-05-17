import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:delta_erp/features/products/domain/product.dart';

class ProductsCsvService {
  const ProductsCsvService();

  Future<String> exportToCsv({
    required List<Product> items,
    required String targetPath,
  }) async {
    try {
      final valueFormat = NumberFormat('0.00');
      final quantityFormat = NumberFormat('0');

      String esc(String value) {
        final escaped = value.replaceAll('"', '""');
        return '"$escaped"';
      }

      final buffer = StringBuffer();
      buffer.writeln('Products Export');
      buffer.writeln(
        'Generated At,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );
      buffer.writeln('Total Rows,${items.length}');
      buffer.writeln();
      buffer.writeln(
        'Name,Barcode,Unit,Current Stock,Sale Price,Purchase Price,Low Stock Threshold',
      );

      for (final item in items) {
        buffer.writeln(
          '${esc(item.name)},${esc(item.barcode ?? '')},${item.unitType.name},'
          '${quantityFormat.format(item.currentStock)},${valueFormat.format(item.salePrice)},'
          '${valueFormat.format(item.purchasePrice)},${quantityFormat.format(item.lowStockThreshold)}',
        );
      }

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      final bytes = utf8.encode('\uFEFF${buffer.toString()}');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting products CSV',
        name: 'ProductsCsvService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
