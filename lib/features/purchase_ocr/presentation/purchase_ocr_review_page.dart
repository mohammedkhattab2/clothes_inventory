import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:delta_erp/core/widgets/app_empty_state.dart';
import 'package:delta_erp/core/widgets/app_error_banner.dart';
import 'package:delta_erp/core/widgets/app_inline_loading_indicator.dart';
import 'package:delta_erp/core/widgets/app_loading_indicator.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_service.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:delta_erp/features/purchase_ocr/presentation/purchase_ocr_cubit.dart';
import 'package:delta_erp/features/purchase_ocr/presentation/widgets/purchase_ocr_observability_panel.dart';
import 'package:delta_erp/features/purchase_ocr/presentation/widgets/purchase_ocr_intelligence_panel.dart';
import 'package:delta_erp/features/purchases/presentation/widgets/purchases_product_dialog.dart';
import 'package:delta_erp/features/purchases/presentation/utils/purchases_formatters.dart';
import 'package:delta_erp/services/di/service_locator.dart';

class PurchaseOcrReviewPage extends StatelessWidget {
  const PurchaseOcrReviewPage({required this.imagePath, super.key});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<PurchaseOcrCubit>();
        unawaited(cubit.processImage(imagePath, userInitiated: true));
        return cubit;
      },
      child: _PurchaseOcrReviewView(imagePath: imagePath),
    );
  }
}

class _PurchaseOcrReviewView extends StatefulWidget {
  const _PurchaseOcrReviewView({required this.imagePath});

  final String imagePath;

  @override
  State<_PurchaseOcrReviewView> createState() => _PurchaseOcrReviewViewState();
}

class _PurchaseOcrReviewViewState extends State<_PurchaseOcrReviewView> {
  final _supplierController = TextEditingController();
  final _dateController = TextEditingController();
  final PurchaseOcrService _ocrService = getIt<PurchaseOcrService>();
  final ProductRepository _productRepository = getIt<ProductRepository>();
  late final PurchaseOcrObservabilityManager _observabilityManager;
  bool _retryInFlight = false;

