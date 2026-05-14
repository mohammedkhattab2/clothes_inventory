part of 'purchases_page.dart';

enum _InvoiceImageInputSource { upload, camera }

class _PurchasesPageState extends State<PurchasesPage> {
  static const double _compactLayoutBreakpoint = 950;

  final _productRepo = getIt<ProductRepository>();
  final _accountsRepo = getIt<AccountsRepository>();
  final _purchaseItemsImportService = PurchaseItemsImportService();
  final _imagePicker = ImagePicker();
  final _licenseService = getIt<LicenseService>();
  bool _readOnlyMode = false;
  String? _readOnlyMessage;
  bool _importingItems = false;
  bool _savingImportTemplate = false;

  final _searchController = TextEditingController();
  final _paidController = TextEditingController();
  final _taxPercentController = TextEditingController();
  final _paidAmountFocusNode = FocusNode();
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

  List<Product> _searchResults = const [];
  List<AccountLookup> _suppliers = const [];
  List<PurchaseInvoiceSummary> _invoiceRows = const [];
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
    _searchProducts('');
    _productRepo.productsRevisionListenable.addListener(
      _handleProductsRevisionChanged,
    );
    _loadInvoices();
    _refreshWritePermissionStatus();
  }

  void _handleProductsRevisionChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchProducts(_searchController.text);
    });
  }

  Future<void> _loadSuppliers() async {
    final data = await _accountsRepo.listByType('supplier');
    if (!mounted) return;
    setState(() => _suppliers = data);
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

  Future<void> _searchProducts(String query) async {
    final data = await _productRepo.listProducts(nameQuery: query);
    if (!mounted) return;
    setState(() => _searchResults = data);
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
      await _searchProducts(_searchController.text);
      if (!mounted || !context.mounted) return;
      _showLatestSnackBar(
        context,
        '${'Purchase saved'.tr()}: #$savedInvoiceId',
      );
    }
  }

  Future<void> _downloadImportTemplate(BuildContext blocContext) async {
    if (_savingImportTemplate) return;
    if (!mounted || !blocContext.mounted) return;

    setState(() => _savingImportTemplate = true);
    try {
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download Template'.tr(),
        fileName: 'purchase_import_template.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );

      if (!mounted || !blocContext.mounted) return;
      if (targetPath == null || targetPath.trim().isEmpty) {
        return;
      }

      await getIt<PurchaseImportTemplateService>().saveArabicTemplate(
        targetPath: targetPath,
      );

      if (!mounted || !blocContext.mounted) return;
      _showLatestSnackBar(blocContext, 'Template saved successfully.'.tr());
    } catch (e) {
      if (!mounted || !blocContext.mounted) return;
      _showLatestSnackBar(blocContext, '${'Template save failed'.tr()}: $e');
    } finally {
      if (mounted) {
        setState(() => _savingImportTemplate = false);
      }
    }
  }

  Future<void> _importItemsFromFile(BuildContext blocContext) async {
    if (_importingItems) return;
    final allowed = await _ensurePurchasesWriteAllowed();
    if (!allowed) return;
    if (!mounted || !blocContext.mounted) return;

    setState(() => _importingItems = true);
    try {
      final fileResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
        allowMultiple: false,
      );

      if (!mounted || !blocContext.mounted) return;
      if (fileResult == null || fileResult.files.isEmpty) {
        return;
      }

      final selectedFile = fileResult.files.single;
      final fileName = selectedFile.name.trim();
      if (fileName.isEmpty) {
        _showLatestSnackBar(blocContext, 'Invalid import file.'.tr());
        return;
      }

      var bytes = selectedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        final filePath = selectedFile.path;
        if (filePath == null || filePath.trim().isEmpty) {
          _showLatestSnackBar(
            blocContext,
            'Unable to read selected file.'.tr(),
          );
          return;
        }
        bytes = await File(filePath).readAsBytes();
      }

      try {
        final productParse = ProductsImportService().parse(
          fileBytes: bytes,
          fileName: fileName,
        );

        final hasProductDefinitionData = productParse.rows.any(
          (row) =>
              row.purchasePrice > 0 ||
              row.salePrice > 0 ||
              row.salePriceHalfWholesale > 0 ||
              row.salePriceWholesale > 0 ||
              row.lowStockThreshold > 0 ||
              row.unitType == UnitType.weight,
        );

        if (hasProductDefinitionData && productParse.rows.isNotEmpty) {
          if (!mounted || !blocContext.mounted) return;
          final reviewedRows = await _showProductsPreApplyDialog(
            blocContext,
            productParse.rows,
          );
          if (!mounted || !blocContext.mounted) return;
          if (reviewedRows == null) {
            return;
          }
          if (reviewedRows.isNotEmpty) {
            await _productRepo.upsertImportedProducts(rows: reviewedRows);
          }
        }
      } catch (_) {
        // Ignore product-definition parse errors here; line-item import still proceeds.
      }

      final products = await _productRepo.listProducts();
      final importResult = _purchaseItemsImportService.parseAndResolve(
        fileBytes: bytes,
        fileName: fileName,
        products: products,
      );

      if (!mounted || !blocContext.mounted) return;

      if (importResult.lines.isEmpty) {
        _showLatestSnackBar(blocContext, 'No valid rows to import.'.tr());
        if (importResult.issues.isNotEmpty ||
            importResult.warnings.isNotEmpty) {
          await _showImportSummaryDialog(blocContext, importResult);
        }
        return;
      }

      final shouldApply = await _showImportPreviewDialog(
        blocContext,
        importResult,
      );
      if (!mounted || !blocContext.mounted || !shouldApply) return;

      final cubit = blocContext.read<PurchasesCubit>();
      final existingByProductId = {
        for (final item in cubit.state.cart) item.productId: item,
      };

      for (final line in importResult.lines) {
        final productId = line.product.id;
        if (productId == null) continue;

        final existing = existingByProductId[productId];
        if (existing == null) {
          cubit.addProduct(line.product);
        }

        final base = existingByProductId[productId];
        final nextQuantity = (base?.quantity ?? 0) + line.quantity;
        final nextDiscount = (base?.discount ?? 0) + line.discount;

        cubit.updateItem(
          productId,
          quantity: nextQuantity,
          unitPrice: line.unitPrice,
          discount: nextDiscount,
        );

        existingByProductId[productId] =
            (existingByProductId[productId] ??
                    PurchaseDraftItem(
                      productId: productId,
                      productName: line.product.name,
                      unitType: line.product.unitType.name,
                      quantity: 0,
                      unitPrice: line.unitPrice,
                    ))
                .copyWith(
                  quantity: nextQuantity,
                  unitPrice: line.unitPrice,
                  discount: nextDiscount,
                );
      }

      await _searchProducts(_searchController.text);
      if (!mounted || !blocContext.mounted) return;

      final summary =
          '${'Rows added'.tr()}: ${importResult.addedRows}  •  ${'Rows skipped'.tr()}: ${importResult.skippedRows}';
      _showLatestSnackBar(blocContext, '${'Import completed'.tr()}. $summary');

      if (importResult.issues.isNotEmpty || importResult.warnings.isNotEmpty) {
        await _showImportSummaryDialog(blocContext, importResult);
      }
    } catch (e) {
      if (!mounted || !blocContext.mounted) return;
      _showLatestSnackBar(
        blocContext,
        '${'Import failed'.tr()}: ${_localizedImportExceptionMessage(e)}',
      );
    } finally {
      if (mounted) {
        setState(() => _importingItems = false);
      }
    }
  }

  Future<bool> _showImportPreviewDialog(
    BuildContext context,
    PurchaseImportResult result,
  ) async {
    final width = (MediaQuery.sizeOf(context).width * 0.9).clamp(420.0, 860.0);
    final previewLines = result.lines
        .map(
          (line) =>
              '${line.product.name}  •  ${'Qty'.tr()}: ${line.quantity.toStringAsFixed(2)}  •  ${'Unit Price'.tr()}: ${line.unitPrice.toStringAsFixed(2)}  •  ${'Discount'.tr()}: ${line.discount.toStringAsFixed(2)}',
        )
        .toList(growable: false);

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Preview'.tr(),
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review import rows before applying to cart.'.tr(),
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          '${'Rows valid'.tr()}: ${result.lines.length}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${'Rows with issues'.tr()}: ${result.issues.length}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${'Rows with warnings'.tr()}: ${result.warnings.length}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: previewLines.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• ${previewLines[index]}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text('Cancel Import'.tr()),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text('Apply Import'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return approved ?? false;
  }

  Future<List<ProductsImportRow>?> _showProductsPreApplyDialog(
    BuildContext context,
    List<ProductsImportRow> rows,
  ) async {
    if (rows.isEmpty) {
      return const <ProductsImportRow>[];
    }

    final width = (MediaQuery.sizeOf(context).width * 0.94).clamp(460.0, 980.0);
    final drafts = List<ProductsImportRow>.from(rows);

    final approvedRows = await showDialog<List<ProductsImportRow>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: 680),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review product rows before saving.'.tr(),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edit imported products before they are added to products list.'
                            .tr(),
                        style: Theme.of(dialogContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: width - 64),
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 14,
                                horizontalMargin: 10,
                                headingRowHeight: 42,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 56,
                                columns: [
                                  DataColumn(label: Text('Name'.tr())),
                                  DataColumn(
                                    label: Text('Barcode (optional)'.tr()),
                                  ),
                                  DataColumn(label: Text('Unit Type'.tr())),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Retail Price'.tr()),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Half Wholesale Price'.tr()),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Wholesale Price'.tr()),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Purchase Price'.tr()),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Low Stock Threshold'.tr()),
                                  ),
                                  DataColumn(label: Text('Actions'.tr())),
                                ],
                                rows: [
                                  for (
                                    var index = 0;
                                    index < drafts.length;
                                    index++
                                  )
                                    DataRow(
                                      cells: [
                                        DataCell(Text(drafts[index].name)),
                                        DataCell(
                                          Text(
                                            (drafts[index].barcode ?? '')
                                                    .trim()
                                                    .isEmpty
                                                ? '-'
                                                : drafts[index].barcode!.trim(),
                                          ),
                                        ),
                                        DataCell(
                                          Text(drafts[index].unitType.name),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[index].salePrice
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[index].salePriceHalfWholesale
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[index].salePriceWholesale
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[index].purchasePrice
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[index].lowStockThreshold
                                                .toStringAsFixed(0),
                                          ),
                                        ),
                                        DataCell(
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final edited =
                                                  await _editImportedProductDraft(
                                                    dialogContext,
                                                    drafts[index],
                                                  );
                                              if (edited == null ||
                                                  !dialogContext.mounted) {
                                                return;
                                              }
                                              setDialogState(
                                                () => drafts[index] = edited,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            label: Text('Edit Product'.tr()),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(null),
                            child: Text('Cancel Import'.tr()),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(List<ProductsImportRow>.unmodifiable(drafts)),
                            child: Text('Apply Import'.tr()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return approvedRows;
  }

  Future<ProductsImportRow?> _editImportedProductDraft(
    BuildContext context,
    ProductsImportRow row,
  ) async {
    Product? editedPayload;

    await PurchasesProductDialog.show(
      context,
      initialName: row.name,
      initialQuantity: 1,
      initialPurchasePrice: row.purchasePrice,
      parseFlexibleNumber: parseFlexibleNumber,
      onCreateProduct: (payload) async {
        editedPayload = payload;
        return payload;
      },
      onUpdateProduct: (payload) async {},
      onRefreshSearch: () async {},
      onCreatedAttachToCart: (created, enteredQuantity) {},
      onUpdatedSyncCart: (productId, unitPrice) {},
    );

    final payload = editedPayload;
    if (payload == null) {
      return null;
    }

    return ProductsImportRow(
      name: payload.name,
      barcode: payload.barcode,
      unitType: payload.unitType,
      salePrice: payload.salePrice,
      salePriceHalfWholesale: payload.salePriceHalfWholesale,
      salePriceWholesale: payload.salePriceWholesale,
      purchasePrice: payload.purchasePrice,
      lowStockThreshold: payload.lowStockThreshold,
    );
  }

  Future<void> _showImportSummaryDialog(
    BuildContext context,
    PurchaseImportResult result,
  ) async {
    final width = (MediaQuery.sizeOf(context).width * 0.9).clamp(360.0, 760.0);
    final hasReportRows =
        result.issues.isNotEmpty || result.warnings.isNotEmpty;
    final issueLines = [
      for (final issue in result.issues)
        '• ${'Row'.tr()} ${issue.rowNumber}: ${_localizedImportIssueMessage(issue.message)}',
    ];
    final warningLines = [
      for (final warning in result.warnings)
        '• ${'Row'.tr()} ${warning.rowNumber}: ${_localizedImportIssueMessage(warning.message)}',
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Summary'.tr(),
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text('${'Rows read'.tr()}: ${result.totalRows}'),
                  Text('${'Rows added'.tr()}: ${result.addedRows}'),
                  Text('${'Rows skipped'.tr()}: ${result.skippedRows}'),
                  if (warningLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${'Warnings'.tr()} (${warningLines.length})',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                  ],
                  if (issueLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${'Errors'.tr()} (${issueLines.length})',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        ...warningLines.map((line) => Text(line)),
                        if (warningLines.isNotEmpty && issueLines.isNotEmpty)
                          const SizedBox(height: 8),
                        ...issueLines.map((line) => Text(line)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasReportRows)
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _exportImportIssuesReport(context, result);
                          },
                          icon: const Icon(Icons.download_outlined),
                          label: Text('Export Error Report'.tr()),
                        ),
                      if (hasReportRows) const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text('Close'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportImportIssuesReport(
    BuildContext context,
    PurchaseImportResult result,
  ) async {
    if (result.issues.isEmpty && result.warnings.isEmpty) {
      _showLatestSnackBar(context, 'No import issues to export.'.tr());
      return;
    }

    try {
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Error Report'.tr(),
        fileName: 'purchase_import_issues_report.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );

      if (!mounted) return;
      if (targetPath == null || targetPath.trim().isEmpty) {
        return;
      }

      final rows = <String>[
        'type,row,message',
        ...result.warnings.map(
          (warning) =>
              'warning,${warning.rowNumber},"${_localizedImportIssueMessage(warning.message).replaceAll('"', '""')}"',
        ),
        ...result.issues.map(
          (issue) =>
              'error,${issue.rowNumber},"${_localizedImportIssueMessage(issue.message).replaceAll('"', '""')}"',
        ),
      ];

      final file = File(targetPath);
      await file.writeAsString(
        '\uFEFF${rows.join('\n')}',
        encoding: utf8,
        flush: true,
      );

      if (!mounted || !context.mounted) return;
      _showLatestSnackBar(context, 'Error report saved successfully.'.tr());
    } catch (e) {
      if (!mounted || !context.mounted) return;
      _showLatestSnackBar(context, '${'Error report export failed'.tr()}: $e');
    }
  }

  String _localizedImportIssueMessage(String raw) {
    switch (raw) {
      case 'Unknown product (barcode/name not found).':
      case 'Invalid quantity. Quantity must be a positive number.':
      case 'Piece products require whole quantity.':
      case 'Invalid unit price. Unit price must be zero or positive.':
      case 'Invalid discount. Discount must be zero or positive.':
      case 'Discount exceeds line total.':
      case 'Product has no valid ID in local database.':
      case 'Duplicate product with different price. Last imported price was applied.':
      case 'Ambiguous product name. Please provide barcode for exact match.':
        return raw.tr();
      default:
        return raw;
    }
  }

  String _localizedImportExceptionMessage(Object error) {
    var message = error.toString();
    const badStatePrefix = 'Bad state: ';
    const formatPrefix = 'FormatException: ';
    if (message.startsWith(badStatePrefix)) {
      message = message.substring(badStatePrefix.length);
    }
    if (message.startsWith(formatPrefix)) {
      message = message.substring(formatPrefix.length);
    }

    if (message.startsWith('Unsupported file type:')) {
      return 'Unsupported file type.'.tr();
    }

    switch (message.trim()) {
      case 'The selected file is empty.':
      case 'The selected file does not contain headers.':
      case 'Missing required columns. Expected Quantity and Name. Barcode is optional.':
        return message.trim().tr();
      default:
        return message;
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
        blocContext.read<PurchasesCubit>().setSupplier(supplierId);
      },
    );

    await _loadSuppliers();
  }

  Future<void> _createProductDialog(
    BuildContext blocContext, [
    Product? existingProduct,
  ]) async {
    final allowed = await _ensurePurchasesWriteAllowed();
    if (!allowed) return;
    if (!mounted || !blocContext.mounted) return;

    await PurchasesProductDialog.show(
      blocContext,
      existingProduct: existingProduct,
      parseFlexibleNumber: parseFlexibleNumber,
      onCreateProduct: _productRepo.createProduct,
      onUpdateProduct: _productRepo.updateProduct,
      onRefreshSearch: () => _searchProducts(_searchController.text),
      onCreatedAttachToCart: (created, enteredQuantity) {
        if (!mounted || !blocContext.mounted) return;
        blocContext.read<PurchasesCubit>().addProduct(created);
        final createdId = created.id;
        if (createdId != null) {
          blocContext.read<PurchasesCubit>().updateItem(
            createdId,
            quantity: enteredQuantity,
          );
        }
      },
      onUpdatedSyncCart: (productId, unitPrice) {
        if (!mounted || !blocContext.mounted) return;
        blocContext.read<PurchasesCubit>().updateItem(
          productId,
          unitPrice: unitPrice,
        );
      },
    );
  }

  Future<void> _deleteProductFromEntryList(
    BuildContext blocContext,
    Product product,
  ) async {
    final allowed = await _ensurePurchasesWriteAllowed();
    if (!allowed) return;
    if (!mounted || !blocContext.mounted) return;

    final productId = product.id;
    if (productId == null) return;

    final confirmed = await showDialog<bool>(
      context: blocContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete Product'.tr()),
          content: Text('Are you sure you want to delete this product?'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _productRepo.deleteProduct(productId);
      if (!mounted || !blocContext.mounted) return;
      blocContext.read<PurchasesCubit>().removeItem(productId);
      await _searchProducts(_searchController.text);
      if (!mounted || !blocContext.mounted) return;
      _showLatestSnackBar(blocContext, 'Product deleted successfully'.tr());
    } catch (e) {
      if (!mounted || !blocContext.mounted) return;
      _showLatestSnackBar(blocContext, _presentPurchaseError(e.toString()));
    }
  }

  @override
  void dispose() {
    _productRepo.productsRevisionListenable.removeListener(
      _handleProductsRevisionChanged,
    );
    _searchController.dispose();
    _paidController.dispose();
    _taxPercentController.dispose();
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
          if (state.successInvoiceId != null) {
            _showLatestSnackBar(
              context,
              '${'Purchase saved'.tr()}: #${state.successInvoiceId}',
            );
            _paymentStatus = _PurchasePaymentStatus.full;
            _paidController.clear();
            _taxPercentController.clear();
            _loadInvoices();
          }
          if (state.error != null) {
            _showLatestSnackBar(context, _presentPurchaseError(state.error!));
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
              children: [
                PurchasesHeaderSection(
                  isShortViewport: isShortViewport,
                  isVeryDenseViewport: isVeryDenseViewport,
                  readOnlyMode: _readOnlyMode,
                  readOnlyMessage: _readOnlyMessage,
                  actions: [
                    OutlinedButton.icon(
                      onPressed: state.loading || _readOnlyMode
                          ? null
                          : () => _scanInvoice(context),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text('Scan Invoice'.tr()),
                    ),
                  ],
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
                            child: PurchasesProductsPane(
                              compact: compact,
                              searchController: _searchController,
                              searchResults: _searchResults,
                              onSearchChanged: _searchProducts,
                              onAddProduct: () => _createProductDialog(context),
                              onImportItems: () =>
                                  _importItemsFromFile(context),
                              onDownloadTemplate: () =>
                                  _downloadImportTemplate(context),
                              onEditProduct: (product) =>
                                  _createProductDialog(context, product),
                              onDeleteProduct: (product) =>
                                  _deleteProductFromEntryList(context, product),
                              onAddToCart: cubit.addProduct,
                              importing: _importingItems,
                              savingTemplate: _savingImportTemplate,
                              bottomChild: _buildInvoicesExplorer(context),
                            ),
                          ),
                          SizedBox(
                            width: compact ? 0 : sectionGap,
                            height: compact ? sectionGap : 0,
                          ),
                          Expanded(
                            flex: cartPaneFlex,
                            child: PurchasesCartPane(
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
                              taxPercentController: _taxPercentController,
                              paidController: _paidController,
                              paidAmountFocusNode: _paidAmountFocusNode,
                              taxAmount: state.taxAmount,
                              outstandingAmount:
                                  (state.total - state.paidAmount)
                                      .clamp(0, state.total)
                                      .toDouble(),
                              paymentMethod: state.paymentMethod,
                              paidFieldEnabled:
                                  _paymentStatus ==
                                  _PurchasePaymentStatus.partial,
                              onAddSupplier: () =>
                                  _createSupplierDialog(context),
                              onSupplierChanged: cubit.setSupplier,
                              onPaymentStatusChanged: (value) {
                                if (value == null) return;
                                final selectedStatus =
                                    _PurchasePaymentStatus.values[value];
                                setState(() => _paymentStatus = selectedStatus);
                                if (selectedStatus ==
                                    _PurchasePaymentStatus.full) {
                                  cubit.setPaidAmount(state.total);
                                } else if (selectedStatus ==
                                    _PurchasePaymentStatus.deferred) {
                                  cubit.setPaidAmount(0);
                                }
                              },
                              onTaxChanged: (v) => context
                                  .read<PurchasesCubit>()
                                  .setTaxPercentage(
                                    parseFlexibleNumber(v) ?? 0,
                                  ),
                              onPaidChanged:
                                  _paymentStatus ==
                                      _PurchasePaymentStatus.partial
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
                              onReturnFromInvoice: () =>
                                  _showReturnDialog(context),
                              onCancelInvoice: () => _showCancelDialog(context),
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
      activeInvoiceLines: _activeInvoiceLines,
      parseFlexibleInt: parseFlexibleInt,
      parseFlexibleNumber: parseFlexibleNumber,
      formatInvoiceQuantity: formatInvoiceQuantityValue,
      animateDialogEntrance: _animateDialogEntrance,
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
          await _searchProducts(_searchController.text);
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

  Widget _buildInvoicesExplorer(BuildContext blocContext) {
    return PurchasesInvoicesExplorer(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      accountId: widget.accountId,
      categoryId: widget.categoryId,
      loadingInvoices: _loadingInvoices,
      invoiceRows: _invoiceRows,
      invoiceScrollController: _invoiceScrollController,
      activeInvoiceId: _activeInvoiceId,
      activeInvoiceNumber: _activeInvoiceNumber,
      activePurchaseItemId: _activePurchaseItemId,
      invoicePage: _invoicePage,
      invoicePageSize: _invoicePageSize,
      invoiceLabelBuilder: buildPurchaseInvoiceLabel,
      onSelectInvoice: _selectInvoice,
      onReturnSelected: () => _showReturnDialog(
        blocContext,
        initialPurchaseId: _activeInvoiceId,
        initialPurchaseItemId: _activePurchaseItemId,
      ),
      onShowDetails: () => _showInvoiceDetailsDialog(blocContext),
      onCancelSelected: () =>
          _showCancelDialog(blocContext, initialPurchaseId: _activeInvoiceId),
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
