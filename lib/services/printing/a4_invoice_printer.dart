import 'dart:typed_data';

import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_print_model_mapper.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/pdf/a4_invoice_pdf_document.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:printing/printing.dart';

class A4InvoicePrinter implements InvoicePrinter {
  const A4InvoicePrinter({
    InvoicePrintModelMapper mapper = const InvoicePrintModelMapper(),
    CompanySettingsService? companySettingsService,
    this.onPrint,
  }) : _mapper = mapper,
       _companySettingsService = companySettingsService;

  final InvoicePrintModelMapper _mapper;
  final CompanySettingsService? _companySettingsService;
  final Future<void> Function(Uint8List bytes, String jobName)? onPrint;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final data = _mapper.toA4ViewData(invoice);
    final settings = _companySettingsService ?? getIt<CompanySettingsService>();
    final logoBytes = invoice.logoBytes ?? await settings.loadLogoBytes();
    final bytes = await buildA4InvoicePdfDocument(
      data: data,
      logoBytes: logoBytes,
    );

    if (onPrint != null) {
      await onPrint!(bytes, 'invoice_${invoice.invoiceNumber}');
      return;
    }

    final ok = await Printing.layoutPdf(
      name: 'invoice_${invoice.invoiceNumber}',
      onLayout: (_) async => bytes,
    );
    if (ok == false) {
      throw StateError('Printing was cancelled.');
    }
  }
}
