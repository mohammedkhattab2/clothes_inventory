import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_document.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Sharp thermal receipt preview — content-fit PDF at higher display scale.
class ThermalInvoicePdfPreview extends StatefulWidget {
  const ThermalInvoicePdfPreview({
    super.key,
    required this.invoice,
    required this.paperWidthMm,
  });

  final InvoicePrintModel invoice;
  final double paperWidthMm;

  /// Display scale for sharp on-screen thermal preview.
  static const previewScale = 3.5;

  /// Raster DPI for PdfPreview — higher = sharper text on screen.
  static const previewDpi = 300.0;

  static double maxPreviewWidthPx(double paperWidthMm) =>
      paperWidthMm * PdfPageFormat.mm * previewScale;

  @override
  State<ThermalInvoicePdfPreview> createState() =>
      _ThermalInvoicePdfPreviewState();
}

class _ThermalInvoicePdfPreviewState extends State<ThermalInvoicePdfPreview> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController.none(
      child: ColoredBox(
        color: Colors.white,
        child: PdfPreview.builder(
          build: (_) => buildThermalInvoicePdfDocument(
            invoice: widget.invoice,
            paperWidthMm: widget.paperWidthMm,
          ),
          maxPageWidth: ThermalInvoicePdfPreview.maxPreviewWidthPx(
            widget.paperWidthMm,
          ),
          dpi: ThermalInvoicePdfPreview.previewDpi,
          pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
          previewPageMargin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          allowPrinting: false,
          useActions: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          pagesBuilder: (context, pages) {
            if (pages.isEmpty) {
              return const SizedBox.shrink();
            }

            return ListView.builder(
              controller: _scrollController,
              primary: false,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final page = pages[index];
                return Center(
                  child: AspectRatio(
                    aspectRatio: page.aspectRatio,
                    child: Image(
                      image: page.image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
