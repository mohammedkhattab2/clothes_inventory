import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_print_preview_page.dart';
import 'package:delta_erp/features/license/domain/license_service.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/purchases/presentation/utils/purchases_formatters.dart';
import 'package:delta_erp/features/purchases/presentation/widgets/purchases_cancel_dialog.dart';
import 'package:delta_erp/features/purchases/presentation/widgets/purchases_invoice_details_dialog.dart';
import 'package:delta_erp/features/purchases/presentation/widgets/purchases_invoices_explorer.dart';
import 'package:delta_erp/features/purchases/presentation/widgets/purchases_return_dialog.dart';
import 'package:delta_erp/features/sales/data/sales_repository.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_cancel_sale_dialog.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_invoice_details_dialog.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_invoices_explorer.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_return_dialog.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/pdf/sales_invoice_pdf_service.dart';
import 'package:delta_erp/services/printing/a4_invoice_printer.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/thermal_pdf_invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';

enum InvoicesHubTab { sales, purchases }

class InvoicesHubPage extends StatefulWidget {
  const InvoicesHubPage({
    this.initialTab = InvoicesHubTab.sales,
    this.selectedInvoiceId,
    this.fromDate,
    this.toDate,
    this.accountId,
    this.categoryId,
    this.initialPage = 0,
    this.pageSize = 50,
    this.navSource,
    super.key,
  });

  final InvoicesHubTab initialTab;
  final int? selectedInvoiceId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? accountId;
  final int? categoryId;
  final int initialPage;
  final int pageSize;
  final String? navSource;

  @override
  State<InvoicesHubPage> createState() => _InvoicesHubPageState();
}

