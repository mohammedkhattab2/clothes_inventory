part of 'purchases_page.dart';

enum _InvoiceImageInputSource { upload, camera }

class _PurchasesPageState extends State<PurchasesPage> {
  final _productRepo = getIt<ProductRepository>();
  final _accountsRepo = getIt<AccountsRepository>();
  final _imagePicker = ImagePicker();
  final _licenseService = getIt<LicenseService>();
  bool _readOnlyMode = false;
  String? _readOnlyMessage;

  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  Timer? _barcodeDebounce;
  int _barcodeLookupGeneration = 0;
  final _paidController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _headerDiscountValueController = TextEditingController();
  final _paidAmountFocusNode = FocusNode();
  final _invoiceScrollController = ScrollController();
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

  final _barcodeLabelPrinter = const ProductBarcodeLabelPrinter(
    paperWidthMm: 58,
    printerPrefs: ThermalPrinterPreferences(),
  );

  List<AccountLookup> _suppliers = const [];
  List<PurchaseInvoiceSummary> _invoiceRows = const [];
  // ignore: unused_field
  bool _loadingInvoices = false;
  int _invoicePage = 0;
  int _invoicePageSize = 50;
  int? _activeInvoiceId;
  String? _activeInvoiceNumber;
  int? _activePurchaseItemId;
  List<PurchaseInvoiceLine> _activeInvoiceLines = const [];
  final Map<int, String> _inlineQuantityDrafts = <int, String>{};
  final Map<int, TextEditingController> _inlineQtyControllers =
      <int, TextEditingController>{};
  final Map<int, FocusNode> _inlineQtyFocusNodes = <int, FocusNode>{};
  _PurchasePaymentStatus _paymentStatus = _PurchasePaymentStatus.full;

