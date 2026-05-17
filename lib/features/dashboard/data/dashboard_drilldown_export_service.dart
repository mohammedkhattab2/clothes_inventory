import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:delta_erp/features/dashboard/data/dashboard_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DashboardDrillDownExportService {
  const DashboardDrillDownExportService();

  Future<String> exportPdf({
    required String title,
    required String kind,
    required DateTime fromDate,
    required DateTime toDate,
    required String granularity,
    required String categoryLabel,
    required String accountLabel,
    required List<DashboardInvoiceRecord> invoiceRows,
    required List<DashboardProfitRecord> profitRows,
    required String targetPath,
  }) async {
    try {
      final doc = pw.Document();
      final money = NumberFormat('#,##0.00');
      final date = DateFormat('yyyy-MM-dd HH:mm');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Date Range: ${DateFormat('yyyy-MM-dd').format(fromDate)} to ${DateFormat('yyyy-MM-dd').format(toDate)}',
              ),
              pw.Text('Trend: $granularity'),
              pw.Text('Category: $categoryLabel'),
              pw.Text('Account: $accountLabel'),
              pw.SizedBox(height: 12),
            ];

            if (profitRows.isNotEmpty) {
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Date',
                    'Invoice',
                    'Account',
                    'Revenue',
                    'COGS',
                    'Gross Profit',
                  ],
                  data: profitRows
                      .map(
                        (row) => [
                          date.format(row.createdAt),
                          row.invoiceNumber,
                          row.accountName,
                          money.format(row.revenue),
                          money.format(row.cogs),
                          money.format(row.grossProfit),
                        ],
                      )
                      .toList(),
                ),
              );

              if (kind == 'net' && invoiceRows.isNotEmpty) {
                widgets.add(pw.SizedBox(height: 12));
                widgets.add(
                  pw.Text(
                    'Operating Expenses',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                );
                widgets.add(pw.SizedBox(height: 6));
                widgets.add(
                  pw.TableHelper.fromTextArray(
                    headers: const [
                      'Date',
                      'Invoice',
                      'Account',
                      'Status',
                      'Total',
                    ],
                    data: invoiceRows
                        .map(
                          (row) => [
                            date.format(row.createdAt),
                            row.invoiceNumber,
                            row.accountName,
                            row.status,
                            money.format(row.totalAmount),
                          ],
                        )
                        .toList(),
                  ),
                );
              }
            } else {
              final salesPaymentExport =
                  kind == 'revenue' || kind == 'customer_debt';
              if (salesPaymentExport) {
                widgets.add(
                  pw.TableHelper.fromTextArray(
                    headers: const [
                      'Date',
                      'Invoice',
                      'Account',
                      'Status',
                      'Total',
                      'Cash',
                      'Vodafone Cash',
                      'Visa',
                      'Deferred',
                    ],
                    data: invoiceRows
                        .map(
                          (row) => [
                            date.format(row.createdAt),
                            row.invoiceNumber,
                            row.accountName,
                            row.status,
                            money.format(row.totalAmount),
                            money.format(row.paidCash),
                            money.format(row.paidVodafone),
                            money.format(row.paidVisa),
                            money.format(row.outstandingAmount),
                          ],
                        )
                        .toList(),
                  ),
                );
              } else {
                widgets.add(
                  pw.TableHelper.fromTextArray(
                    headers: const [
                      'Date',
                      'Invoice',
                      'Account',
                      'Status',
                      'Total',
                      'Paid',
                      'Outstanding',
                    ],
                    data: invoiceRows
                        .map(
                          (row) => [
                            date.format(row.createdAt),
                            row.invoiceNumber,
                            row.accountName,
                            row.status,
                            money.format(row.totalAmount),
                            money.format(row.paidAmount),
                            money.format(row.outstandingAmount),
                          ],
                        )
                        .toList(),
                  ),
                );
              }
            }

            return widgets;
          },
        ),
      );

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(await doc.save(), flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting dashboard drill-down PDF',
        name: 'DashboardDrillDownExportService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<String> exportCsv({
    required String title,
    required String kind,
    required DateTime fromDate,
    required DateTime toDate,
    required String granularity,
    required String categoryLabel,
    required String accountLabel,
    required List<DashboardInvoiceRecord> invoiceRows,
    required List<DashboardProfitRecord> profitRows,
    required String targetPath,
  }) async {
    try {
      final money = NumberFormat('#,##0.00');
      final date = DateFormat('yyyy-MM-dd HH:mm');

      String esc(String value) => '"${value.replaceAll('"', '""')}"';

      final b = StringBuffer();
      b.writeln(esc(title));
      b.writeln('From,${DateFormat('yyyy-MM-dd').format(fromDate)}');
      b.writeln('To,${DateFormat('yyyy-MM-dd').format(toDate)}');
      b.writeln('Trend,${esc(granularity)}');
      b.writeln('Category,${esc(categoryLabel)}');
      b.writeln('Account,${esc(accountLabel)}');
      b.writeln();

      if (profitRows.isNotEmpty) {
        b.writeln('Date,Invoice,Account,Revenue,COGS,Gross Profit');
        for (final row in profitRows) {
          b.writeln(
            '${date.format(row.createdAt)},${esc(row.invoiceNumber)},${esc(row.accountName)},${money.format(row.revenue)},${money.format(row.cogs)},${money.format(row.grossProfit)}',
          );
        }

        if (kind == 'net' && invoiceRows.isNotEmpty) {
          b.writeln();
          b.writeln('Operating Expenses');
          b.writeln('Date,Invoice,Account,Status,Total');
          for (final row in invoiceRows) {
            b.writeln(
              '${date.format(row.createdAt)},${esc(row.invoiceNumber)},${esc(row.accountName)},${esc(row.status)},${money.format(row.totalAmount)}',
            );
          }
        }
      } else {
        final salesPaymentExport = kind == 'revenue' || kind == 'customer_debt';
        if (salesPaymentExport) {
          b.writeln(
            'Date,Invoice,Account,Status,Total,Cash,Vodafone Cash,Visa,Deferred',
          );
          for (final row in invoiceRows) {
            b.writeln(
              '${date.format(row.createdAt)},${esc(row.invoiceNumber)},${esc(row.accountName)},${esc(row.status)},${money.format(row.totalAmount)},${money.format(row.paidCash)},${money.format(row.paidVodafone)},${money.format(row.paidVisa)},${money.format(row.outstandingAmount)}',
            );
          }
        } else {
          b.writeln('Date,Invoice,Account,Status,Total,Paid,Outstanding');
          for (final row in invoiceRows) {
            b.writeln(
              '${date.format(row.createdAt)},${esc(row.invoiceNumber)},${esc(row.accountName)},${esc(row.status)},${money.format(row.totalAmount)},${money.format(row.paidAmount)},${money.format(row.outstandingAmount)}',
            );
          }
        }
      }

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        utf8.encode('\uFEFF${b.toString()}'),
        flush: true,
      );
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting dashboard drill-down CSV',
        name: 'DashboardDrillDownExportService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

}