  @override
  void initState() {
    super.initState();
    _observabilityManager = PurchaseOcrObservabilityManager(_ocrService);
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseOcrCubit, PurchaseOcrState>(
      listenWhen: (previous, current) {
        return previous.successInvoiceId != current.successInvoiceId ||
            previous.error != current.error;
      },
      listener: (context, state) {
        if (state.successInvoiceId != null) {
          Navigator.of(context).pop(state.successInvoiceId);
          return;
        }

        if (state.error != null && state.error!.trim().isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!.tr())));
        }
      },
      builder: (context, state) {
        final draft = state.draft;
        if (draft != null) {
          if (_supplierController.text != (draft.supplierName ?? '')) {
            _supplierController.value = _supplierController.value.copyWith(
              text: draft.supplierName ?? '',
              selection: TextSelection.collapsed(
                offset: (draft.supplierName ?? '').length,
              ),
            );
          }
          final dateText = draft.invoiceDate == null
              ? ''
              : DateFormat('yyyy-MM-dd').format(draft.invoiceDate!);
          if (_dateController.text != dateText) {
            _dateController.value = _dateController.value.copyWith(
              text: dateText,
              selection: TextSelection.collapsed(offset: dateText.length),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Invoice OCR Review'.tr()),
            actions: [
              if (kDebugMode)
                TextButton.icon(
                  onPressed: _showObservabilityPanel,
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text('ocr.review.stats'.tr()),
                ),
              if (kDebugMode)
                TextButton.icon(
                  onPressed: _showOcrHealthCheck,
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: Text('ocr.review.health_check'.tr()),
                ),
              TextButton.icon(
                onPressed: state.status == PurchaseOcrStatus.processing
                    ? null
                    : () => context
                          .read<PurchaseOcrCubit>()
                          .savePurchaseInvoice(),
                icon: state.status == PurchaseOcrStatus.saving
                    ? const AppInlineLoadingIndicator(size: 16)
                    : const Icon(Icons.save_outlined),
                label: Text('Save Invoice'.tr()),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Future<void> _showObservabilityPanel() async {
    if (!kDebugMode) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 960,
            height: 640,
            child: PurchaseOcrObservabilityPanel(
              manager: _observabilityManager,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PurchaseOcrState state) {
    final draft = state.draft;

    if (state.status == PurchaseOcrStatus.processing) {
      return AppLoadingIndicator(label: 'Extracting invoice data...'.tr());
    }

    if (draft == null &&
        state.error != null &&
        state.error!.trim().isNotEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppErrorBanner(message: state.error!.tr()),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text('Enter Manually'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: _retryInFlight ? null : () => _retryOcr(context),
                    icon: _retryInFlight
                        ? const AppInlineLoadingIndicator(size: 16)
                        : const Icon(Icons.refresh_outlined),
                    label: Text('Retry OCR'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (draft == null) {
      return AppEmptyState(
        icon: Icons.document_scanner_outlined,
        title: 'No OCR data to review.'.tr(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;

        final detailsCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Details'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: draft.supplierId,
                  decoration: InputDecoration(
                    labelText: 'Match Existing Supplier'.tr(),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Match'.tr()),
                    ),
                    ...state.suppliers.map(
                      (supplier) => DropdownMenuItem<int?>(
                        value: supplier.id,
                        child: Text(supplier.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    context.read<PurchaseOcrCubit>().setSupplierId(value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _supplierController,
                  decoration: InputDecoration(
                    labelText: 'Supplier name'.tr(),
                    helperText:
                        'Existing suppliers are auto-matched; new names will be created.'
                            .tr(),
                  ),
                  onChanged: (value) {
                    context.read<PurchaseOcrCubit>().setSupplierName(value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Invoice date'.tr(),
                    suffixIcon: IconButton(
                      onPressed: () => _pickDate(context, draft.invoiceDate),
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  onTap: () => _pickDate(context, draft.invoiceDate),
                ),
                const SizedBox(height: 8),
                Text(
                  '${'Detected total'.tr()}: ${draft.totalAmount?.toStringAsFixed(2) ?? '-'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${'Computed subtotal'.tr()}: ${draft.computedSubtotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                PurchaseOcrIntelligencePanel(
                  temporalInsights: state.temporalInsights,
                  trendAnomalies: state.trendAnomalies,
                  behavioralSignals: state.behavioralSignals,
                  learnedMappingsAppliedCount:
                      state.learnedMappingsApplied.length,
                  actionableRecommendations: state.actionableRecommendations,
                  riskScore: state.riskScore,
                ),
                const SizedBox(height: 12),
                _OcrAliasHintsCard(),
                const SizedBox(height: 12),
                _OcrExtractedTextCard(draft: draft),
              ],
            ),
          ),
        );

        final itemsCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Invoice Items'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<PurchaseOcrCubit>().addItem(),
                      icon: const Icon(Icons.add),
                      label: Text('Add Item'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: draft.items.isEmpty
                      ? AppEmptyState(
                          icon: Icons.list_alt_outlined,
                          title: 'No OCR items detected. Add manually.'.tr(),
                          compact: true,
                        )
                      : ListView.separated(
                          itemCount: draft.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final line = draft.items[index];
                            return _LineEditorCard(
                              key: ValueKey('ocr_line_$index'),
                              index: index,
                              item: line,
                              products: state.products,
                              onAddProduct: () =>
                                  _showCreateProductDialogForLine(
                                    index: index,
                                    line: line,
                                  ),
                              onChanged:
                                  ({
                                    name,
                                    quantity,
                                    price,
                                    matchedProductId,
                                    clearMatchedProduct = false,
                                  }) {
                                    context.read<PurchaseOcrCubit>().updateItem(
                                      index: index,
                                      productName: name,
                                      quantity: quantity,
                                      unitPrice: price,
                                      matchedProductId: matchedProductId,
                                      clearMatchedProduct: clearMatchedProduct,
                                    );
                                  },
                              onDelete: () => context
                                  .read<PurchaseOcrCubit>()
                                  .removeItem(index),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.status == PurchaseOcrStatus.saving
                        ? null
                        : () => context
                              .read<PurchaseOcrCubit>()
                              .savePurchaseInvoice(),
                    icon: state.status == PurchaseOcrStatus.saving
                        ? const AppInlineLoadingIndicator(size: 18)
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      state.status == PurchaseOcrStatus.saving
                          ? 'Saving...'.tr()
                          : 'Confirm and Save Purchase'.tr(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                detailsCard,
                const SizedBox(height: 12),
                Expanded(child: itemsCard),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(flex: 4, child: detailsCard),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: itemsCard),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateProductDialogForLine({
    required int index,
    required PurchaseOcrLineItemDraft line,
  }) async {
    await PurchasesProductDialog.show(
      context,
      initialName: line.productName,
      initialQuantity: line.quantity,
      initialPurchasePrice: line.unitPrice,
      parseFlexibleNumber: parseFlexibleNumber,
      onCreateProduct: _productRepository.createProduct,
      onUpdateProduct: _productRepository.updateProduct,
      onRefreshSearch: () async {},
      onCreatedAttachToCart: (created, enteredQuantity) async {
        if (!mounted) return;
        final cubit = context.read<PurchaseOcrCubit>();
        cubit.addOrUpdateProductInState(created);

        final createdId = created.id;
        if (createdId != null) {
          await cubit.updateItem(index: index, matchedProductId: createdId);
        }

        if (created.purchasePrice > 0 && line.unitPrice <= 0) {
          await cubit.updateItem(
            index: index,
            unitPrice: created.purchasePrice,
          );
        }

        final normalizedQty = enteredQuantity.roundToDouble();
        if (normalizedQty > 0) {
          await cubit.updateItem(index: index, quantity: normalizedQty);
        }
      },
      onUpdatedSyncCart: (productId, unitPrice) {},
    );
  }

  Future<void> _retryOcr(BuildContext context) async {
    if (_retryInFlight) return;

    setState(() => _retryInFlight = true);
    try {
      await context.read<PurchaseOcrCubit>().processImage(widget.imagePath);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OCR retry error: $error\n$stackTrace');
      }
    } finally {
      if (mounted) {
        setState(() => _retryInFlight = false);
      }
    }
  }

  Future<void> _showOcrHealthCheck() async {
    try {
      final health = _ocrService.debugHealthCheck();
      final version = await _ocrService.getTesseractVersion();
      final executablePath = Platform.resolvedExecutable;
      final ocrDirectoryPath = path.join(
        File(executablePath).parent.path,
        'ocr',
      );
      final lastFailure = _ocrService.getLastFailure();
      final diagnosticsText = _buildOcrDiagnostics(
        health: health,
        version: version,
        executablePath: executablePath,
        ocrDirectoryPath: ocrDirectoryPath,
        lastFailure: lastFailure,
      );
      if (!mounted) return;

      debugPrint('[OCR] Health check: $health');
      debugPrint('[OCR] Version: $version');

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('ocr.review.health_check'.tr()),
            content: SingleChildScrollView(
              child: Text(
                'ocr.review.health_dialog'.tr(
                  namedArgs: {'health': '$health', 'version': version},
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: diagnosticsText),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Diagnostics copied'.tr())),
                    );
                  } catch (error, stackTrace) {
                    if (kDebugMode) {
                      debugPrint(
                        'Failed copying diagnostics: $error\n$stackTrace',
                      );
                    }
                  }
                },
                child: Text('Copy Diagnostics'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Close'.tr()),
              ),
            ],
          );
        },
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OCR health check failed: $error\n$stackTrace');
      }
    }
  }

  String _buildOcrDiagnostics({
    required Map<String, bool> health,
    required String version,
    required String executablePath,
    required String ocrDirectoryPath,
    required OcrFailure? lastFailure,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final lastErrorMessage = lastFailure?.message ?? 'No previous OCR error';
    final lastErrorDebugDetails =
        lastFailure?.debugDetails ?? 'No previous OCR error';
    final lastErrorType = lastFailure?.type.name ?? 'unknown';
    final lastErrorCode =
        lastFailure?.errorCode ?? OcrErrorType.unknown.stableCode;
    final lastErrorSeverity =
        lastFailure?.severity.name ?? OcrErrorType.unknown.severity.name;
    final lastErrorFingerprint =
        lastFailure?.errorFingerprint ??
        '${OcrErrorType.unknown.stableCode}|${OcrErrorType.unknown.name}|no_image|runtime';
    final errorResolvedStatus = lastFailure == null
        ? 'unresolved'
        : _ocrService.getFingerprintResolutionStatus(lastErrorFingerprint);
    return [
      'timestamp: $timestamp',
      'executable_path: $executablePath',
      'ocr_directory_path: $ocrDirectoryPath',
      'health_check: $health',
      'last_error_message: $lastErrorMessage',
      'last_error_debug_details: $lastErrorDebugDetails',
      'last_error_type: $lastErrorType',
      'last_error_code: $lastErrorCode',
      'last_error_severity: $lastErrorSeverity',
      'last_error_fingerprint: $lastErrorFingerprint',
      'error_resolved_status: $errorResolvedStatus',
      'tesseract_version:\n$version',
    ].join('\n\n');
  }

  Future<void> _pickDate(BuildContext context, DateTime? initialDate) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate ?? now,
    );

    if (!context.mounted) return;
    context.read<PurchaseOcrCubit>().setInvoiceDate(selected);
  }
}

class _OcrAliasHintsCard extends StatelessWidget {
  const _OcrAliasHintsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text('OCR label hints'.tr()),
        subtitle: Text(
          'Use these names in supplier invoices to improve automatic extraction.'
              .tr(),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _AliasGroup(
            title: 'Item / Product'.tr(),
            aliases: PurchaseInvoiceParser.suggestedItemAliases,
          ),
          _AliasGroup(
            title: 'Quantity'.tr(),
            aliases: PurchaseInvoiceParser.suggestedQuantityAliases,
          ),
          _AliasGroup(
            title: 'Unit Price'.tr(),
            aliases: PurchaseInvoiceParser.suggestedUnitPriceAliases,
          ),
          _AliasGroup(
            title: 'Invoice Total'.tr(),
            aliases: PurchaseInvoiceParser.suggestedInvoiceTotalAliases,
          ),
        ],
      ),
    );
  }
}

class _AliasGroup extends StatelessWidget {
  const _AliasGroup({required this.title, required this.aliases});

  final String title;
  final List<String> aliases;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: aliases
                .map(
                  (alias) => Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(alias),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _OcrExtractedTextCard extends StatelessWidget {
  const _OcrExtractedTextCard({required this.draft});

  final PurchaseOcrDraft draft;

  @override
  Widget build(BuildContext context) {
    final candidateLines = _extractCandidateItemLines(draft.normalizedText);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text('OCR extracted text'.tr()),
        subtitle: Text(
          'Copy raw/normalized OCR text and send missing item lines.'.tr(),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: draft.rawText));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Raw OCR text copied'.tr())),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: Text('Copy Raw OCR'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: draft.normalizedText),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Normalized OCR text copied'.tr()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text('Copy Normalized OCR'.tr()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (candidateLines.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Candidate item lines'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidateLines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final line = candidateLines[index];
                  return SelectableText(line);
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: candidateLines.join('\n')),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Candidate lines copied'.tr())),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text('Copy Candidate Lines'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _extractCandidateItemLines(String normalizedText) {
    final lines = normalizedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final candidates = <String>[];
    final hasAlpha = RegExp(r'[A-Za-z\u0600-\u06FF]');
    final hasNumber = RegExp(r'[0-9٠-٩]');
    final likelyHeader = RegExp(
      r'(invoice|supplier|date|total|الاجمالي|الإجمالي|التاريخ|المورد)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (!hasAlpha.hasMatch(line) || !hasNumber.hasMatch(line)) {
        continue;
      }
      if (likelyHeader.hasMatch(line)) {
        continue;
      }
      candidates.add(line);
      if (candidates.length == 25) {
        break;
      }
    }
    return candidates;
  }
}

class _LineEditorCard extends StatefulWidget {
  const _LineEditorCard({
    required super.key,
    required this.index,
    required this.item,
    required this.products,
    required this.onChanged,
    required this.onAddProduct,
    required this.onDelete,
  });

  final int index;
  final PurchaseOcrLineItemDraft item;
  final List<Product> products;
  final void Function({
    String? name,
    double? quantity,
    double? price,
    int? matchedProductId,
    bool clearMatchedProduct,
  })
  onChanged;
  final VoidCallback onAddProduct;
  final VoidCallback onDelete;

  @override
  State<_LineEditorCard> createState() => _LineEditorCardState();
}

class _LineEditorCardState extends State<_LineEditorCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _qtyController;
  late final TextEditingController _priceController;
  late final FocusNode _qtyFocusNode;
  late final FocusNode _priceFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.productName);
    _qtyController = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _priceController = TextEditingController(
      text: widget.item.unitPrice.toStringAsFixed(2),
    );
    _qtyFocusNode = FocusNode();
    _priceFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _LineEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nameController.text != widget.item.productName) {
      _nameController.text = widget.item.productName;
    }

    final qtyText = widget.item.quantity.toStringAsFixed(0);
    if (!_qtyFocusNode.hasFocus && _qtyController.text != qtyText) {
      _qtyController.text = qtyText;
    }

    final priceText = widget.item.unitPrice.toStringAsFixed(2);
    if (!_priceFocusNode.hasFocus && _priceController.text != priceText) {
      _priceController.text = priceText;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'.tr()),
                  onChanged: (value) {
                    widget.onChanged(name: value, clearMatchedProduct: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add Product'.tr(),
                onPressed: widget.onAddProduct,
                icon: const Icon(Icons.add_box_outlined),
              ),
              IconButton(
                tooltip: 'Delete'.tr(),
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  focusNode: _qtyFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
                  ],
                  decoration: InputDecoration(labelText: 'Quantity'.tr()),
                  onChanged: (value) {
                    final parsed = parseFlexibleInt(value);
                    if (parsed != null && parsed > 0) {
                      widget.onChanged(quantity: parsed.toDouble());
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  focusNode: _priceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬]')),
                  ],
                  decoration: InputDecoration(labelText: 'Unit Price'.tr()),
                  onChanged: (value) {
                    final parsed = parseFlexibleNumber(value);
                    if (parsed != null) {
                      widget.onChanged(price: parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: widget.item.matchedProductId,
            decoration: InputDecoration(
              labelText: 'Match Existing Product'.tr(),
            ),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text('No Match'.tr())),
              ...widget.products.map(
                (product) => DropdownMenuItem<int?>(
                  value: product.id,
                  child: Text(product.name),
                ),
              ),
            ],
            onChanged: (value) {
              widget.onChanged(matchedProductId: value);
            },
          ),
        ],
      ),
    );
  }
}