class _InvoicesHubPageState extends State<InvoicesHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _licenseService = getIt<LicenseService>();
  final _salesRepo = getIt<SalesRepository>();
  final _purchasesRepo = getIt<PurchasesRepository>();
  final _salesPdfService = getIt<SalesInvoicePdfService>();
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final _invoicePrintManager = InvoicePrintManager(
    a4Printer: const A4InvoicePrinter(),
    thermal58Printer: ThermalPdfInvoicePrinter(
      paperWidthMm: 58,
      printerPrefs: const ThermalPrinterPreferences(),
    ),
    thermal80Printer: ThermalPdfInvoicePrinter(
      paperWidthMm: 80,
      printerPrefs: const ThermalPrinterPreferences(),
    ),
  );

  final _salesScrollController = ScrollController();
  final _purchasesScrollController = ScrollController();

  // Sales invoices state
  bool _salesLoading = false;
  List<SalesInvoiceSummary> _salesRows = const [];
  Map<SalesInvoiceTypeFilter, int> _salesTypeCounts =
      const <SalesInvoiceTypeFilter, int>{};
  SalesInvoiceTypeFilter _salesTypeFilter = SalesInvoiceTypeFilter.all;
  int _salesPage = 0;
  int _salesPageSize = 50;
  int? _activeSalesInvoiceId;
  String? _activeSalesInvoiceNumber;
  int? _activeSalesItemId;
  List<SalesInvoiceLine> _activeSalesInvoiceLines = const [];

  // Purchase invoices state
  bool _purchasesLoading = false;
  List<PurchaseInvoiceSummary> _purchaseRows = const [];
  int _purchasePage = 0;
  int _purchasePageSize = 50;
  int? _activePurchaseInvoiceId;
  String? _activePurchaseInvoiceNumber;
  int? _activePurchaseItemId;
  List<PurchaseInvoiceLine> _activePurchaseInvoiceLines = const [];

  @override
  void initState() {
    super.initState();
    _salesPage = widget.initialPage < 0 ? 0 : widget.initialPage;
    _salesPageSize = widget.pageSize <= 0 ? 50 : widget.pageSize;
    _purchasePage = widget.initialPage < 0 ? 0 : widget.initialPage;
    _purchasePageSize = widget.pageSize <= 0 ? 50 : widget.pageSize;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == InvoicesHubTab.sales ? 0 : 1,
    );

    if (widget.initialTab == InvoicesHubTab.sales) {
      _activeSalesInvoiceId = widget.selectedInvoiceId;
    } else {
      _activePurchaseInvoiceId = widget.selectedInvoiceId;
    }

    _loadSalesInvoices();
    _loadPurchaseInvoices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selectedInvoiceId == null) return;
      _showLatestSnackBar(
        context,
        '${'Opened from'.tr()} ${widget.navSource ?? 'navigation'.tr()}: ${'invoice'.tr()} #${widget.selectedInvoiceId} ${'highlighted'.tr()}.',
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _salesScrollController.dispose();
    _purchasesScrollController.dispose();
    super.dispose();
  }

  void _showLatestSnackBar(BuildContext targetContext, String message) {
    if (!mounted || !targetContext.mounted) return;
    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _animateDialogEntrance(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  double? _parseFlexibleNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    const arabicIndicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    var normalized = trimmed;
    arabicIndicDigits.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });

    normalized = normalized
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  int? _parseFlexibleInt(String raw) {
    final value = _parseFlexibleNumber(raw);
    if (value == null) return null;
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() > 0.000001) {
      return null;
    }
    return rounded.toInt();
  }

  Future<bool> _ensureWriteAllowed() async {
    final permission = await _licenseService.checkWritePermission();
    if (permission.isValid) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    _showLatestSnackBar(
      context,
      _localizedLicenseWriteMessage(permission.code),
    );
    return false;
  }

  String _localizedLicenseWriteMessage(String code) {
    switch (code) {
      case 'grace_read_only':
      case 'read_only_mode':
        return 'license.read_only_banner'.tr();
      case 'license_expired':
        return 'license.expired'.tr();
      case 'machine_mismatch':
        return 'license.machine_mismatch'.tr();
      case 'signature_invalid':
      case 'invalid_format':
        return 'license.invalid'.tr();
      case 'clock_rollback':
        return 'license.clock_rollback'.tr();
      case 'no_license':
      default:
        return 'license.inactive'.tr();
    }
  }

  Future<void> _loadSalesInvoices() async {
    setState(() => _salesLoading = true);
    try {
      final statuses = switch (_salesTypeFilter) {
        SalesInvoiceTypeFilter.all => null,
        SalesInvoiceTypeFilter.completed => <String>['completed'],
        SalesInvoiceTypeFilter.credit => <String>['partial'],
        SalesInvoiceTypeFilter.pending => <String>['pending'],
      };

      final countsRaw = await _salesRepo.countInvoicesByStatus(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
      );

      final completedCount = countsRaw['completed'] ?? 0;
      final creditCount = countsRaw['partial'] ?? 0;
      final pendingCount = countsRaw['pending'] ?? 0;
      final allCount = completedCount + creditCount + pendingCount;

      final rows = await _salesRepo.listInvoices(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
        statuses: statuses,
        limit: _salesPageSize,
        offset: _salesPage * _salesPageSize,
      );

      if (!mounted) return;
      setState(() {
        _salesRows = rows;
        _salesTypeCounts = {
          SalesInvoiceTypeFilter.all: allCount,
          SalesInvoiceTypeFilter.completed: completedCount,
          SalesInvoiceTypeFilter.credit: creditCount,
          SalesInvoiceTypeFilter.pending: pendingCount,
        };
        _salesLoading = false;
      });
      _scrollToSalesPreselected();
      if (_activeSalesInvoiceId != null &&
          !_salesRows.any((e) => e.id == _activeSalesInvoiceId)) {
        setState(() {
          _activeSalesInvoiceId = null;
          _activeSalesInvoiceNumber = null;
          _activeSalesItemId = null;
          _activeSalesInvoiceLines = const [];
        });
      }
    } catch (e, st) {
      dev.log(
        'Failed loading sales invoices in hub',
        name: 'InvoicesHubPage',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _salesLoading = false);
    }
  }

  void _scrollToSalesPreselected() {
    final targetId = _activeSalesInvoiceId;
    if (targetId == null) return;
    final index = _salesRows.indexWhere((e) => e.id == targetId);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_salesScrollController.hasClients) return;
      final max = _salesScrollController.position.maxScrollExtent;
      final offset = (index * 48.0).clamp(0, max).toDouble();
      _salesScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _selectSalesInvoice(SalesInvoiceSummary row) async {
    final lines = await _salesRepo.listInvoiceLines(row.id);
    SalesInvoiceLine? selectedLine;
    if (lines.isNotEmpty) {
      var lineCandidate = lines.first;
      for (final line in lines) {
        if (line.remainingQuantity > lineCandidate.remainingQuantity) {
          lineCandidate = line;
        }
      }
      selectedLine = lineCandidate;
    }
    if (!mounted) return;
    setState(() {
      _activeSalesInvoiceId = row.id;
      _activeSalesInvoiceNumber = row.invoiceNumber;
      _activeSalesInvoiceLines = lines;
      _activeSalesItemId = selectedLine?.id;
    });
    _showLatestSnackBar(
      context,
      '${'Invoice'.tr()} ${row.invoiceNumber} ${'selected'.tr()}.',
    );
  }

  Future<void> _refreshSalesInvoiceLines(
    int saleId, {
    int? preferredItemId,
  }) async {
    final lines = await _salesRepo.listInvoiceLines(saleId);
    if (!mounted) return;

    SalesInvoiceLine? selectedLine;
    if (lines.isNotEmpty) {
      if (preferredItemId != null) {
        for (final line in lines) {
          if (line.id == preferredItemId) {
            selectedLine = line;
            break;
          }
        }
      }

      selectedLine ??= lines.first;
      for (final line in lines) {
        if (line.remainingQuantity > selectedLine!.remainingQuantity) {
          selectedLine = line;
        }
      }
    }

    SalesInvoiceSummary? refreshedSummary;
    for (final row in _salesRows) {
      if (row.id == saleId) {
        refreshedSummary = row;
        break;
      }
    }

    setState(() {
      _activeSalesInvoiceLines = lines;
      _activeSalesItemId = selectedLine?.id;
      if (refreshedSummary != null) {
        _activeSalesInvoiceNumber = refreshedSummary.invoiceNumber;
      }
      if (_activeSalesInvoiceId != saleId) {
        _activeSalesInvoiceId = saleId;
      }
    });
  }

  Future<void> _showSalesReturnDialog({
    int? initialSaleId,
    int? initialSaleItemId,
    double? initialQuantity,
  }) async {
    await SalesReturnDialog.show(
      context,
      initialSaleId: initialSaleId,
      initialSaleItemId: initialSaleItemId,
      initialQuantity: initialQuantity,
      parseFlexibleInt: _parseFlexibleInt,
      parseFlexibleNumber: _parseFlexibleNumber,
      lookupSaleInvoiceSuggestion: (id) =>
          _salesRepo.lookupSaleInvoiceSuggestionForReturn(id),
      searchSaleInvoicesForReturn: (prefix) =>
          _salesRepo.suggestSaleInvoicesForReturn(prefix),
      loadInvoiceLines: (saleId) => _salesRepo.listInvoiceLines(saleId),
      onReturnSaleItem:
          ({
            required saleId,
            required saleItemId,
            required quantity,
            required paymentMethod,
          }) async {
            final allowed = await _ensureWriteAllowed();
            if (!allowed) {
              return 'license.read_only_banner'.tr();
            }
            try {
              await _salesRepo.returnSaleItem(
                saleId: saleId,
                saleItemId: saleItemId,
                quantity: quantity,
                paymentMethod: paymentMethod,
              );
              await _loadSalesInvoices();
              return null;
            } catch (e) {
              return e.toString();
            }
          },
      onRefreshInvoiceLines: _refreshSalesInvoiceLines,
      animateDialogEntrance: _animateDialogEntrance,
      activeInvoiceId: _activeSalesInvoiceId,
      activeInvoiceDisplayNumber: _activeSalesInvoiceNumber,
      activeInvoiceLines: _activeSalesInvoiceLines,
    );
  }

  Future<void> _showSalesCancelDialog({int? initialSaleId}) async {
    await SalesCancelSaleDialog.show(
      context,
      initialSaleId: initialSaleId,
      parseFlexibleInt: _parseFlexibleInt,
      animateDialogEntrance: _animateDialogEntrance,
      onCancelSale: (saleId) async {
        final allowed = await _ensureWriteAllowed();
        if (!allowed) {
          return false;
        }
        try {
          await _salesRepo.cancelSale(saleId);
          if (!mounted) return true;
          setState(() {
            _activeSalesItemId = null;
            _activeSalesInvoiceLines = const [];
          });
          await _loadSalesInvoices();
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<void> _generateSalesPdf(int saleId) async {
    try {
      final bytes = await _salesPdfService.generateA4Invoice(saleId);
      if (!mounted) return;
      _showLatestSnackBar(
        context,
        '${'PDF generated in memory'.tr()} (${bytes.length} ${'bytes'.tr()}).',
      );
    } catch (e) {
      if (!mounted) return;
      _showLatestSnackBar(context, '${'PDF generation failed'.tr()}: $e');
    }
  }

  Future<void> _showSalesInvoiceDetailsDialog() async {
    final invoiceId = _activeSalesInvoiceId;
    if (invoiceId == null) return;

    await SalesInvoiceDetailsDialog.show(
      context,
      invoiceId: invoiceId,
      invoiceRows: _salesRows,
      activeInvoiceLines: _activeSalesInvoiceLines,
      activeInvoiceNumber: _activeSalesInvoiceNumber,
      activeSaleItemId: _activeSalesItemId,
      dateFormat: _dateFormat,
      animateDialogEntrance: _animateDialogEntrance,
      loadInvoiceLines: (id) => _salesRepo.listInvoiceLines(id),
      onSelectLine: (lineId) {
        if (!mounted) return;
        setState(() => _activeSalesItemId = lineId);
      },
      onPrintInvoice: _openPrintPreview,
      onApplyReturn: (saleItemId, quantity) {
        _showSalesReturnDialog(
          initialSaleId: invoiceId,
          initialSaleItemId: saleItemId,
          initialQuantity: quantity,
        );
      },
    );
  }

  Future<void> _loadPurchaseInvoices() async {
    setState(() => _purchasesLoading = true);
    try {
      final rows = await _purchasesRepo.listInvoices(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
        limit: _purchasePageSize,
        offset: _purchasePage * _purchasePageSize,
      );

      if (!mounted) return;
      setState(() {
        _purchaseRows = rows;
        _purchasesLoading = false;
      });
      _scrollToPurchasePreselected();
      if (_activePurchaseInvoiceId != null &&
          !_purchaseRows.any((e) => e.id == _activePurchaseInvoiceId)) {
        setState(() {
          _activePurchaseInvoiceId = null;
          _activePurchaseInvoiceNumber = null;
          _activePurchaseItemId = null;
          _activePurchaseInvoiceLines = const [];
        });
      }
    } catch (e, st) {
      dev.log(
        'Failed loading purchase invoices in hub',
        name: 'InvoicesHubPage',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _purchasesLoading = false);
    }
  }

  void _scrollToPurchasePreselected() {
    final targetId = _activePurchaseInvoiceId;
    if (targetId == null) return;
    final index = _purchaseRows.indexWhere((e) => e.id == targetId);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_purchasesScrollController.hasClients) return;
      final max = _purchasesScrollController.position.maxScrollExtent;
      final offset = (index * 48.0).clamp(0, max).toDouble();
      _purchasesScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _refreshActivePurchaseInvoiceLines(
    int purchaseId, {
    int? preferredItemId,
  }) async {
    final lines = await _purchasesRepo.listInvoiceLines(purchaseId);
    if (!mounted) return;

    PurchaseInvoiceLine? selectedLine;
    if (preferredItemId != null) {
      for (final line in lines) {
        if (line.id == preferredItemId) {
          selectedLine = line;
          break;
        }
      }
    }

    if (selectedLine == null && lines.isNotEmpty) {
      var lineCandidate = lines.first;
      for (final line in lines) {
        if (line.remainingQuantity > lineCandidate.remainingQuantity) {
          lineCandidate = line;
        }
      }
      selectedLine = lineCandidate;
    }

    setState(() {
      _activePurchaseInvoiceLines = lines;
      _activePurchaseItemId = selectedLine?.id;
    });
  }

  Future<void> _selectPurchaseInvoice(PurchaseInvoiceSummary row) async {
    final lines = await _purchasesRepo.listInvoiceLines(row.id);
    PurchaseInvoiceLine? selectedLine;
    if (lines.isNotEmpty) {
      var lineCandidate = lines.first;
      for (final line in lines) {
        if (line.remainingQuantity > lineCandidate.remainingQuantity) {
          lineCandidate = line;
        }
      }
      selectedLine = lineCandidate;
    }
    if (!mounted) return;
    setState(() {
      _activePurchaseInvoiceId = row.id;
      _activePurchaseInvoiceNumber = row.invoiceNumber;
      _activePurchaseInvoiceLines = lines;
      _activePurchaseItemId = selectedLine?.id;
    });
    _showLatestSnackBar(
      context,
      '${buildPurchaseInvoiceLabel(id: row.id, rawInvoiceNumber: row.invoiceNumber)} ${'selected'.tr()}.',
    );
  }

  Future<void> _showPurchaseReturnDialog({
    int? initialPurchaseId,
    int? initialPurchaseItemId,
    double? initialQuantity,
  }) async {
    await PurchasesReturnDialog.show(
      context,
      initialPurchaseId: initialPurchaseId,
      initialPurchaseItemId: initialPurchaseItemId,
      initialQuantity: initialQuantity,
      activeInvoiceId: _activePurchaseInvoiceId,
      activeInvoiceDisplayNumber: _activePurchaseInvoiceNumber,
      activeInvoiceLines: _activePurchaseInvoiceLines,
      parseFlexibleInt: parseFlexibleInt,
      parseFlexibleNumber: parseFlexibleNumber,
      formatInvoiceQuantity: formatInvoiceQuantityValue,
      animateDialogEntrance: _animateDialogEntrance,
      lookupPurchaseInvoiceSuggestion: (id) =>
          _purchasesRepo.lookupPurchaseInvoiceSuggestionForReturn(id),
      searchPurchaseInvoicesForReturn: (prefix) =>
          _purchasesRepo.suggestPurchaseInvoicesForReturn(prefix),
      loadInvoiceLines: (purchaseId) =>
          _purchasesRepo.listInvoiceLines(purchaseId),
      onReturnPurchaseItem:
          ({
            required purchaseId,
            required purchaseItemId,
            required quantity,
          }) async {
            final allowed = await _ensureWriteAllowed();
            if (!allowed) {
              return 'license.read_only_banner'.tr();
            }
            try {
              await _purchasesRepo.returnPurchaseItem(
                purchaseId: purchaseId,
                purchaseItemId: purchaseItemId,
                quantity: quantity,
              );
              await _loadPurchaseInvoices();
              return null;
            } catch (e) {
              return e.toString();
            }
          },
      onRefreshActiveInvoiceLines: _refreshActivePurchaseInvoiceLines,
    );
  }

  Future<void> _showPurchaseCancelDialog({int? initialPurchaseId}) async {
    await PurchasesCancelDialog.show(
      context,
      initialPurchaseId: initialPurchaseId,
      parseFlexibleInt: parseFlexibleInt,
      animateDialogEntrance: _animateDialogEntrance,
      onConfirmCancel: (purchaseId) async {
        final allowed = await _ensureWriteAllowed();
        if (!allowed) {
          return false;
        }
        try {
          await _purchasesRepo.cancelPurchase(purchaseId);
          if (!mounted) return true;
          setState(() {
            _activePurchaseItemId = null;
            _activePurchaseInvoiceLines = const [];
          });
          await _loadPurchaseInvoices();
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<void> _showPurchaseInvoiceDetailsDialog() async {
    final invoiceId = _activePurchaseInvoiceId;
    if (invoiceId == null) return;

    await PurchasesInvoiceDetailsDialog.show(
      context,
      invoiceId: invoiceId,
      invoiceRows: _purchaseRows,
      activeInvoiceNumber: _activePurchaseInvoiceNumber,
      activePurchaseItemId: _activePurchaseItemId,
      dateFormat: _dateFormat,
      purchaseInvoiceLabel: buildPurchaseInvoiceLabel,
      formatInvoiceQuantity: formatInvoiceQuantityValue,
      animateDialogEntrance: _animateDialogEntrance,
      loadInvoiceLines: (purchaseId) async {
        await _refreshActivePurchaseInvoiceLines(
          purchaseId,
          preferredItemId: _activePurchaseItemId,
        );
        return _activePurchaseInvoiceLines;
      },
      onPrintInvoice: _openPrintPreview,
      onApplyReturn: (purchaseItemId, quantity) {
        _showPurchaseReturnDialog(
          initialPurchaseId: invoiceId,
          initialPurchaseItemId: purchaseItemId,
          initialQuantity: quantity,
        );
      },
    );
  }

  Future<void> _openPrintPreview(InvoicePrintModel invoice) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePrintPreviewPage(
          invoice: invoice,
          printManager: _invoicePrintManager,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoices'.tr(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${'Filters'.tr()}: ${widget.fromDate == null ? 'Any date'.tr() : DateFormat('yyyy-MM-dd').format(widget.fromDate!)} - ${widget.toDate == null ? 'Any date'.tr() : DateFormat('yyyy-MM-dd').format(widget.toDate!)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(text: 'Sales Invoices'.tr()),
              Tab(text: 'Purchase Invoices'.tr()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    return SalesInvoicesExplorer(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      accountId: widget.accountId,
      categoryId: widget.categoryId,
      loadingInvoices: _salesLoading,
      invoiceRows: _salesRows,
      invoiceScrollController: _salesScrollController,
      activeInvoiceId: _activeSalesInvoiceId,
      activeInvoiceNumber: _activeSalesInvoiceNumber,
      canCompletePendingSelected:
          _activeSalesInvoiceId != null &&
          _salesRows.any(
            (row) => row.id == _activeSalesInvoiceId && row.status == 'pending',
          ),
      activeSaleItemId: _activeSalesItemId,
      selectedTypeFilter: _salesTypeFilter,
      invoiceTypeCounts: _salesTypeCounts,
      invoicePage: _salesPage,
      invoicePageSize: _salesPageSize,
      onSelectInvoice: _selectSalesInvoice,
      onReturnSelected: () => _showSalesReturnDialog(
        initialSaleId: _activeSalesInvoiceId,
        initialSaleItemId: _activeSalesItemId,
      ),
      onCancelSelected: () =>
          _showSalesCancelDialog(initialSaleId: _activeSalesInvoiceId),
      onShowDetails: _showSalesInvoiceDetailsDialog,
      onGeneratePdfSelected: () {
        final id = _activeSalesInvoiceId;
        if (id == null) return;
        _generateSalesPdf(id);
      },
      onCompletePendingSelected: () {
        final id = _activeSalesInvoiceId;
        if (id == null) return;
        context.go('/sales?selectedInvoiceId=$id&navSource=invoices');
      },
      onTypeFilterChanged: (filter) {
        setState(() {
          _salesTypeFilter = filter;
          _salesPage = 0;
          _activeSalesInvoiceId = null;
          _activeSalesInvoiceNumber = null;
          _activeSalesItemId = null;
          _activeSalesInvoiceLines = const [];
        });
        _loadSalesInvoices();
      },
      onPreviousPage: () {
        setState(() => _salesPage -= 1);
        _loadSalesInvoices();
      },
      onNextPage: () {
        setState(() => _salesPage += 1);
        _loadSalesInvoices();
      },
    );
  }

  Widget _buildPurchasesTab() {
    return PurchasesInvoicesExplorer(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      accountId: widget.accountId,
      categoryId: widget.categoryId,
      loadingInvoices: _purchasesLoading,
      invoiceRows: _purchaseRows,
      invoiceScrollController: _purchasesScrollController,
      activeInvoiceId: _activePurchaseInvoiceId,
      activeInvoiceNumber: _activePurchaseInvoiceNumber,
      activePurchaseItemId: _activePurchaseItemId,
      invoicePage: _purchasePage,
      invoicePageSize: _purchasePageSize,
      invoiceLabelBuilder: buildPurchaseInvoiceLabel,
      onSelectInvoice: _selectPurchaseInvoice,
      onReturnSelected: () => _showPurchaseReturnDialog(
        initialPurchaseId: _activePurchaseInvoiceId,
        initialPurchaseItemId: _activePurchaseItemId,
      ),
      onShowDetails: _showPurchaseInvoiceDetailsDialog,
      onCancelSelected: () => _showPurchaseCancelDialog(
        initialPurchaseId: _activePurchaseInvoiceId,
      ),
      onPreviousPage: () {
        setState(() => _purchasePage -= 1);
        _loadPurchaseInvoices();
      },
      onNextPage: () {
        setState(() => _purchasePage += 1);
        _loadPurchaseInvoices();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final isVeryDense = viewport.height < 720;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isVeryDense ? 12 : 20,
        isVeryDense ? 10 : 18,
        isVeryDense ? 12 : 20,
        isVeryDense ? 10 : 18,
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          Expanded(
            child: IndexedStack(
              index: _tabController.index,
              children: [_buildSalesTab(), _buildPurchasesTab()],
            ),
          ),
        ],
      ),
    );
  }
}
