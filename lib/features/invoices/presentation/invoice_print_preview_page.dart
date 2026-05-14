import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/core/config/company_settings_service.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/features/invoices/presentation/invoice_print_model_mapper.dart';
import 'package:clothes_inventory/features/invoices/presentation/widgets/a4_invoice_rtl_widget.dart';
import 'package:clothes_inventory/services/printing/invoice_print_manager.dart';
import 'package:clothes_inventory/services/printing/invoice_print_preferences.dart';
import 'package:clothes_inventory/services/printing/invoice_printer.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class InvoicePrintPreviewPage extends StatefulWidget {
  const InvoicePrintPreviewPage({
    super.key,
    required this.invoice,
    required this.printManager,
  });

  final InvoicePrintModel invoice;
  final InvoicePrintManager printManager;

  @override
  State<InvoicePrintPreviewPage> createState() =>
      _InvoicePrintPreviewPageState();
}

class _InvoicePrintPreviewPageState extends State<InvoicePrintPreviewPage> {
  static const _mapper = InvoicePrintModelMapper();
  static const _preferences = InvoicePrintPreferences();

  PrinterType _printerType = PrinterType.a4;
  bool _supportsArabic = true;
  bool _useImageFallback = false;
  bool _printing = false;
  Uint8List? _logoBytes;
  late final CompanySettingsService _companySettingsService;
  late final VoidCallback _settingsListener;

  @override
  void initState() {
    super.initState();
    _companySettingsService = getIt<CompanySettingsService>();
    _settingsListener = () {
      _refreshLogoBytes();
    };
    _companySettingsService.settingsListenable.addListener(_settingsListener);
    _refreshLogoBytes();
    _loadSavedPrintConfig();
  }

  @override
  void dispose() {
    _companySettingsService.settingsListenable.removeListener(
      _settingsListener,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _mapper.toA4ViewData(widget.invoice);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('معاينة الطباعة')),
      body: Column(
        children: [
          _Toolbar(
            printerType: _printerType,
            supportsArabic: _supportsArabic,
            useImageFallback: _useImageFallback,
            printing: _printing,
            onPrinterTypeChanged: (value) {
              setState(() {
                _printerType = value;
              });
              _persistConfig();
            },
            onSupportsArabicChanged: (value) {
              setState(() {
                _supportsArabic = value;
              });
              _persistConfig();
            },
            onImageFallbackChanged: (value) {
              setState(() {
                _useImageFallback = value;
              });
              _persistConfig();
            },
            onPrintPressed: _printing ? null : _handlePrint,
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                    colorScheme.surface,
                  ],
                ),
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SingleChildScrollView(
                      child: A4InvoiceRtlWidget(
                        data: data,
                        logoBytes: _logoBytes,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLogoBytes() async {
    final bytes = await _companySettingsService.loadLogoBytes();
    if (!mounted) return;
    setState(() {
      _logoBytes = bytes;
    });
  }

  Future<void> _handlePrint() async {
    setState(() {
      _printing = true;
    });

    try {
      final config = InvoicePrintConfiguration(
        printerType: _printerType,
        printerSupportsArabic: _supportsArabic,
        useImageFallback: _useImageFallback,
      );
      await _preferences.save(config);
      await widget.printManager.printInvoice(widget.invoice, config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الفاتورة للطباعة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الطباعة: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  Future<void> _loadSavedPrintConfig() async {
    final config = await _preferences.load();
    if (!mounted) return;
    setState(() {
      _printerType = config.printerType;
      _supportsArabic = config.printerSupportsArabic;
      _useImageFallback = config.useImageFallback;
    });
  }

  Future<void> _persistConfig() {
    return _preferences.save(
      InvoicePrintConfiguration(
        printerType: _printerType,
        printerSupportsArabic: _supportsArabic,
        useImageFallback: _useImageFallback,
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.printerType,
    required this.supportsArabic,
    required this.useImageFallback,
    required this.printing,
    required this.onPrinterTypeChanged,
    required this.onSupportsArabicChanged,
    required this.onImageFallbackChanged,
    required this.onPrintPressed,
  });

  final PrinterType printerType;
  final bool supportsArabic;
  final bool useImageFallback;
  final bool printing;
  final ValueChanged<PrinterType> onPrinterTypeChanged;
  final ValueChanged<bool> onSupportsArabicChanged;
  final ValueChanged<bool> onImageFallbackChanged;
  final VoidCallback? onPrintPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 1,
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<PrinterType>(
                value: printerType,
                items: const [
                  DropdownMenuItem(value: PrinterType.a4, child: Text('A4')),
                  DropdownMenuItem(
                    value: PrinterType.thermal58,
                    child: Text('Thermal 58mm'),
                  ),
                  DropdownMenuItem(
                    value: PrinterType.thermal80,
                    child: Text('Thermal 80mm'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onPrinterTypeChanged(value);
                  }
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('يدعم العربي'),
                  Switch(
                    value: supportsArabic,
                    onChanged: onSupportsArabicChanged,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Image fallback'),
                  Switch(
                    value: useImageFallback,
                    onChanged: onImageFallbackChanged,
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onPrintPressed,
                icon: printing
                    ? const AppInlineLoadingIndicator()
                    : const Icon(Icons.print_outlined),
                label: Text(printing ? 'جارٍ الطباعة...' : 'طباعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
