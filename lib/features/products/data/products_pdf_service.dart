import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ProductsPdfService {
  const ProductsPdfService();

  Future<String> exportToPdf({
    required List<Product> items,
    required String targetPath,
  }) async {
    try {
      final doc = pw.Document();
      final valueFormat = NumberFormat('0.00');
      final quantityFormat = NumberFormat('0');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Text(
                'Products Export',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Generated at: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              ),
              pw.Text('Total rows: ${items.length}'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                headers: const [
                  'Name',
                  'Barcode',
                  'Unit',
                  'Current Stock',
                  'Sale Price',
                  'Purchase Price',
                  'Low Stock Threshold',
                ],
                data: items
                    .map(
                      (item) => [
                        item.name,
                        item.barcode ?? '',
                        item.unitType.name,
                        quantityFormat.format(item.currentStock),
                        valueFormat.format(item.salePrice),
                        valueFormat.format(item.purchasePrice),
                        quantityFormat.format(item.lowStockThreshold),
                      ],
                    )
                    .toList(),
              ),
            ];
          },
        ),
      );

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(await doc.save(), flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting products PDF',
        name: 'ProductsPdfService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