  void _showLatestSnackBar(BuildContext targetContext, String message) {
    if (!mounted || !targetContext.mounted) return;
    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _presentPurchaseError(String raw) {
    if (raw.contains('FOREIGN KEY constraint failed') ||
        raw.contains('SqliteException') ||
        raw.contains('DatabaseException')) {
      return 'Cannot delete product because it is used in sales/purchases history.'
          .tr();
    }

    switch (raw) {
      case 'Cannot delete product because it is used in sales/purchases history.':
      case 'Supplier is required.':
      case 'Add at least one product.':
      case 'Purchase must have at least one item.':
      case 'Piece products require integer quantity.':
      case 'Purchase not found.':
      case 'Cancelled purchase cannot be returned.':
      case 'Purchase item not found.':
      case 'Cannot cancel purchase with returns. Reverse all returns first.':
      case 'Cannot cancel purchase because current stock is insufficient.':
      case 'Insufficient stock for one or more products.':
      case 'purchase.amend_blocked_returns':
      case 'purchase.amend_blocked_status':
      case 'purchase.amend_blocked_ledger':
        return raw.tr();
      default:
        return raw;
    }
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
    _loadSuppliers();
    _loadInvoices();
    _refreshWritePermissionStatus();
  }

  Future<void> _loadSuppliers() async {
    final data = await _accountsRepo.listByType('supplier');
    if (!mounted) return;
    setState(() => _suppliers = data);
  }

  String? _phoneForSupplierId(int? supplierId) {
    if (supplierId == null) return null;
    for (final s in _suppliers) {
      if (s.id == supplierId) {
        return s.phone;
      }
    }
    return null;
  }

  void _applySupplierPhone(int? supplierId) {
    _supplierPhoneController.text =
        _phoneForSupplierId(supplierId)?.trim() ?? '';
  }

  void _onSupplierChanged(BuildContext blocContext, int? supplierId) {
    blocContext.read<PurchasesCubit>().setSupplier(supplierId);
    _applySupplierPhone(supplierId);
  }

  Future<bool> _ensurePurchasesWriteAllowed() async {
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

  Future<void> _attemptCheckout(
    PurchasesCubit cubit,
    PurchasesState state,
  ) async {
    final allowed = await _ensurePurchasesWriteAllowed();
    if (!allowed) return;
    if (!mounted) return;
    _commitInlineQuantityDrafts(cubit, state.cart);
    cubit.checkout();
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
        _showLatestSnackBar(
          context,
          'No product matches this barcode.'.tr(),
        );
        refocusBarcodeForNextScan(
          focus: _barcodeFocusNode,
          controller: _barcodeController,
        );
      }
      return;
    }
    if (!context.mounted) return;
    context.read<PurchasesCubit>().addProduct(items.first);
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

  Future<void> _loadInvoices() async {
    setState(() => _loadingInvoices = true);
    try {
      final rows = await getIt<PurchasesRepository>().listInvoices(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
        limit: _invoicePageSize,
        offset: _invoicePage * _invoicePageSize,
      );
      if (!mounted) return;
      setState(() {
        _invoiceRows = rows;
        _loadingInvoices = false;
      });
      _scrollToPreselected();
    } catch (e, st) {
      dev.log(
        'Failed loading purchase invoices for navigation context',
        name: 'PurchasesPage',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _loadingInvoices = false);
    }
  }

  Future<void> _printPurchaseEntryBarcodeLabels({
    required String productName,
    required String barcode,
    required int quantity,
  }) async {
    try {
      await _barcodeLabelPrinter.printLabel(
        productName: productName,
        barcodeValue: barcode,
        copies: quantity,
      );
      if (!mounted) return;
      _showLatestSnackBar(context, 'Barcode label sent to printer'.tr());
    } catch (e) {
      if (!mounted) return;
      _showLatestSnackBar(
        context,
        '${'Failed to print barcode'.tr()}: $e',
      );
    }
  }

  Future<void> _showPurchasesEntryProductDialog(BuildContext context) async {
    final allowed = await _ensurePurchasesWriteAllowed();
    if (!allowed || !context.mounted) return;

    await PurchasesProductDialog.show(
      context,
      parseFlexibleNumber: parseFlexibleNumber,
      onGenerateBarcode: () => _productRepo.generateNextShortBarcode(),
      barcodeLabelPrinter: _barcodeLabelPrinter,
      onPrintBarcode: _printPurchaseEntryBarcodeLabels,
      onCreateProduct: _productRepo.createProduct,
      onUpdateProduct: _productRepo.updateProduct,
      onRefreshSearch: () async {},
      onCreatedAttachToCart: (created, enteredQuantity) {
        if (!context.mounted) return;
        context.read<PurchasesCubit>().addProductWithQuantity(
          created,
          enteredQuantity,
        );
      },
      onUpdatedSyncCart: (productId, unitPrice) {
        if (!context.mounted) return;
        context.read<PurchasesCubit>().syncCartLinePurchasePrice(
          productId,
          unitPrice,
        );
      },
    );
  }

  Future<void> _scanInvoice(BuildContext context) async {
    final source = await _showImageInputSourceDialog(context);
    if (!mounted || !context.mounted || source == null) return;

    final imagePath = await _pickInvoiceImagePath(source);
    if (!mounted || !context.mounted || imagePath == null) return;

    final savedInvoiceId = await Navigator.of(context, rootNavigator: true)
        .push<int>(
          MaterialPageRoute<int>(
            builder: (_) => PurchaseOcrReviewPage(imagePath: imagePath),
          ),
        );

    if (!mounted || !context.mounted) return;

    if (savedInvoiceId != null) {
      await _loadInvoices();
      if (!mounted || !context.mounted) return;
      _showLatestSnackBar(
        context,
        '${'Purchase saved'.tr()}: #$savedInvoiceId',
      );
    }
  }

  Future<_InvoiceImageInputSource?> _showImageInputSourceDialog(
    BuildContext context,
  ) {
    return showDialog<_InvoiceImageInputSource>(
      context: context,
      builder: (dialogContext) {
        final width = (MediaQuery.sizeOf(dialogContext).width * 0.9).clamp(
          320.0,
          480.0,
        );

        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan Invoice'.tr(),
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose image source'.tr(),
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(_InvoiceImageInputSource.upload),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text('Upload Image'.tr()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(_InvoiceImageInputSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text('Use Camera'.tr()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text('Cancel'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickInvoiceImagePath(_InvoiceImageInputSource source) async {
    try {
      if (source == _InvoiceImageInputSource.upload) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png'],
          allowMultiple: false,
        );

        final filePath = result?.files.single.path;
        if (filePath == null || filePath.trim().isEmpty) {
          return null;
        }
        return filePath;
      }

      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      return file?.path;
    } catch (_) {
      if (!mounted) return null;
      final message = source == _InvoiceImageInputSource.camera
          ? 'Camera is unavailable on this device. Use Upload Image instead.'
          : 'Unable to open file picker. Please try again.';
      _showLatestSnackBar(context, message.tr());
      return null;
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

  Future<void> _createSupplierDialog(BuildContext blocContext) async {
    final allowed = await _ensurePurchasesWriteAllowed();
    if (!allowed) return;
    if (!mounted || !blocContext.mounted) return;

    await PurchasesSupplierDialog.show(
      blocContext,
      suppliers: _suppliers,
      onCreateSupplier: ({required name, phone, address}) {
        return _accountsRepo.createAccount(
          name: name,
          accountType: 'supplier',
          phone: phone,
          address: address,
        );
      },
      onReloadSuppliers: _loadSuppliers,
      onSupplierSelected: (supplierId) {
        if (!mounted || !blocContext.mounted) return;
        _onSupplierChanged(blocContext, supplierId);
      },
    );

    await _loadSuppliers();
    if (!mounted || !blocContext.mounted) return;
    final supplierId = blocContext.read<PurchasesCubit>().state.supplierId;
    _applySupplierPhone(supplierId);
  }

  @override
  void dispose() {
    _barcodeDebounce?.cancel();
    _searchController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _nameFocusNode.dispose();
    _paidController.dispose();
    _supplierPhoneController.dispose();
    _headerDiscountValueController.dispose();
    _paidAmountFocusNode.dispose();
    _invoiceScrollController.dispose();
    for (final controller in _inlineQtyControllers.values) {
      controller.dispose();
    }
    for (final node in _inlineQtyFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshActiveInvoiceLines(
    int purchaseId, {
    int? preferredItemId,
  }) async {
    final lines = await getIt<PurchasesRepository>().listInvoiceLines(
      purchaseId,
    );
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
      _activeInvoiceLines = lines;
      _activePurchaseItemId = selectedLine?.id;
    });
  }

  void _applyInlineQuantityChange(
    PurchasesCubit cubit,
    PurchaseDraftItem item,
    String raw,
  ) {
    final parsed = parseFlexibleNumber(raw);
    if (parsed == null) return;

    if (parsed <= 0) {
      cubit.removeItem(item.productId);
      return;
    }

    cubit.updateItem(item.productId, quantity: parsed);
  }

  void _commitInlineQuantityDrafts(
    PurchasesCubit cubit,
    List<PurchaseDraftItem> cart,
  ) {
    if (_inlineQuantityDrafts.isEmpty) return;

    for (final item in cart) {
      final draft = _inlineQuantityDrafts[item.productId];
      if (draft == null || draft.trim().isEmpty) continue;
      _applyInlineQuantityChange(cubit, item, draft);
    }
    _inlineQuantityDrafts.clear();
  }

  void _syncInlineQuantityEditors(List<PurchaseDraftItem> cart) {
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

  TextEditingController _qtyControllerFor(PurchaseDraftItem item) {
    return _inlineQtyControllers.putIfAbsent(
      item.productId,
      () => TextEditingController(text: formatDraftQuantity(item)),
    );
  }

  FocusNode _qtyFocusNodeFor(
    PurchaseDraftItem item,
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PurchasesCubit>(),
      child: BlocConsumer<PurchasesCubit, PurchasesState>(
        listener: (context, state) {
          var shouldClearTransient = false;
          var shouldClearError = false;

          if (state.successEvent == 'invoice_amendment_loaded') {
            _applySupplierPhone(state.supplierId);
            _headerDiscountValueController.text =
                state.headerDiscountValue == 0
                    ? ''
                    : state.headerDiscountValue.toStringAsFixed(2);
            final total = state.total;
            final paid = state.paidAmount;
            if (mounted) {
              setState(() {
                if (total <= 0.000001) {
                  _paymentStatus = _PurchasePaymentStatus.deferred;
                } else if ((paid - total).abs() < 0.000001) {
                  _paymentStatus = _PurchasePaymentStatus.full;
                } else if (paid < 0.000001) {
                  _paymentStatus = _PurchasePaymentStatus.deferred;
                } else {
                  _paymentStatus = _PurchasePaymentStatus.partial;
                }
              });
            }
            if (mounted && state.editingPurchaseId != null) {
              unawaited(
                _refreshActiveInvoiceLines(state.editingPurchaseId!),
              );
            }
            _showLatestSnackBar(
              context,
              'purchase.invoice_amendment_loaded_hint'.tr(),
            );
            shouldClearTransient = true;
          }

          if (state.successInvoiceId != null) {
            final msg = switch (state.successEvent) {
              'purchase_amended' => 'purchase.amended_success'.tr(
                  namedArgs: {'id': '${state.successInvoiceId}'},
                ),
              _ =>
                '${'Purchase saved'.tr()}: #${state.successInvoiceId}',
            };
            _showLatestSnackBar(context, msg);
            _paymentStatus = _PurchasePaymentStatus.full;
            _searchController.clear();
            _barcodeController.clear();
            refocusBarcodeForNextScan(
              focus: _barcodeFocusNode,
              controller: _barcodeController,
            );
            _paidController.clear();
            _headerDiscountValueController.clear();
            _loadInvoices();
            shouldClearTransient = true;
          }

          if (state.error != null) {
            _showLatestSnackBar(context, _presentPurchaseError(state.error!));
            shouldClearTransient = true;
            shouldClearError = true;
          }

          if (shouldClearTransient) {
            context.read<PurchasesCubit>().clearTransientFeedback(
              clearError: shouldClearError,
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<PurchasesCubit>();
          _syncInlineQuantityEditors(state.cart);
          final viewport = MediaQuery.sizeOf(context);
          final isShortViewport =
              viewport.height < 900 || viewport.width < 1280;
          final isVeryDenseViewport =
              viewport.height < 720 || viewport.width < 1080;
          final sectionGap = isVeryDenseViewport
              ? 6.0
              : (isShortViewport ? 8.0 : 10.0);
          final desiredPaid = _paymentStatus == _PurchasePaymentStatus.full
              ? state.total
              : (_paymentStatus == _PurchasePaymentStatus.deferred
                    ? 0.0
                    : state.paidAmount);
          if ((_paymentStatus != _PurchasePaymentStatus.partial) &&
              state.paidAmount != desiredPaid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              cubit.setPaidAmount(desiredPaid);
            });
          }
          final displayPaid = _paymentStatus == _PurchasePaymentStatus.partial
              ? state.paidAmount
              : desiredPaid;
          final displayPaidText =
              (_paymentStatus == _PurchasePaymentStatus.partial &&
                  displayPaid == 0)
              ? ''
              : displayPaid.toStringAsFixed(2);
          final shouldSyncPaidText =
              _paymentStatus != _PurchasePaymentStatus.partial ||
              !_paidAmountFocusNode.hasFocus;
          if (shouldSyncPaidText && _paidController.text != displayPaidText) {
            _paidController.value = _paidController.value.copyWith(
              text: displayPaidText,
              selection: TextSelection.collapsed(
                offset: displayPaidText.length,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              isVeryDenseViewport ? 12 : (isShortViewport ? 16 : 24),
              isVeryDenseViewport ? 10 : (isShortViewport ? 12 : 24),
              isVeryDenseViewport ? 12 : (isShortViewport ? 16 : 24),
              isVeryDenseViewport ? 10 : (isShortViewport ? 12 : 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                ],
                PurchasesCheckoutToolbar(
                  veryDense: isVeryDenseViewport,
                  colorScheme: Theme.of(context).colorScheme,
                  nameFocusNode: _nameFocusNode,
                  nameSearchController: _searchController,
                  barcodeController: _barcodeController,
                  barcodeFocusNode: _barcodeFocusNode,
                  searchProducts: (q) => _productRepo.listProducts(
                    nameQuery: q,
                    limit: 72,
                  ),
                  onProductSelected: (item) {
                    _searchController.clear();
                    cubit.addProduct(item);
                  },
                  onBarcodeChanged: (value) =>
                      _onBarcodeFieldChanged(context, value),
                  onBarcodeSubmitted: (value) =>
                      _onBarcodeFieldSubmitted(context, value),
                  onScanInvoice: () => _scanInvoice(context),
                  scanInvoiceEnabled: !_readOnlyMode,
                  loading: state.loading,
                  onAddProduct: () {
                    unawaited(_showPurchasesEntryProductDialog(context));
                  },
                  addProductEnabled:
                      roleCanManageProducts(
                        getIt<SessionService>().currentUser?.role,
                      ) &&
                      !_readOnlyMode,
                ),
                SizedBox(height: sectionGap),
                Expanded(
                  child: PurchasesCartPane(
                    veryDense: isVeryDenseViewport,
                    total: state.total,
                    loading: state.loading,
                    paymentStatusIndex: _paymentStatus.index,
                    paymentStatusItems: [
                      DropdownMenuItem(
                        value: _PurchasePaymentStatus.full.index,
                        child: Text('Full Payment'.tr()),
                      ),
                      DropdownMenuItem(
                        value: _PurchasePaymentStatus.partial.index,
                        child: Text('Partial Payment'.tr()),
                      ),
                      DropdownMenuItem(
                        value: _PurchasePaymentStatus.deferred.index,
                        child: Text('Deferred Payment'.tr()),
                      ),
                    ],
                    cartContent: _buildCartTableContent(
                      context,
                      state,
                      cubit,
                    ),
                    suppliers: _suppliers,
                    supplierId: state.supplierId,
                    supplierPhoneController: _supplierPhoneController,
                    headerDiscountKind: state.headerDiscountKind,
                    headerDiscountValueController:
                        _headerDiscountValueController,
                    paidController: _paidController,
                    paidAmountFocusNode: _paidAmountFocusNode,
                    headerDiscountAmount: state.headerDiscountAmount,
                    outstandingAmount: (state.total - state.paidAmount)
                        .clamp(0, state.total)
                        .toDouble(),
                    paymentMethod: state.paymentMethod,
                    paidFieldEnabled:
                        _paymentStatus == _PurchasePaymentStatus.partial,
                    paymentMethodEditable:
                        _paymentStatus != _PurchasePaymentStatus.deferred,
                    onAddSupplier: () => _createSupplierDialog(context),
                    onSupplierChanged: (supplierId) =>
                        _onSupplierChanged(context, supplierId),
                    onPaymentStatusChanged: (value) {
                      if (value == null) return;
                      final selectedStatus =
                          _PurchasePaymentStatus.values[value];
                      setState(() => _paymentStatus = selectedStatus);
                      if (selectedStatus == _PurchasePaymentStatus.full) {
                        cubit.setPaidAmount(state.total);
                      } else if (selectedStatus ==
                          _PurchasePaymentStatus.deferred) {
                        cubit.setPaidAmount(0);
                      }
                    },
                    onHeaderDiscountKindChanged: (kind) => context
                        .read<PurchasesCubit>()
                        .setHeaderDiscountKind(kind),
                    onHeaderDiscountValueChanged: (v) => context
                        .read<PurchasesCubit>()
                        .setHeaderDiscountValue(
                          parseFlexibleNumber(v) ?? 0,
                        ),
                    onPaidChanged:
                        _paymentStatus == _PurchasePaymentStatus.partial
                        ? (value) {
                            final parsed = parseFlexibleNumber(value);
                            if (parsed != null) {
                              cubit.setPaidAmount(parsed);
                            } else if (value.trim().isEmpty) {
                              cubit.setPaidAmount(0);
                            }
                          }
                        : null,
                    onPaymentMethodChanged: cubit.setPaymentMethod,
                    onCompletePurchase: () =>
                        _attemptCheckout(cubit, state),
                    onReturnFromInvoice: () => _showReturnDialog(context),
                    onCancelInvoice: () => _showCancelDialog(context),
                    readOnlyMode: _readOnlyMode,
                    readOnlyMessage: _readOnlyMessage,
                    invoiceAmendmentMode: state.editingPurchaseId != null,
                    onCancelInvoiceAmendment: () =>
                        context.read<PurchasesCubit>().clearInvoiceAmendment(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    PurchaseDraftItem item,
  ) async {
    await PurchasesEditItemDialog.show(
      context,
      item: item,
      parseFlexibleNumber: parseFlexibleNumber,
      onApply: ({quantity, unitPrice, discount}) {
        context.read<PurchasesCubit>().updateItem(
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
    int? initialPurchaseId,
    int? initialPurchaseItemId,
    double? initialQuantity,
  }) async {
    final purchasesCubit = context.read<PurchasesCubit>();
    await PurchasesReturnDialog.show(
      context,
      initialPurchaseId: initialPurchaseId,
      initialPurchaseItemId: initialPurchaseItemId,
      initialQuantity: initialQuantity,
      activeInvoiceId: _activeInvoiceId,
      activeInvoiceDisplayNumber: _activeInvoiceNumber,
      activeInvoiceLines: _activeInvoiceLines,
      parseFlexibleInt: parseFlexibleInt,
      parseFlexibleNumber: parseFlexibleNumber,
      formatInvoiceQuantity: formatInvoiceQuantityValue,
      animateDialogEntrance: _animateDialogEntrance,
      lookupPurchaseInvoiceSuggestion: (id) =>
          getIt<PurchasesRepository>()
              .lookupPurchaseInvoiceSuggestionForReturn(id),
      searchPurchaseInvoicesForReturn: (prefix) =>
          getIt<PurchasesRepository>().suggestPurchaseInvoicesForReturn(prefix),
      loadInvoiceLines: (purchaseId) =>
          getIt<PurchasesRepository>().listInvoiceLines(purchaseId),
      onReturnPurchaseItem:
          ({
            required purchaseId,
            required purchaseItemId,
            required quantity,
          }) async {
            final allowed = await _ensurePurchasesWriteAllowed();
            if (!allowed) {
              return 'license.read_only_banner'.tr();
            }
            await purchasesCubit.returnPurchaseItem(
              purchaseId: purchaseId,
              purchaseItemId: purchaseItemId,
              quantity: quantity,
            );
            return purchasesCubit.state.error;
          },
      onRefreshActiveInvoiceLines: _refreshActiveInvoiceLines,
      canAmendPurchaseForCart: (id) =>
          getIt<PurchasesRepository>().canAmendPurchaseInvoice(id),
      onPurchaseInvoiceAmendedInCart: (id) async {
        final allowed = await _ensurePurchasesWriteAllowed();
        if (!allowed) return;
        await purchasesCubit.loadPurchaseForAmendment(id);
      },
      onAddLineToCart: (productId) async {
        final allowed = await _ensurePurchasesWriteAllowed();
        if (!allowed) {
          return;
        }
        final products = await _productRepo.listProductsByIds([productId]);
        if (products.isEmpty || !context.mounted) {
          return;
        }
        purchasesCubit.addProduct(products.first);
      },
    );
  }

  Future<void> _showCancelDialog(
    BuildContext context, {
    int? initialPurchaseId,
  }) async {
    final purchasesCubit = context.read<PurchasesCubit>();
    await PurchasesCancelDialog.show(
      context,
      initialPurchaseId: initialPurchaseId,
      parseFlexibleInt: parseFlexibleInt,
      animateDialogEntrance: _animateDialogEntrance,
      onConfirmCancel: (purchaseId) async {
        final allowed = await _ensurePurchasesWriteAllowed();
        if (!allowed) {
          return false;
        }
        await purchasesCubit.cancelPurchase(purchaseId);
        final failed = purchasesCubit.state.error != null;
        if (!failed) {
          if (mounted) {
            setState(() {
              _activePurchaseItemId = null;
              _activeInvoiceLines = const [];
            });
          }
          await _loadInvoices();
        }
        return !failed;
      },
    );
  }

  Widget _buildCartTableContent(
    BuildContext context,
    PurchasesState state,
    PurchasesCubit cubit,
  ) {
    return PurchasesCartTableContent(
      state: state,
      cubit: cubit,
      qtyControllerFor: _qtyControllerFor,
      qtyFocusNodeFor: _qtyFocusNodeFor,
      formatQuantity: formatDraftQuantity,
      parseFlexibleNumber: parseFlexibleNumber,
      inlineQuantityDrafts: _inlineQuantityDrafts,
      applyInlineQuantityChange: (_, item, raw) {
        _applyInlineQuantityChange(cubit, item, raw);
      },
      onShowEditItemDialog: _showEditItemDialog,
    );
  }

  // ignore: unused_element
  Future<void> _selectInvoice(PurchaseInvoiceSummary row) async {
    final lines = await getIt<PurchasesRepository>().listInvoiceLines(row.id);
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
      _activeInvoiceId = row.id;
      _activeInvoiceNumber = row.invoiceNumber;
      _activeInvoiceLines = lines;
      _activePurchaseItemId = selectedLine?.id;
    });
    _showLatestSnackBar(
      context,
      '${buildPurchaseInvoiceLabel(id: row.id, rawInvoiceNumber: row.invoiceNumber)} ${'selected'.tr()}.',
    );
  }

  // ignore: unused_element
  Future<void> _showInvoiceDetailsDialog(BuildContext context) async {
    final pageContext = context;
    final invoiceId = _activeInvoiceId;
    if (invoiceId == null) return;

    await PurchasesInvoiceDetailsDialog.show(
      context,
      invoiceId: invoiceId,
      invoiceRows: _invoiceRows,
      activeInvoiceNumber: _activeInvoiceNumber,
      activePurchaseItemId: _activePurchaseItemId,
      dateFormat: _dateFormat,
      purchaseInvoiceLabel: buildPurchaseInvoiceLabel,
      formatInvoiceQuantity: formatInvoiceQuantityValue,
      animateDialogEntrance: _animateDialogEntrance,
      loadInvoiceLines: (purchaseId) async {
        await _refreshActiveInvoiceLines(
          purchaseId,
          preferredItemId: _activePurchaseItemId,
        );
        return _activeInvoiceLines;
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
      onApplyReturn: (purchaseItemId, quantity) {
        _showReturnDialog(
          pageContext,
          initialPurchaseId: invoiceId,
          initialPurchaseItemId: purchaseItemId,
          initialQuantity: quantity,
        );
      },
    );
  }
}
