part of 'sales_page.dart';

class _SalesPageState extends State<SalesPage> {
  final _productRepo = getIt<ProductRepository>();
  final _accountsRepo = getIt<AccountsRepository>();
  final _pdfService = getIt<SalesInvoicePdfService>();
  final _invoiceScrollController = ScrollController();
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool? _printInvoiceAfterCheckout;
  final _invoicePrintPreferences = const InvoicePrintPreferences();
  late final InvoicePrintModelFactory _invoicePrintFactory =
      InvoicePrintModelFactory(
        getIt<SaleInvoicePrintDataBuilder>(),
        getIt<PurchasesRepository>(),
        getIt<AppDatabase>(),
        getIt<CompanySettingsService>(),
      );
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

  final _nameSearchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  final _paidController = TextEditingController();
  final _paidWalletController = TextEditingController();
  final _headerDiscountValueController = TextEditingController();
  final _newCustomerController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _licenseService = getIt<LicenseService>();
  Timer? _barcodeDebounce;
  int _barcodeLookupGeneration = 0;
  bool _readOnlyMode = false;
  String? _readOnlyMessage;

  List<AccountLookup> _customers = const [];
  List<SalesInvoiceSummary> _invoiceRows = const [];
  // ignore: unused_field
  Map<SalesInvoiceTypeFilter, int> _invoiceTypeCounts =
      const <SalesInvoiceTypeFilter, int>{};
  // ignore: unused_field
  bool _loadingInvoices = false;
  int _invoicePage = 0;
  int _invoicePageSize = 50;
  // ignore: prefer_final_fields
  SalesInvoiceTypeFilter _invoiceTypeFilter = SalesInvoiceTypeFilter.all;
  int? _activeInvoiceId;
  String? _activeInvoiceNumber;
  int? _loadedPendingSaleId;
  int? _activeSaleItemId;
  List<SalesInvoiceLine> _activeInvoiceLines = const [];
  final Map<int, String> _inlineQuantityDrafts = <int, String>{};
  final Map<int, String> _inlineDiscountDrafts = <int, String>{};
  final Map<int, TextEditingController> _inlineQtyControllers =
      <int, TextEditingController>{};
  final Map<int, FocusNode> _inlineQtyFocusNodes = <int, FocusNode>{};
  final Map<int, TextEditingController> _inlineDiscountControllers =
      <int, TextEditingController>{};
  final Map<int, FocusNode> _inlineDiscountFocusNodes = <int, FocusNode>{};
  _SalePriceTier _selectedSalePriceTier = _SalePriceTier.retail;

  void _resetCartPaymentControllers() {
    _paidController.clear();
    _paidWalletController.clear();
    _headerDiscountValueController.clear();
    _newCustomerController.clear();
    _customerPhoneController.clear();
  }

