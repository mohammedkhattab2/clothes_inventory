import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DashboardPdfService {
  const DashboardPdfService();

  Future<String> exportSummary({
    required DashboardSnapshot snapshot,
    required DateTime fromDate,
    required DateTime toDate,
    required String granularity,
    bool includeOwnerAnalytics = true,
    String? preparedByName,
    String? categoryLabel,
    String? accountLabel,
    Uint8List? topProductsChart,
    Uint8List? trendChart,
  }) async {
    try {
      final bytes = await _buildPdf(
        snapshot: snapshot,
        fromDate: fromDate,
        toDate: toDate,
        granularity: granularity,
        includeOwnerAnalytics: includeOwnerAnalytics,
        preparedByName: preparedByName,
        categoryLabel: categoryLabel,
        accountLabel: accountLabel,
        topProductsChart: topProductsChart,
        trendChart: trendChart,
      );

      final docs = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docs.path, 'exports', 'dashboard'));
      await exportDir.create(recursive: true);

      final fileName =
          'dashboard_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File(p.join(exportDir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting dashboard PDF',
        name: 'DashboardPdfService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<Uint8List> _buildPdf({
    required DashboardSnapshot snapshot,
    required DateTime fromDate,
    required DateTime toDate,
    required String granularity,
    required bool includeOwnerAnalytics,
    String? preparedByName,
    String? categoryLabel,
    String? accountLabel,
    Uint8List? topProductsChart,
    Uint8List? trendChart,
  }) async {
    final doc = pw.Document();
    final money = NumberFormat('#,##0.00');
    final d = DateFormat('yyyy-MM-dd');

    pw.Widget kpiCell(String title, double value) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(
              money.format(value),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          final title = includeOwnerAnalytics
              ? 'Dashboard Summary'.tr()
              : 'Shift Close Report'.tr();
          final shiftBalance = snapshot.totalSales - snapshot.expenses;

          final kpiWidgets = <pw.Widget>[
            pw.SizedBox(
              width: 160,
              child: kpiCell('Revenue'.tr(), snapshot.totalSales),
            ),
            pw.SizedBox(
              width: 160,
              child: kpiCell('Expenses'.tr(), snapshot.expenses),
            ),
          ];

          if (includeOwnerAnalytics) {
            kpiWidgets.addAll([
              pw.SizedBox(
                width: 160,
                child: kpiCell('Gross Profit'.tr(), snapshot.grossProfit),
              ),
              pw.SizedBox(
                width: 160,
                child: kpiCell('Net Profit'.tr(), snapshot.netProfit),
              ),
              pw.SizedBox(
                width: 160,
                child: kpiCell(
                  'Customer Debt'.tr(),
                  snapshot.outstandingCustomerDebt,
                ),
              ),
              pw.SizedBox(
                width: 160,
                child: kpiCell(
                  'Supplier Debt'.tr(),
                  snapshot.outstandingSupplierDebt,
                ),
              ),
            ]);
          } else {
            kpiWidgets.add(
              pw.SizedBox(
                width: 160,
                child: kpiCell('Shift Balance'.tr(), shiftBalance),
              ),
            );
          }

          return [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${'Date Range'.tr()}: ${d.format(fromDate)} ${'to'.tr()} ${d.format(toDate)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              '${'Filters'.tr()}: ${'Trend'.tr()}=$granularity, ${'Category'.tr()}=${categoryLabel ?? 'All'.tr()}, ${'Account'.tr()}=${accountLabel ?? 'All'.tr()}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (!includeOwnerAnalytics && preparedByName != null) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                '${'Prepared by'.tr()}: $preparedByName',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 12),
            pw.Wrap(spacing: 8, runSpacing: 8, children: kpiWidgets),
            if (includeOwnerAnalytics) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Top-selling Products (Qty + Revenue)'.tr(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              if (topProductsChart != null)
                pw.Image(pw.MemoryImage(topProductsChart), height: 180)
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Product'.tr(), 'Quantity'.tr(), 'Revenue'.tr()],
                  data: snapshot.topProducts
                      .map(
                        (e) => [
                          e.productName,
                          e.quantity.toStringAsFixed(0),
                          money.format(e.revenue),
                        ],
                      )
                      .toList(),
                ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Sales vs Purchases Trend'.tr(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              if (trendChart != null)
                pw.Image(pw.MemoryImage(trendChart), height: 180)
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Period'.tr(), 'Sales'.tr(), 'Purchases'.tr()],
                  data: snapshot.trend
                      .map(
                        (e) => [
                          e.label,
                          money.format(e.sales),
                          money.format(e.purchases),
                        ],
                      )
                      .toList(),
                ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Top Suppliers'.tr(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Supplier'.tr(), 'Volume'.tr()],
                data: snapshot.topSuppliers
                    .map((e) => [e.supplierName, money.format(e.volume)])
                    .toList(),
              ),
            ],
          ];
        },
      ),
    );

    return doc.save();
  }
}
