part of 'sales_page.dart';

class _SalesPageState extends State<SalesPage> {
  static const double _compactLayoutBreakpoint = 950;

  final _productRepo = getIt<ProductRepository>();
  final _accountsRepo = getIt<AccountsRepository>();
  final _pdfService = getIt<SalesInvoicePdfService>();
  final _invoiceScrollController = ScrollController();
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final _invoicePrintManager = InvoicePrintManager(
    a4Printer: const A4InvoicePrinter(),
    thermal58Printer: const UnsupportedInvoicePrinter(
      'Thermal printer adapter is not configured yet.',
    ),
    thermal80Printer: const UnsupportedInvoicePrinter(
      'Thermal printer adapter is not configured yet.',
    ),
  );

  final _nameSearchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _paidController = TextEditingController();
  final _taxPercentController = TextEditingController();
  final _newCustomerController = TextEditingController();
  final _licenseService = getIt<LicenseService>();
  Timer? _searchDebounce;
  bool _readOnlyMode = false;
  String? _readOnlyMessage;

  List<Product> _searchResults = const [];
  List<AccountLookup> _customers = const [];
  List<SalesInvoiceSummary> _invoiceRows = const [];
  Map<SalesInvoiceTypeFilter, int> _invoiceTypeCounts =
      const <SalesInvoiceTypeFilter, int>{};
  bool _loadingInvoices = false;
  int _invoicePage = 0;
  int _invoicePageSize = 50;
  SalesInvoiceTypeFilter _invoiceTypeFilter = SalesInvoiceTypeFilter.all;
  int? _activeInvoiceId;
  String? _activeInvoiceNumber;
  int? _loadedPendingSaleId;
  int? _activeSaleItemId;
  List<SalesInvoiceLine> _activeInvoiceLines = const [];
  List<SaleDraftItem> _lastCheckoutItems = const <SaleDraftItem>[];
  final Map<int, String> _inlineQuantityDrafts = <int, String>{};
  final Map<int, TextEditingController> _inlineQtyControllers =
      <int, TextEditingController>{};
  final Map<int, FocusNode> _inlineQtyFocusNodes = <int, FocusNode>{};
  _SalePriceTier _selectedSalePriceTier = _SalePriceTier.retail;

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
    _searchByName('');
    _productRepo.productsRevisionListenable.addListener(
      _handleProductsRevisionChanged,
    );
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

  void _handleProductsRevisionChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchByName(_nameSearchController.text);
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

  Future<void> _attemptCheckout(SalesCubit cubit, SalesState state) async {
    final allowed = await _ensureSalesWriteAllowed();
    if (!allowed) return;
    if (!mounted) return;

    final draftsOk = _commitInlineQuantityDrafts(context, state.cart);
    if (!draftsOk) return;
    _lastCheckoutItems = List<SaleDraftItem>.from(state.cart);
    cubit.checkout(pendingSaleIdOverride: _loadedPendingSaleId);
  }

  Future<void> _attemptSavePendingInvoice(
    SalesCubit cubit,
    SalesState state,
  ) async {
    final allowed = await _ensureSalesWriteAllowed();
    if (!allowed) return;
    if (!mounted) return;

    final draftsOk = _commitInlineQuantityDrafts(context, state.cart);
    if (!draftsOk) return;
    _lastCheckoutItems = const <SaleDraftItem>[];
    cubit.checkout(isPending: true);
  }