  void _showLatestSnackBar(BuildContext targetContext, String message) {
    if (!mounted || !targetContext.mounted) return;
    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _invoicePage = widget.initialInvoicePage < 0
        ? 0
        : widget.initialInvoicePage;
    _invoicePageSize = widget.invoicePageSize <= 0
        ? 50
        : widget.invoicePageSize;
    _activeInvoiceId = widget.selectedInvoiceId;
    _loadCustomers();
    _loadInvoices();
    _refreshWritePermissionStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selectedInvoiceId == null) return;
      _showLatestSnackBar(
        context,
        '${'Opened from'.tr()} ${widget.navSource ?? 'navigation'.tr()}: ${'invoice'.tr()} #${widget.selectedInvoiceId} ${'highlighted'.tr()}.',
      );
    });
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

  Future<void> _loadCustomers() async {
    final items = await _accountsRepo.listByType('customer');
    if (!mounted) return;
    setState(() => _customers = items);
  }

  String? _phoneForCustomerId(int? customerId) {
    if (customerId == null) return null;
    for (final c in _customers) {
      if (c.id == customerId) {
        return c.phone;
      }
    }
    return null;
  }

  void _backfillCustomerPhoneIfNeeded(int? customerId, String currentPhone) {
    if (customerId == null || currentPhone.trim().isNotEmpty) return;
    final phone = _phoneForCustomerId(customerId)?.trim() ?? '';
    if (phone.isEmpty) return;
    _customerPhoneController.text = phone;
    if (mounted) {
      context.read<SalesCubit>().setCustomerPhone(phone);
    }
  }

  Future<bool> _ensureSalesWriteAllowed() async {
    final permission = await _licenseService.checkWritePermission();
    if (permission.isValid) {
      if (mounted && _readOnlyMode) {
        setState(() {
          _readOnlyMode = false;
          _readOnlyMessage = null;
        });
      }
      return true;
    }

    if (mounted) {
      final deniedMessage = _localizedLicenseWriteMessage(permission.code);
      setState(() {
        _readOnlyMode = true;
        _readOnlyMessage = deniedMessage;
      });
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

  Future<void> _refreshWritePermissionStatus() async {
    final permission = await _licenseService.checkWritePermission();
    if (!mounted) return;
    final deniedMessage = _localizedLicenseWriteMessage(permission.code);
    setState(() {
      _readOnlyMode = !permission.isValid;
      _readOnlyMessage = permission.isValid ? null : deniedMessage;
    });
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

  Future<bool?> _confirmPrintInvoiceAfterCheckout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('checkout.print_invoice_prompt'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('checkout.print_invoice_no'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('checkout.print_invoice_yes'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _printSaleInvoiceDirect(int saleId) async {
    try {
      final model = await _invoicePrintFactory.buildForSale(saleId);
      if (model == null || !mounted) return;
      final config = await _invoicePrintPreferences.load();
      await _invoicePrintManager.printInvoice(model, config);
    } catch (e) {
      if (!mounted) return;
      _showLatestSnackBar(context, '${'Failed to print invoice'.tr()}: $e');
    }
  }

  Future<void> _attemptCheckout(SalesCubit cubit, SalesState state) async {
    final allowed = await _ensureSalesWriteAllowed();
    if (!allowed) return;
    if (!mounted) return;

    final qtyOk = _commitInlineQuantityDrafts(context, state.cart);
    if (!qtyOk) return;
    final discountOk = _commitInlineDiscountDrafts(context, state.cart);
    if (!discountOk) return;

    _printInvoiceAfterCheckout = null;
    if (state.editingSaleId == null && _loadedPendingSaleId == null) {
      _printInvoiceAfterCheckout = await _confirmPrintInvoiceAfterCheckout(
        context,
      );
    }

    if (state.editingSaleId != null) {
      final saleId = state.editingSaleId!;
      try {
        final preview = await getIt<SalesRepository>().previewAmendRefund(
          SaleAmendRequest(
            saleId: saleId,
            items: state.cart,
            headerDiscountKind: state.headerDiscountKind,
            headerDiscountValue: state.headerDiscountValue,
            paymentMethod: state.paymentMethod,
          ),
        );
        if (!mounted) return;
        AmendCollectConfirmation? collectConfirmation;
        AmendRefundConfirmation? refundConfirmation;
        if (preview.totalDelta > 0.000001) {
          collectConfirmation = await SalesAmendPaymentDialog.show(
            context,
            preview: preview,
            parseFlexibleNumber: _parseFlexibleNumber,
          );
          if (!mounted) return;
          if (collectConfirmation == null) return;
        } else if (preview.maxRefundable > 0.000001) {
          refundConfirmation = await SalesAmendRefundDialog.show(
            context,
            preview: preview,
            parseFlexibleNumber: _parseFlexibleNumber,
          );
          if (!mounted) return;
          if (refundConfirmation == null) return;
        }
        cubit.checkout(
          amendRefundAmountOverride: refundConfirmation?.refundAmountOverride,
          amendRefundCashOverride: refundConfirmation?.refundCashOverride,
          amendRefundWalletOverride: refundConfirmation?.refundWalletOverride,
          positiveAmendmentHandling: collectConfirmation?.handling,
          collectPaymentMethod: collectConfirmation?.paymentMethod,
          collectAmount: collectConfirmation?.collectAmount,
          collectWalletAmount: collectConfirmation?.collectWalletAmount,
        );
      } catch (e) {
        if (!mounted) return;
        _showLatestSnackBar(context, e.toString());
      }
      return;
    }

    cubit.checkout(pendingSaleIdOverride: _loadedPendingSaleId);
  }

  Future<void> _attemptSavePendingInvoice(
    SalesCubit cubit,
    SalesState state,
  ) async {
    final allowed = await _ensureSalesWriteAllowed();
    if (!allowed) return;
    if (!mounted) return;

    final qtyOk = _commitInlineQuantityDrafts(context, state.cart);
    if (!qtyOk) return;
    final discountOk = _commitInlineDiscountDrafts(context, state.cart);
    if (!discountOk) return;
    cubit.checkout(isPending: true);
  }

  Future<void> _loadInvoices() async {
    setState(() => _loadingInvoices = true);
    try {
      final statuses = switch (_invoiceTypeFilter) {
        SalesInvoiceTypeFilter.all => null,
        SalesInvoiceTypeFilter.completed => <String>['completed'],
        SalesInvoiceTypeFilter.credit => <String>['partial'],
        SalesInvoiceTypeFilter.pending => <String>['pending'],
      };

      final countsRaw = await getIt<SalesRepository>().countInvoicesByStatus(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
      );

      final completedCount = countsRaw['completed'] ?? 0;
      final creditCount = countsRaw['partial'] ?? 0;
      final pendingCount = countsRaw['pending'] ?? 0;
      final allCount = completedCount + creditCount + pendingCount;

      final rows = await getIt<SalesRepository>().listInvoices(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
        statuses: statuses,
        limit: _invoicePageSize,
        offset: _invoicePage * _invoicePageSize,
      );
      if (!mounted) return;
      setState(() {
        _invoiceRows = rows;
        _invoiceTypeCounts = {
          SalesInvoiceTypeFilter.all: allCount,
          SalesInvoiceTypeFilter.completed: completedCount,
          SalesInvoiceTypeFilter.credit: creditCount,
          SalesInvoiceTypeFilter.pending: pendingCount,
        };
        _loadingInvoices = false;
      });
      _scrollToPreselected();
      if (_activeInvoiceId != null &&
          !_invoiceRows.any((e) => e.id == _activeInvoiceId)) {
        setState(() {
          _activeInvoiceId = null;
          _activeInvoiceNumber = null;
          _activeSaleItemId = null;
          _activeInvoiceLines = const [];
        });
      }
    } catch (e, st) {
      dev.log(
        'Failed loading sales invoices for navigation context',
        name: 'SalesPage',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _loadingInvoices = false);
    }
  }

  void _scrollToPreselected() {
    final targetId = _activeInvoiceId;
    if (targetId == null) return;
    final index = _invoiceRows.indexWhere((e) => e.id == targetId);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_invoiceScrollController.hasClients) return;
      final max = _invoiceScrollController.position.maxScrollExtent;
      final offset = (index * 48.0).clamp(0, max).toDouble();
      _invoiceScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _searchBarcodeAndAdd(
    BuildContext context,
    String barcode, {
    bool notifyOnNoMatch = true,
  }) async {
    final trimmed = normalizePosBarcodeInput(barcode);
    if (trimmed.isEmpty) return;
    final gen = ++_barcodeLookupGeneration;
    final items = await _productRepo.listProducts(barcode: trimmed);
    if (!mounted || gen != _barcodeLookupGeneration) return;
    if (items.isEmpty) {
      if (notifyOnNoMatch && context.mounted) {
        _showLatestSnackBar(context, 'No product matches this barcode.'.tr());
        refocusBarcodeForNextScan(
          focus: _barcodeFocusNode,
          controller: _barcodeController,
        );
      }
      return;
    }
    if (!context.mounted) return;
    context.read<SalesCubit>().addProduct(
      items.first,
      initialUnitPrice: _resolveSalePriceByTier(items.first),
    );
    _barcodeController.clear();
    refocusBarcodeForNextScan(
      focus: _barcodeFocusNode,
      controller: _barcodeController,
    );
  }

  void _onBarcodeFieldChanged(BuildContext context, String _) {
    _barcodeDebounce?.cancel();
    _barcodeDebounce = Timer(kPosBarcodeDebounce, () {
      if (!mounted) return;
      unawaited(
        _searchBarcodeAndAdd(
          context,
          _barcodeController.text,
          notifyOnNoMatch: false,
        ),
      );
    });
  }

  void _onBarcodeFieldSubmitted(BuildContext context, String value) {
    _barcodeDebounce?.cancel();
    unawaited(_searchBarcodeAndAdd(context, value, notifyOnNoMatch: true));
  }

  double _resolveSalePriceByTier(Product product) {
    switch (_selectedSalePriceTier) {
      case _SalePriceTier.retail:
        return product.salePrice;
      case _SalePriceTier.halfWholesale:
        return product.salePriceHalfWholesale;
      case _SalePriceTier.wholesale:
        return product.salePriceWholesale;
    }
  }

  Future<void> _applySelectedPriceTierToCart(
    BuildContext context,
    List<SaleDraftItem> cart,
  ) async {
    if (cart.isEmpty) return;
    final ids = cart.map((e) => e.productId).toSet().toList();
    final products = await _productRepo.listProductsByIds(ids);
    if (!mounted || !context.mounted) return;

    final productById = <int, Product>{
      for (final product in products)
        if (product.id != null) product.id!: product,
    };

    final cubit = context.read<SalesCubit>();
    for (final item in cart) {
      final product = productById[item.productId];
      if (product == null) continue;
      cubit.updateItem(
        item.productId,
        unitPrice: _resolveSalePriceByTier(product),
      );
    }
  }

  String _salePriceTierLabel(_SalePriceTier tier) {
    switch (tier) {
      case _SalePriceTier.retail:
        return 'Retail'.tr();
      case _SalePriceTier.halfWholesale:
        return 'Half Wholesale'.tr();
      case _SalePriceTier.wholesale:
        return 'Wholesale'.tr();
    }
  }

  @override
  void dispose() {
    _barcodeDebounce?.cancel();
    _nameSearchController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _nameFocusNode.dispose();
    _paidController.dispose();
    _paidWalletController.dispose();
    _headerDiscountValueController.dispose();
    _newCustomerController.dispose();
    _customerPhoneController.dispose();
    _invoiceScrollController.dispose();
    for (final controller in _inlineQtyControllers.values) {
      controller.dispose();
    }
    for (final node in _inlineQtyFocusNodes.values) {
      node.dispose();
    }
    for (final controller in _inlineDiscountControllers.values) {
      controller.dispose();
    }
    for (final node in _inlineDiscountFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
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

  String _formatQuantity(SaleDraftItem item) {
    if (item.unitType == UnitType.piece.name) {
      final nearestInt = item.quantity.roundToDouble();
      if ((item.quantity - nearestInt).abs() < 0.000001) {
        return item.quantity.toStringAsFixed(0);
      }
    }
    return item.quantity.toStringAsFixed(0);
  }

  String _formatDiscount(SaleDraftItem item) {
    return item.discount.toStringAsFixed(2);
  }

  bool _applyInlineQuantityChange(
    BuildContext context,
    SaleDraftItem item,
    String raw, {
    bool showFeedback = true,
  }) {
    final parsed = _parseFlexibleNumber(raw);
    if (parsed == null) {
      if (showFeedback) {
        _showLatestSnackBar(context, 'Enter a valid quantity.'.tr());
      }
      return false;
    }

    if (parsed <= 0) {
      context.read<SalesCubit>().removeItem(item.productId);
      return true;
    }

    if (item.unitType == UnitType.piece.name &&
        parsed != parsed.roundToDouble()) {
      if (showFeedback) {
        _showLatestSnackBar(
          context,
          'Piece products require integer quantity.'.tr(),
        );
      }
      return false;
    }

    if (parsed > item.availableStock + 0.000001) {
      if (showFeedback) {
        _showLatestSnackBar(
          context,
          'Cannot sell more than available stock.'.tr(),
        );
      }
      return false;
    }

    context.read<SalesCubit>().updateItem(item.productId, quantity: parsed);
    return true;
  }

  bool _commitInlineQuantityDrafts(
    BuildContext context,
    List<SaleDraftItem> cart,
  ) {
    if (_inlineQuantityDrafts.isEmpty) return true;

    for (final item in cart) {
      final draft = _inlineQuantityDrafts[item.productId];
      if (draft == null || draft.trim().isEmpty) continue;
      final ok = _applyInlineQuantityChange(context, item, draft);
      if (!ok) {
        return false;
      }
      _inlineQuantityDrafts.remove(item.productId);
    }

    return true;
  }

  bool _applyInlineDiscountChange(
    BuildContext context,
    SaleDraftItem item,
    String raw, {
    bool showFeedback = true,
  }) {
    final parsed = _parseFlexibleNumber(raw);
    if (parsed == null) {
      if (showFeedback) {
        _showLatestSnackBar(context, 'Enter a valid amount.'.tr());
      }
      return false;
    }

    final clampedDiscount = parsed < 0 ? 0.0 : parsed;
    final gross = roundCurrency(item.quantity * item.unitPrice);
    if (clampedDiscount > gross + 0.000001) {
      if (showFeedback) {
        _showLatestSnackBar(context, 'Discount cannot exceed line total.'.tr());
      }
      return false;
    }

    context.read<SalesCubit>().updateItem(
      item.productId,
      discount: clampedDiscount,
    );
    return true;
  }

  bool _commitInlineDiscountDrafts(
    BuildContext context,
    List<SaleDraftItem> cart,
  ) {
    if (_inlineDiscountDrafts.isEmpty) return true;

    for (final item in cart) {
      final draft = _inlineDiscountDrafts[item.productId];
      if (draft == null || draft.trim().isEmpty) continue;
      final ok = _applyInlineDiscountChange(context, item, draft);
      if (!ok) {
        return false;
      }
      _inlineDiscountDrafts.remove(item.productId);
    }

    return true;
  }

  void _syncInlineQuantityEditors(List<SaleDraftItem> cart) {
    final activeIds = cart.map((item) => item.productId).toSet();

    final staleControllers = _inlineQtyControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleControllers) {
      _inlineQtyControllers.remove(id)?.dispose();
    }

    final staleNodes = _inlineQtyFocusNodes.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleNodes) {
      _inlineQtyFocusNodes.remove(id)?.dispose();
      _inlineQuantityDrafts.remove(id);
    }
  }

  void _syncInlineDiscountEditors(List<SaleDraftItem> cart) {
    final activeIds = cart.map((item) => item.productId).toSet();

    final staleControllers = _inlineDiscountControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleControllers) {
      _inlineDiscountControllers.remove(id)?.dispose();
    }

    final staleNodes = _inlineDiscountFocusNodes.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleNodes) {
      _inlineDiscountFocusNodes.remove(id)?.dispose();
      _inlineDiscountDrafts.remove(id);
    }
  }

  TextEditingController _qtyControllerFor(SaleDraftItem item) {
    return _inlineQtyControllers.putIfAbsent(
      item.productId,
      () => TextEditingController(text: _formatQuantity(item)),
    );
  }

  FocusNode _qtyFocusNodeFor(
    SaleDraftItem item,
    TextEditingController controller,
  ) {
    return _inlineQtyFocusNodes.putIfAbsent(item.productId, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      });
      return node;
    });
  }

  TextEditingController _discountControllerFor(SaleDraftItem item) {
    return _inlineDiscountControllers.putIfAbsent(
      item.productId,
      () => TextEditingController(text: _formatDiscount(item)),
    );
  }

  FocusNode _discountFocusNodeFor(
    SaleDraftItem item,
    TextEditingController controller,
  ) {
    return _inlineDiscountFocusNodes.putIfAbsent(item.productId, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      });
      return node;
    });
  }

  bool _hasInvalidInlineDrafts(List<SaleDraftItem> cart) {
    for (final item in cart) {
      final draft = _inlineQuantityDrafts[item.productId];
      if (draft == null || draft.trim().isEmpty) continue;

      final parsed = _parseFlexibleNumber(draft);
      if (parsed == null) return true;
      if (parsed <= 0) return true;
      if (item.unitType == UnitType.piece.name &&
          parsed != parsed.roundToDouble()) {
        return true;
      }
      if (parsed > item.availableStock + 0.000001) return true;
    }
    for (final item in cart) {
      final draft = _inlineDiscountDrafts[item.productId];
      if (draft == null || draft.trim().isEmpty) continue;

      final parsed = _parseFlexibleNumber(draft);
      if (parsed == null) return true;
      if (parsed < 0) return true;
      final gross = roundCurrency(item.quantity * item.unitPrice);
      if (parsed > gross + 0.000001) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesCubit, SalesState>(
      listenWhen: (previous, current) {
        if (previous.total == current.total) return false;
        if (current.editingSaleId != null) return false;
        if (current.pendingSaleId != null) return false;
        return true;
      },
      listener: (context, state) {
        final cubit = context.read<SalesCubit>();
        final total = state.total;
        cubit.setPaidAmount(total);
        cubit.setPaidWalletAmount(0);
        _paidController.text = total == 0 ? '' : total.toStringAsFixed(2);
        _paidWalletController.text = '';
      },
      child: BlocConsumer<SalesCubit, SalesState>(
        listenWhen: (previous, current) {
          return previous.successInvoiceId != current.successInvoiceId ||
              previous.successEvent != current.successEvent ||
              previous.error != current.error;
        },
        listener: (context, state) {
          var shouldClearTransient = false;
          var shouldClearError = false;

          if (state.successInvoiceId != null) {
            final event = state.successEvent ?? 'sale_saved';
            final invoiceId = state.successInvoiceId!;
            if (_printInvoiceAfterCheckout == true &&
                event != 'pending_saved' &&
                event != 'sale_amended') {
              unawaited(_printSaleInvoiceDirect(invoiceId));
            }
            _printInvoiceAfterCheckout = null;
            if (event == 'pending_completed' || event == 'sale_amended') {
              _loadedPendingSaleId = null;
            }
            if (mounted) {
              setState(() {
                _invoicePage = 0;
                _activeInvoiceId = state.successInvoiceId;
                if (event == 'sale_amended') {
                  _activeSaleItemId = null;
                } else {
                  _activeInvoiceNumber = null;
                  _activeSaleItemId = null;
                  _activeInvoiceLines = const [];
                }
              });
            }
            if (event == 'sale_amended' && state.successInvoiceId != null) {
              unawaited(_refreshActiveInvoiceLines(state.successInvoiceId!));
            }
            _loadInvoices();
            if (event == 'sale_saved') {
              unawaited(_loadCustomers());
            }
            final successMessage = switch (event) {
              'pending_saved' =>
                '${'Pending invoice saved'.tr()}: #${state.successInvoiceId}',
              'pending_completed' =>
                '${'Pending invoice completed'.tr()}: #${state.successInvoiceId}',
              'sale_amended' => 'sale.amended_success'.tr(
                namedArgs: {'id': '${state.successInvoiceId}'},
              ),
              _ => '${'Sale saved'.tr()}: #${state.successInvoiceId}',
            };
            _showLatestSnackBar(context, successMessage);
            if (event != 'pending_completed') {
              _nameSearchController.clear();
              _barcodeController.clear();
              refocusBarcodeForNextScan(
                focus: _barcodeFocusNode,
                controller: _barcodeController,
              );
              _paidController.clear();
              _paidWalletController.clear();
              _headerDiscountValueController.clear();
              _newCustomerController.clear();
              _customerPhoneController.clear();
            }
            shouldClearTransient = true;
          }
          if (state.successEvent == 'pending_loaded') {
            _loadedPendingSaleId = state.pendingSaleId;
            _headerDiscountValueController.text = state.headerDiscountValue == 0
                ? ''
                : state.headerDiscountValue.toStringAsFixed(2);
            _paidController.text = '0';
            _paidWalletController.text = '';
            _newCustomerController.text = state.newCustomerName;
            _customerPhoneController.text = state.customerPhone;
            _backfillCustomerPhoneIfNeeded(
              state.customerId,
              state.customerPhone,
            );
            if (mounted) {
              setState(() {
                _activeInvoiceId = null;
                _activeInvoiceNumber = null;
                _activeSaleItemId = null;
                _activeInvoiceLines = const [];
              });
            }
            _showLatestSnackBar(
              context,
              'Pending invoice loaded to cart.'.tr(),
            );
            shouldClearTransient = true;
          }
          if (state.successEvent == 'invoice_amendment_loaded') {
            _loadedPendingSaleId = null;
            _headerDiscountValueController.text = state.headerDiscountValue == 0
                ? ''
                : state.headerDiscountValue.toStringAsFixed(2);
            _paidController.text = state.paidAmount == 0
                ? ''
                : state.paidAmount.toStringAsFixed(2);
            _paidWalletController.text = state.paidWalletAmount == 0
                ? ''
                : state.paidWalletAmount.toStringAsFixed(2);
            _newCustomerController.text = state.newCustomerName;
            _customerPhoneController.text = state.customerPhone;
            _backfillCustomerPhoneIfNeeded(
              state.customerId,
              state.customerPhone,
            );
            if (mounted && state.editingSaleId != null) {
              unawaited(_refreshActiveInvoiceLines(state.editingSaleId!));
            }
            _showLatestSnackBar(
              context,
              'sale.invoice_amendment_loaded_hint'.tr(),
            );
            shouldClearTransient = true;
          }
          if (state.error != null) {
            _showLatestSnackBar(context, state.error!.tr());
            shouldClearTransient = true;
            shouldClearError = true;
          }
          if (shouldClearTransient) {
            context.read<SalesCubit>().clearTransientFeedback(
              clearError: shouldClearError,
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<SalesCubit>();
          _syncInlineQuantityEditors(state.cart);
          _syncInlineDiscountEditors(state.cart);
          final hasInvalidInlineDrafts = _hasInvalidInlineDrafts(state.cart);
          final viewport = MediaQuery.sizeOf(context);
          final isShortViewport = viewport.height < 900;
          final isVeryDenseViewport = viewport.height < 720;
          final sectionGap = isVeryDenseViewport
              ? 10.0
              : (isShortViewport ? 12.0 : 16.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              isVeryDenseViewport ? 12 : (isShortViewport ? 16 : 24),
              isVeryDenseViewport ? 10 : (isShortViewport ? 12 : 24),
              isVeryDenseViewport ? 12 : (isShortViewport ? 16 : 24),
              isVeryDenseViewport ? 10 : (isShortViewport ? 12 : 24),
            ),
            child: Column(
              children: [
                if (_readOnlyMode) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isVeryDenseViewport ? 10 : 12,
                      vertical: isVeryDenseViewport ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.tertiary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      _readOnlyMessage ?? 'license.read_only_banner'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                ],
                SalesCheckoutToolbar(
                  veryDense: isVeryDenseViewport,
                  colorScheme: Theme.of(context).colorScheme,
                  nameFocusNode: _nameFocusNode,
                  nameSearchController: _nameSearchController,
                  barcodeController: _barcodeController,
                  barcodeFocusNode: _barcodeFocusNode,
                  searchProducts: (q) =>
                      _productRepo.listProducts(nameQuery: q, limit: 72),
                  onProductSelected: (item) {
                    _nameSearchController.clear();
                    context.read<SalesCubit>().addProduct(
                      item,
                      initialUnitPrice: _resolveSalePriceByTier(item),
                    );
                  },
                  onBarcodeChanged: (value) =>
                      _onBarcodeFieldChanged(context, value),
                  onBarcodeSubmitted: (value) =>
                      _onBarcodeFieldSubmitted(context, value),
                ),
                SizedBox(height: sectionGap),
                Expanded(
                  child: SalesCartPane(
                    veryDense: isVeryDenseViewport,
                    total: state.total,
                    effectivePaidTotal: state.effectivePaidTotal,
                    loading: state.loading,
                    hasInvalidInlineDrafts: hasInvalidInlineDrafts,
                    successInvoiceId: state.successInvoiceId,
                    priceTierSelector: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _SalePriceTier.values
                          .map(
                            (tier) => ChoiceChip(
                              selected: _selectedSalePriceTier == tier,
                              label: Text(_salePriceTierLabel(tier)),
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() {
                                  _selectedSalePriceTier = tier;
                                });
                                _applySelectedPriceTierToCart(
                                  context,
                                  state.cart,
                                );
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    cartContent: _buildCartTableContent(context, state, cubit),
                    customers: _customers,
                    customerId: state.customerId,
                    newCustomerController: _newCustomerController,
                    customerPhoneController: _customerPhoneController,
                    headerDiscountKind: state.headerDiscountKind,
                    headerDiscountValueController:
                        _headerDiscountValueController,
                    paidController: _paidController,
                    paidWalletController: _paidWalletController,
                    headerDiscountAmount: state.headerDiscountAmount,
                    paymentMethod: state.paymentMethod,
                    onCustomerChanged: (value) {
                      final phone = _phoneForCustomerId(value);
                      final t = phone?.trim() ?? '';
                      context.read<SalesCubit>().selectCustomer(
                        value,
                        phone: t,
                      );
                      _customerPhoneController.text = t;
                      if (value != null) {
                        _newCustomerController.clear();
                      }
                    },
                    onNewCustomerNameChanged: context
                        .read<SalesCubit>()
                        .setNewCustomerName,
                    onCustomerPhoneChanged: context
                        .read<SalesCubit>()
                        .setCustomerPhone,
                    onHeaderDiscountKindChanged: (kind) =>
                        context.read<SalesCubit>().setHeaderDiscountKind(kind),
                    onHeaderDiscountValueChanged: (v) => context
                        .read<SalesCubit>()
                        .setHeaderDiscountValue(_parseFlexibleNumber(v) ?? 0),
                    onPaidChanged: (v) => context
                        .read<SalesCubit>()
                        .setPaidAmount(_parseFlexibleNumber(v) ?? 0),
                    onPaidWalletChanged: (v) => context
                        .read<SalesCubit>()
                        .setPaidWalletAmount(_parseFlexibleNumber(v) ?? 0),
                    onPaymentMethodChanged: (value) {
                      context.read<SalesCubit>().setPaymentMethod(value);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        final updated = context.read<SalesCubit>().state;
                        _paidController.text = updated.paidAmount == 0
                            ? ''
                            : updated.paidAmount.toStringAsFixed(2);
                        _paidWalletController.text =
                            updated.paidWalletAmount == 0
                            ? ''
                            : updated.paidWalletAmount.toStringAsFixed(2);
                      });
                    },
                    onCompleteSale: () => _attemptCheckout(cubit, state),
                    onSavePendingSale: () =>
                        _attemptSavePendingInvoice(cubit, state),
                    onReturnFromInvoice: () => _showReturnDialog(context),
                    onCancelInvoice: () => _showCancelSaleDialog(context),
                    onGeneratePdf: () {
                      final invoiceId = state.successInvoiceId;
                      if (invoiceId == null) return;
                      _generatePdf(context, invoiceId);
                    },
                    invoiceAmendmentMode: state.editingSaleId != null,
                    onCancelInvoiceAmendment: () {
                      cubit.clearInvoiceAmendment();
                      if (!mounted) return;
                      _resetCartPaymentControllers();
                    },
                    readOnlyMode: _readOnlyMode,
                    readOnlyMessage: _readOnlyMessage,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartTableContent(
    BuildContext context,
    SalesState state,
    SalesCubit cubit,
  ) {
    return SalesCartTable(
      cart: state.cart,
      invoiceAmendmentMode: state.editingSaleId != null,
      pieceUnitTypeName: UnitType.piece.name,
      inlineQuantityDrafts: _inlineQuantityDrafts,
      inlineDiscountDrafts: _inlineDiscountDrafts,
      qtyControllerFor: _qtyControllerFor,
      qtyFocusNodeFor: _qtyFocusNodeFor,
      discountControllerFor: _discountControllerFor,
      discountFocusNodeFor: _discountFocusNodeFor,
      formatQuantity: _formatQuantity,
      formatDiscount: _formatDiscount,
      parseFlexibleNumber: _parseFlexibleNumber,
      onQuantityDraftChanged: (item, value) {
        setState(() {
          _inlineQuantityDrafts[item.productId] = value;
        });
      },
      onApplyInlineQuantity: (item, value) {
        _applyInlineQuantityChange(context, item, value);
      },
      onQuantityDraftCleared: (productId) {
        setState(() {
          _inlineQuantityDrafts.remove(productId);
        });
      },
      onDiscountDraftChanged: (item, value) {
        setState(() {
          _inlineDiscountDrafts[item.productId] = value;
        });
      },
      onApplyInlineDiscount: (item, value) {
        _applyInlineDiscountChange(context, item, value);
      },
      onDiscountDraftCleared: (productId) {
        setState(() {
          _inlineDiscountDrafts.remove(productId);
        });
      },
      onRemoveItem: cubit.removeItem,
      onUpdateItemQuantity: (productId, quantity) {
        cubit.updateItem(productId, quantity: quantity);
      },
      onUpdateItemDiscount: (productId, discount) {
        cubit.updateItem(productId, discount: discount);
      },
    );
  }

  Future<void> _showReturnDialog(
    BuildContext context, {
    int? initialSaleId,
    int? initialSaleItemId,
    double? initialQuantity,
  }) async {
    final salesCubit = context.read<SalesCubit>();
    await SalesReturnDialog.show(
      context,
      initialSaleId: initialSaleId,
      initialSaleItemId: initialSaleItemId,
      initialQuantity: initialQuantity,
      parseFlexibleInt: _parseFlexibleInt,
      parseFlexibleNumber: _parseFlexibleNumber,
      lookupSaleInvoiceSuggestion: (id) =>
          getIt<SalesRepository>().lookupSaleInvoiceSuggestionForReturn(id),
      searchSaleInvoicesForReturn: (prefix) =>
          getIt<SalesRepository>().suggestSaleInvoicesForReturn(prefix),
      loadInvoiceLines: (saleId) =>
          getIt<SalesRepository>().listInvoiceLines(saleId),
      loadPaymentSnapshot: (saleId) =>
          getIt<SalesRepository>().loadSalePaymentSnapshot(saleId),
      previewMaxRefund:
          ({required saleId, required saleItemId, required quantity}) =>
              getIt<SalesRepository>().previewMaxRefundForReturnLine(
                saleId: saleId,
                saleItemId: saleItemId,
                quantity: quantity,
              ),
      onReturnSaleItem:
          ({
            required saleId,
            required saleItemId,
            required quantity,
            required paymentMethod,
            refundAmount,
            refundCash,
            refundWallet,
          }) async {
            final allowed = await _ensureSalesWriteAllowed();
            if (!allowed) {
              return 'license.read_only_banner'.tr();
            }
            await salesCubit.returnSaleItem(
              saleId: saleId,
              saleItemId: saleItemId,
              quantity: quantity,
              paymentMethod: paymentMethod,
              refundAmountOverride: refundAmount,
              refundCashOverride: refundCash,
              refundWalletOverride: refundWallet,
            );
            return salesCubit.state.error;
          },
      onRefreshInvoiceLines: _refreshActiveInvoiceLines,
      animateDialogEntrance: _animateDialogEntrance,
      activeInvoiceId: _activeInvoiceId,
      activeInvoiceDisplayNumber: _activeInvoiceNumber,
      activeInvoiceLines: _activeInvoiceLines,
      canAmendInvoiceForCart: (saleId) =>
          getIt<SalesRepository>().canAmendSaleInvoice(saleId),
      onInvoiceAmendedInCart: (saleId) async {
        if (!context.mounted) return;
        await salesCubit.loadInvoiceForAmendment(saleId);
      },
    );
  }

  Future<void> _showCancelSaleDialog(
    BuildContext context, {
    int? initialSaleId,
  }) async {
    final salesCubit = context.read<SalesCubit>();
    await SalesCancelSaleDialog.show(
      context,
      initialSaleId: initialSaleId,
      parseFlexibleInt: _parseFlexibleInt,
      animateDialogEntrance: _animateDialogEntrance,
      onCancelSale: (saleId) async {
        final allowed = await _ensureSalesWriteAllowed();
        if (!allowed) {
          return false;
        }
        await salesCubit.cancelSale(saleId);
        final failed = salesCubit.state.error != null;
        if (!failed) {
          if (mounted) {
            setState(() {
              _activeSaleItemId = null;
              _activeInvoiceLines = const [];
            });
          }
          await _loadInvoices();
        }
        return !failed;
      },
    );
  }

  Future<void> _generatePdf(BuildContext context, int saleId) async {
    try {
      final bytes = await _pdfService.generateA4Invoice(saleId);
      if (!context.mounted) return;
      _showLatestSnackBar(
        context,
        '${'PDF generated in memory'.tr()} (${bytes.length} ${'bytes'.tr()}).',
      );
    } catch (e) {
      if (!context.mounted) return;
      _showLatestSnackBar(context, '${'PDF generation failed'.tr()}: $e');
    }
  }

  // ignore: unused_element
  Future<void> _selectInvoice(SalesInvoiceSummary row) async {
    final lines = await getIt<SalesRepository>().listInvoiceLines(row.id);
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
      _activeInvoiceId = row.id;
      _activeInvoiceNumber = row.invoiceNumber;
      _activeInvoiceLines = lines;
      _activeSaleItemId = selectedLine?.id;
    });
    _showLatestSnackBar(
      context,
      '${'Invoice'.tr()} ${row.invoiceNumber} ${'selected'.tr()}.',
    );
  }

  Future<void> _refreshActiveInvoiceLines(
    int saleId, {
    int? preferredItemId,
  }) async {
    final lines = await getIt<SalesRepository>().listInvoiceLines(saleId);
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

    setState(() {
      _activeInvoiceLines = lines;
      _activeSaleItemId = selectedLine?.id;
      if (_activeInvoiceId != saleId) {
        _activeInvoiceId = saleId;
      }
    });
  }

  // ignore: unused_element
  Future<void> _loadPendingInvoiceToCart(BuildContext pageContext) async {
    final saleId = _activeInvoiceId;
    if (saleId == null) {
      _showLatestSnackBar(pageContext, 'Select a pending invoice first.'.tr());
      return;
    }

    final cubit = pageContext.read<SalesCubit>();
    await cubit.loadPendingInvoiceToCart(saleId);
  }

  // ignore: unused_element
  Future<void> _showInvoiceDetailsDialog(BuildContext context) async {
    final invoiceId = _activeInvoiceId;
    if (invoiceId == null) return;
    final pageContext = context;
    await SalesInvoiceDetailsDialog.show(
      context,
      invoiceId: invoiceId,
      invoiceRows: _invoiceRows,
      activeInvoiceLines: _activeInvoiceLines,
      activeInvoiceNumber: _activeInvoiceNumber,
      activeSaleItemId: _activeSaleItemId,
      dateFormat: _dateFormat,
      animateDialogEntrance: _animateDialogEntrance,
      loadInvoiceLines: (id) => getIt<SalesRepository>().listInvoiceLines(id),
      onSelectLine: (lineId) {
        if (!mounted) return;
        setState(() => _activeSaleItemId = lineId);
      },
      onPrintInvoice: (invoice) async {
        if (!pageContext.mounted) return;
        await Navigator.of(pageContext).push(
          MaterialPageRoute<void>(
            builder: (_) => InvoicePrintPreviewPage(
              invoice: invoice,
              printManager: _invoicePrintManager,
            ),
          ),
        );
      },
      onApplyReturn: (saleItemId, quantity) {
        _showReturnDialog(
          pageContext,
          initialSaleId: invoiceId,
          initialSaleItemId: saleItemId,
          initialQuantity: quantity,
        );
      },
    );
  }
}