  Future<void> _searchByName(String query) async {
    final items = await _productRepo.listProducts(nameQuery: query);
    if (!mounted) return;
    setState(() => _searchResults = items);
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
    String barcode,
  ) async {
    if (barcode.trim().isEmpty) return;
    final items = await _productRepo.listProducts(barcode: barcode.trim());
    if (items.isNotEmpty && context.mounted) {
      context.read<SalesCubit>().addProduct(
        items.first,
        initialUnitPrice: _resolveSalePriceByTier(items.first),
      );
      _barcodeController.clear();
    }
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
    _productRepo.productsRevisionListenable.removeListener(
      _handleProductsRevisionChanged,
    );
    _searchDebounce?.cancel();
    _nameSearchController.dispose();
    _barcodeController.dispose();
    _paidController.dispose();
    _taxPercentController.dispose();
    _newCustomerController.dispose();
    _invoiceScrollController.dispose();
    for (final controller in _inlineQtyControllers.values) {
      controller.dispose();
    }
    for (final node in _inlineQtyFocusNodes.values) {
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

  void _applyOptimisticStockDeduction(List<SaleDraftItem> soldItems) {
    if (soldItems.isEmpty) return;

    final soldByProduct = <int, double>{};
    for (final item in soldItems) {
      soldByProduct[item.productId] =
          (soldByProduct[item.productId] ?? 0) + item.quantity;
    }

    setState(() {
      _searchResults = _searchResults
          .map((product) {
            final id = product.id;
            if (id == null) return product;
            final soldQty = soldByProduct[id];
            if (soldQty == null) return product;
            final nextStock = (product.currentStock - soldQty)
                .clamp(0, double.infinity)
                .toDouble();
            return product.copyWith(currentStock: nextStock);
          })
          .toList(growable: false);
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
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesCubit, SalesState>(
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
          if (event == 'sale_saved') {
            _applyOptimisticStockDeduction(_lastCheckoutItems);
          }
          if (event == 'pending_completed') {
            _loadedPendingSaleId = null;
          }
          _lastCheckoutItems = const <SaleDraftItem>[];
          if (mounted) {
            setState(() {
              _invoicePage = 0;
              _activeInvoiceId = state.successInvoiceId;
              _activeInvoiceNumber = null;
              _activeSaleItemId = null;
              _activeInvoiceLines = const [];
            });
          }
          _loadInvoices();
          _searchByName(_nameSearchController.text);
          final successMessage = switch (event) {
            'pending_saved' =>
              '${'Pending invoice saved'.tr()}: #${state.successInvoiceId}',
            'pending_completed' =>
              '${'Pending invoice completed'.tr()}: #${state.successInvoiceId}',
            _ => '${'Sale saved'.tr()}: #${state.successInvoiceId}',
          };
          _showLatestSnackBar(context, successMessage);
          if (event != 'pending_completed') {
            _barcodeController.clear();
            _paidController.clear();
            _taxPercentController.clear();
            _newCustomerController.clear();
          }
          shouldClearTransient = true;
        }
        if (state.successEvent == 'pending_loaded') {
          _loadedPendingSaleId = state.pendingSaleId;
          _taxPercentController.text = state.taxPercentage == 0
              ? ''
              : state.taxPercentage.toStringAsFixed(2);
          _paidController.text = '0';
          _newCustomerController.text = state.newCustomerName;
          if (mounted) {
            setState(() {
              _activeInvoiceId = null;
              _activeInvoiceNumber = null;
              _activeSaleItemId = null;
              _activeInvoiceLines = const [];
            });
          }
          _showLatestSnackBar(context, 'Pending invoice loaded to cart.'.tr());
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
              SalesHeaderSection(
                isShortViewport: isShortViewport,
                isVeryDenseViewport: isVeryDenseViewport,
                readOnlyMode: _readOnlyMode,
                readOnlyMessage: _readOnlyMessage,
              ),
              SizedBox(height: sectionGap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < _compactLayoutBreakpoint;
                    final productsPaneFlex = 1;
                    final cartPaneFlex = 1;
                    return Flex(
                      direction: compact ? Axis.vertical : Axis.horizontal,
                      children: [
                        Expanded(
                          flex: productsPaneFlex,
                          child: SalesProductsPane(
                            compact: compact,
                            veryDense: isVeryDenseViewport,
                            nameSearchController: _nameSearchController,
                            barcodeController: _barcodeController,
                            searchResults: _searchResults,
                            onNameChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 300),
                                () => _searchByName(value),
                              );
                            },
                            onBarcodeChanged: (value) =>
                                _searchBarcodeAndAdd(context, value),
                            onAddProduct: (item) =>
                                context.read<SalesCubit>().addProduct(
                                  item,
                                  initialUnitPrice: _resolveSalePriceByTier(
                                    item,
                                  ),
                                ),
                            bottomChild: _buildInvoicesExplorer(context),
                          ),
                        ),
                        SizedBox(
                          width: compact ? 0 : sectionGap,
                          height: compact ? sectionGap : 0,
                        ),
                        Expanded(
                          flex: cartPaneFlex,
                          child: SalesCartPane(
                            veryDense: isVeryDenseViewport,
                            total: state.total,
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
                            cartContent: _buildCartTableContent(
                              context,
                              state,
                              cubit,
                            ),
                            customers: _customers,
                            customerId: state.customerId,
                            newCustomerController: _newCustomerController,
                            taxPercentController: _taxPercentController,
                            paidController: _paidController,
                            paidAmount: state.paidAmount,
                            taxAmount: state.taxAmount,
                            paymentMethod: state.paymentMethod,
                            onCustomerChanged: (value) =>
                                context.read<SalesCubit>().setCustomerId(value),
                            onNewCustomerNameChanged: context
                                .read<SalesCubit>()
                                .setNewCustomerName,
                            onTaxChanged: (v) => context
                                .read<SalesCubit>()
                                .setTaxPercentage(_parseFlexibleNumber(v) ?? 0),
                            onPaidChanged: (v) => context
                                .read<SalesCubit>()
                                .setPaidAmount(_parseFlexibleNumber(v) ?? 0),
                            onPaymentMethodChanged: (value) => context
                                .read<SalesCubit>()
                                .setPaymentMethod(value),
                            onCompleteSale: () =>
                                _attemptCheckout(cubit, state),
                            onSavePendingSale: () =>
                                _attemptSavePendingInvoice(cubit, state),
                            onReturnFromInvoice: () =>
                                _showReturnDialog(context),
                            onCancelInvoice: () =>
                                _showCancelSaleDialog(context),
                            onGeneratePdf: () {
                              final invoiceId = state.successInvoiceId;
                              if (invoiceId == null) return;
                              _generatePdf(context, invoiceId);
                            },
                            readOnlyMode: _readOnlyMode,
                            readOnlyMessage: _readOnlyMessage,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (MediaQuery.sizeOf(context).width <
                  _compactLayoutBreakpoint) ...[
                SizedBox(height: sectionGap),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: _buildInvoicesExplorer(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartTableContent(
    BuildContext context,
    SalesState state,
    SalesCubit cubit,
  ) {
    return SalesCartTable(
      cart: state.cart,
      pieceUnitTypeName: UnitType.piece.name,
      inlineQuantityDrafts: _inlineQuantityDrafts,
      qtyControllerFor: _qtyControllerFor,
      qtyFocusNodeFor: _qtyFocusNodeFor,
      formatQuantity: _formatQuantity,
      parseFlexibleNumber: _parseFlexibleNumber,
      onDraftChanged: (item, value) {
        setState(() {
          _inlineQuantityDrafts[item.productId] = value;
        });
      },
      onApplyInlineQuantity: (item, value) {
        _applyInlineQuantityChange(context, item, value);
      },
      onDraftCleared: (productId) {
        setState(() {
          _inlineQuantityDrafts.remove(productId);
        });
      },
      onRemoveItem: cubit.removeItem,
      onUpdateItemQuantity: (productId, quantity) {
        cubit.updateItem(productId, quantity: quantity);
      },
      onEditItem: (item) => _showEditItemDialog(context, item),
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    SaleDraftItem item,
  ) async {
    await SalesEditItemDialog.show(
      context,
      item: item,
      parseFlexibleNumber: _parseFlexibleNumber,
      onApply: ({quantity, unitPrice, discount}) {
        context.read<SalesCubit>().updateItem(
          item.productId,
          quantity: quantity,
          unitPrice: unitPrice,
          discount: discount,
        );
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
      loadInvoiceLines: (saleId) =>
          getIt<SalesRepository>().listInvoiceLines(saleId),
      onReturnSaleItem:
          ({
            required saleId,
            required saleItemId,
            required quantity,
            required paymentMethod,
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
            );
            return salesCubit.state.error;
          },
      onRefreshInvoiceLines: _refreshActiveInvoiceLines,
      animateDialogEntrance: _animateDialogEntrance,
      activeInvoiceId: _activeInvoiceId,
      activeInvoiceLines: _activeInvoiceLines,
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
          await _searchByName(_nameSearchController.text);
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

  Widget _buildInvoicesExplorer(BuildContext blocContext) {
    return SalesInvoicesExplorer(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      accountId: widget.accountId,
      categoryId: widget.categoryId,
      loadingInvoices: _loadingInvoices,
      invoiceRows: _invoiceRows,
      invoiceScrollController: _invoiceScrollController,
      activeInvoiceId: _activeInvoiceId,
      activeInvoiceNumber: _activeInvoiceNumber,
      canCompletePendingSelected:
          _activeInvoiceId != null &&
          _invoiceRows.any(
            (row) => row.id == _activeInvoiceId && row.status == 'pending',
          ),
      activeSaleItemId: _activeSaleItemId,
      selectedTypeFilter: _invoiceTypeFilter,
      invoiceTypeCounts: _invoiceTypeCounts,
      invoicePage: _invoicePage,
      invoicePageSize: _invoicePageSize,
      onSelectInvoice: _selectInvoice,
      onReturnSelected: () => _showReturnDialog(
        blocContext,
        initialSaleId: _activeInvoiceId,
        initialSaleItemId: _activeSaleItemId,
      ),
      onCancelSelected: () =>
          _showCancelSaleDialog(blocContext, initialSaleId: _activeInvoiceId),
      onShowDetails: () => _showInvoiceDetailsDialog(blocContext),
      onGeneratePdfSelected: () {
        final id = _activeInvoiceId;
        if (id == null) return;
        _generatePdf(blocContext, id);
      },
      onCompletePendingSelected: () => _loadPendingInvoiceToCart(blocContext),
      onTypeFilterChanged: (filter) {
        setState(() {
          _invoiceTypeFilter = filter;
          _invoicePage = 0;
          _activeInvoiceId = null;
          _activeInvoiceNumber = null;
          _activeSaleItemId = null;
          _activeInvoiceLines = const [];
        });
        _loadInvoices();
      },
      onPreviousPage: () {
        setState(() => _invoicePage -= 1);
        _loadInvoices();
      },
      onNextPage: () {
        setState(() => _invoicePage += 1);
        _loadInvoices();
      },
    );
  }

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

  Future<void> _loadPendingInvoiceToCart(BuildContext pageContext) async {
    final saleId = _activeInvoiceId;
    if (saleId == null) {
      _showLatestSnackBar(pageContext, 'Select a pending invoice first.'.tr());
      return;
    }

    final cubit = pageContext.read<SalesCubit>();
    await cubit.loadPendingInvoiceToCart(saleId);
  }

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
