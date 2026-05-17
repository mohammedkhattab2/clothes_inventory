import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/core/config/company_settings.dart';
import 'package:delta_erp/core/utils/app_paths.dart';
import 'package:delta_erp/core/utils/translation_utils.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_print_model_mapper.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_print_preview_page.dart';
import 'package:delta_erp/features/invoices/presentation/widgets/a4_invoice_rtl_widget.dart';
import 'package:delta_erp/features/license/domain/license_models.dart';
import 'package:delta_erp/features/license/domain/license_service.dart';
import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_service.dart';
import 'package:delta_erp/features/settings/data/app_reset_service.dart';
import 'package:delta_erp/features/settings/presentation/widgets/settings_company_tab.dart';
import 'package:delta_erp/features/settings/presentation/widgets/settings_diagnostics_tab.dart';
import 'package:delta_erp/features/settings/presentation/widgets/settings_license_tab.dart';
import 'package:delta_erp/features/settings/presentation/widgets/settings_overview_tab.dart';
import 'package:delta_erp/services/database/maintenance_coordinator.dart';
import 'package:delta_erp/services/printing/a4_invoice_printer.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/thermal_pdf_invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:printing/printing.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/platform/folder_opener_service.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_document.dart';

enum _SettingsTab { overview, company, license, diagnostics }

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phonesController = TextEditingController();
  final _invoiceFooterNoteController = TextEditingController();
  static const _invoiceMapper = InvoicePrintModelMapper();
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

  static const _thermalPrefs = ThermalPrinterPreferences();

  bool _initialized = false;
  bool _saving = false;
  bool _resettingAppData = false;
  bool _loadingLogo = false;
  bool _loadingFooterImage = false;
  bool _selectingPrinter = false;
  String? _currentThermalPrinterName;
  Uint8List? _previewLogoBytes;
  Uint8List? _previewFooterImageBytes;
  String? _pendingLogoPath;
  String? _pendingFooterImagePath;
  bool _removeLogo = false;
  bool _removeFooterImage = false;
  late Future<LicenseValidationResult> _licenseStatusFuture;
  late Future<String> _machineCodeFuture;
  late Future<String> _machineHashFuture;
  late Future<List<LicenseActivationLogEntry>> _activationLogsFuture;
  late Future<SettingsSystemDiagnosticsData> _systemDiagnosticsFuture;
  late Future<SettingsOverviewSnapshot> _overviewFuture;
  LicenseHistoryFilter _activationHistoryFilter = LicenseHistoryFilter.all;

  CompanySettingsService get _service => getIt<CompanySettingsService>();
  LicenseService get _licenseService => getIt<LicenseService>();
  PurchaseOcrService get _ocrService => getIt<PurchaseOcrService>();
  FolderOpenerService get _folderOpenerService => getIt<FolderOpenerService>();
  AppResetService get _appResetService => getIt<AppResetService>();
  MaintenanceCoordinator get _maintenanceCoordinator =>
      getIt<MaintenanceCoordinator>();

  @override
  void initState() {
    super.initState();
    _licenseStatusFuture = _licenseService.validateCurrentLicense();
    _machineCodeFuture = _licenseService.getMachineCode();
    _machineHashFuture = _licenseService.getMachineHash();
    _activationLogsFuture = _licenseService.getRecentActivationLogs();
    _systemDiagnosticsFuture = _collectSystemDiagnostics();
    _overviewFuture = _collectOverviewState();
    _nameController.addListener(_onPreviewChanged);
    _addressController.addListener(_onPreviewChanged);
    _phonesController.addListener(_onPreviewChanged);
    _invoiceFooterNoteController.addListener(_onPreviewChanged);
    _loadThermalPrinterName();
  }

  Future<void> _loadThermalPrinterName() async {
    final name = await _thermalPrefs.loadPrinterName();
    if (mounted) setState(() => _currentThermalPrinterName = name);
  }

  Future<void> _selectThermalPrinter() async {
    if (_selectingPrinter) return;
    setState(() => _selectingPrinter = true);
    try {
      final printer = await Printing.pickPrinter(context: context);
      if (printer == null || !mounted) return;
      await _thermalPrefs.savePrinterName(printer.name);
      if (!mounted) return;
      setState(() => _currentThermalPrinterName = printer.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.thermal_printer_saved'.tr(namedArgs: {'name': printer.name}),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } finally {
      if (mounted) setState(() => _selectingPrinter = false);
    }
  }

  Future<void> _clearThermalPrinter() async {
    await _thermalPrefs.clearPrinterName();
    if (!mounted) return;
    setState(() => _currentThermalPrinterName = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings.thermal_printer_cleared'.tr())),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final settings = _service.settings;
    _nameController.text = settings.name;
    _addressController.text = settings.address;
    _phonesController.text = settings.phoneNumbers.join('\n');
    _invoiceFooterNoteController.text = settings.invoiceFooterNote;
    _loadLogoPreview();
    _loadFooterPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phonesController.dispose();
    _invoiceFooterNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final isDenseViewport = size.height < 820 || size.width < 1180;

    return DefaultTabController(
      length: _SettingsTab.values.length,
      child: AppPageShell(
        isCompact: isCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company Settings'.tr(),
              style: (isDenseViewport
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildTabsBar(context),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: SettingsOverviewTab(
                      key: const ValueKey('overview_tab'),
                      overviewFuture: _overviewFuture,
                      saving: _saving,
                      onSave: _save,
                      onReset: _resetFromCurrent,
                      onTestPrint: _openPrintPreview,
                      onOpenBackup: () => context.go('/settings/backup'),
                      headerPreview: _buildHeaderPreview(context),
                      invoicePreview: _buildInvoicePreview(context),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: SettingsCompanyTab(
                      key: const ValueKey('company_tab'),
                      formKey: _formKey,
                      nameController: _nameController,
                      addressController: _addressController,
                      phonesController: _phonesController,
                      invoiceFooterNoteController: _invoiceFooterNoteController,
                      saving: _saving,
                      loadingLogo: _loadingLogo,
                      loadingFooterImage: _loadingFooterImage,
                      logoPreview: _buildLogoPreview(context),
                      onPickLogo: _pickLogo,
                      onRemoveLogo: _removeLogoPreview,
                      footerImagePreview: _buildFooterImagePreview(context),
                      onPickFooterImage: _pickFooterImage,
                      onRemoveFooterImage: _removeFooterImagePreview,
                      onValidatePhones: _splitPhones,
                      onSave: _save,
                      onReset: _resetFromCurrent,
                      currentThermalPrinterName: _currentThermalPrinterName,
                      selectingPrinter: _selectingPrinter,
                      onSelectThermalPrinter: _selectThermalPrinter,
                      onClearThermalPrinter: _clearThermalPrinter,
                    ),
                  ),
                  SettingsLicenseTab(
                    licenseStatusFuture: _licenseStatusFuture,
                    machineCodeFuture: _machineCodeFuture,
                    machineHashFuture: _machineHashFuture,
                    activationLogsFuture: _activationLogsFuture,
                    activationHistoryFilter: _activationHistoryFilter,
                    onFilterChanged: (value) {
                      setState(() => _activationHistoryFilter = value);
                    },
                    activationStatusLabel: _activationStatusLabel,
                    onCopyToClipboard: _copyToClipboard,
                    onOpenRenewDialog: _openRenewLicenseDialog,
                    onCopyTxt: (logs) =>
                        _copyActivationHistory(logs, asCsv: false),
                    onCopyCsv: (logs) =>
                        _copyActivationHistory(logs, asCsv: true),
                    onExportTxt: (logs) =>
                        _exportActivationHistory(logs, asCsv: false),
                    onExportCsv: (logs) =>
                        _exportActivationHistory(logs, asCsv: true),
                  ),
                  SettingsDiagnosticsTab(
                    diagnosticsFuture: _systemDiagnosticsFuture,
                    onRefresh: () {
                      setState(() {
                        _systemDiagnosticsFuture = _collectSystemDiagnostics();
                        _overviewFuture = _collectOverviewState();
                      });
                    },
                    onCopyDiagnostics: _copyDiagnostics,
                    onOpenAppDataFolder: _openAppDataFolder,
                    onResetApplicationData: _confirmAndResetApplicationData,
                    resettingAppData: _resettingAppData,
                    resetBlocked:
                        _maintenanceCoordinator.isOperationRunning ||
                        _maintenanceCoordinator.isMaintenanceMode,
                    resetBlockedMessage:
                        _maintenanceCoordinator.isOperationRunning ||
                            _maintenanceCoordinator.isMaintenanceMode
                        ? 'Cannot reset while a critical operation is running.'
                              .tr()
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndResetApplicationData() async {
    if (_resettingAppData) {
      return;
    }

    final approved = await _showResetConfirmationDialog();
    if (!approved || !mounted) {
      return;
    }

    setState(() => _resettingAppData = true);
    final result = await _appResetService.resetApplicationData();

    if (!mounted) {
      return;
    }

    if (!result.success) {
      setState(() => _resettingAppData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trIfExists(result.message, context: context))),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (kDebugMode
                  ? 'Application data reset successfully. In debug mode, restart the app manually.'
                  : 'Application data reset successfully. Restarting...')
              .tr(),
        ),
      ),
    );

    if (kDebugMode) {
      setState(() => _resettingAppData = false);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      await _appResetService.restartApplication();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _resettingAppData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.restart_failed'.tr(namedArgs: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<bool> _showResetConfirmationDialog() async {
    final resetController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);
          final maxWidth = (size.width * 0.9).clamp(320.0, 560.0);
          var canConfirm = false;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Dialog(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Application'.tr(),
                          style: Theme.of(dialogContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'This will permanently delete ALL your data (database, logs, temp files). This action cannot be undone.'
                              .tr(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Type RESET to confirm.'.tr(),
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: resetController,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) {
                            setDialogState(() {
                              canConfirm = value == 'RESET';
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirmation'.tr(),
                            hintText: 'settings.reset_keyword'.tr(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(false);
                                },
                                child: Text('Cancel'.tr()),
                              ),
                              FilledButton(
                                onPressed: canConfirm
                                    ? () {
                                        Navigator.of(dialogContext).pop(true);
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    dialogContext,
                                  ).colorScheme.error,
                                  foregroundColor: Theme.of(
                                    dialogContext,
                                  ).colorScheme.onError,
                                ),
                                child: Text('Reset Application Data'.tr()),
                              ),
                            ],
                          ),
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

      return confirmed ?? false;
    } finally {
      resetController.dispose();
    }
  }

  Widget _buildTabsBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerLow,
      ),
      child: TabBar(
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
          ),
        ),
        tabs: [
          Tab(text: 'Overview'.tr()),
          Tab(text: 'Business Identity'.tr()),
          Tab(text: 'License'.tr()),
          Tab(text: 'Diagnostics'.tr()),
        ],
      ),
    );
  }

  Future<SettingsOverviewSnapshot> _collectOverviewState() async {
    final license = await _licenseService.validateCurrentLicense();
    final diagnostics = await _collectSystemDiagnostics();
    final settings = _service.settings;
    return SettingsOverviewSnapshot(
      licenseActive: license.isValid,
      ocrReady: diagnostics.ocrReady,
      profileName: settings.name.trim().isEmpty ? '-' : settings.name.trim(),
    );
  }

  void _refreshOverview() {
    if (!mounted) {
      return;
    }
    setState(() {
      _overviewFuture = _collectOverviewState();
    });
  }

  List<String> _splitPhones(String raw) {
    return raw
        .split(RegExp(r'[\n,;-]+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  void _onPreviewChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildLogoPreview(BuildContext context) {
    final size = 84.0;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final bytes = _previewLogoBytes;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: _loadingLogo
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (bytes == null
                ? Icon(
                    Icons.image_not_supported_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  )),
    );
  }

  Widget _buildFooterImagePreview(BuildContext context) {
    final size = 84.0;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final bytes = _previewFooterImageBytes;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: _loadingFooterImage
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (bytes == null
                ? Icon(
                    Icons.qr_code_2_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(bytes, fit: BoxFit.contain                  ),
                )),
    );
  }

  Widget _buildHeaderPreview(BuildContext context) {
    final company = _buildPreviewCompany();
    return AppSectionPanel(
      emphasis: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_previewLogoBytes != null) ...[
            Center(
              child: SizedBox(
                height: 58,
                width: 58,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_previewLogoBytes!, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            company.name,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            company.address,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            company.phoneNumbers.join(' - '),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<SettingsSystemDiagnosticsData> _collectSystemDiagnostics() async {
    String appDataPath = 'n/a';
    String databasePath = 'n/a';
    String logsPath = 'n/a';
    String tempPath = 'n/a';
    bool healthOk = false;
    String healthMessage = 'backup.not_available'.tr();
    bool ocrReady = false;
    String ocrVersion = 'backup.not_available'.tr();
    String? generalError;

    try {
      final appDataDir = await AppPaths.getAppDataDir();
      appDataPath = appDataDir.path;
    } catch (error) {
      appDataPath = 'settings.unavailable'.tr();
      generalError = 'settings.appdata_path_failed'.tr(
        namedArgs: {'error': '$error'},
      );
    }

    try {
      databasePath = await AppPaths.getDatabasePath();
    } catch (error) {
      databasePath = 'settings.unavailable'.tr();
      generalError = generalError ??
          'settings.database_path_failed'.tr(namedArgs: {'error': '$error'});
    }

    try {
      logsPath = await AppPaths.getLogsPath();
    } catch (error) {
      logsPath = 'settings.unavailable'.tr();
      generalError = generalError ??
          'settings.logs_path_failed'.tr(namedArgs: {'error': '$error'});
    }

    try {
      tempPath = await AppPaths.getTempDir();
    } catch (error) {
      tempPath = 'settings.unavailable'.tr();
      generalError = generalError ??
          'settings.temp_path_failed'.tr(namedArgs: {'error': '$error'});
    }

    try {
      healthOk = await AppPaths.healthCheck();
      healthMessage = healthOk ? 'Healthy'.tr() : 'settings.health_check_failed'.tr();
    } catch (error) {
      healthOk = false;
      healthMessage = error.toString();
    }

    try {
      final ocrHealth = _ocrService.debugHealthCheck();
      ocrReady = ocrHealth.values.every((value) => value);
    } catch (error) {
      ocrReady = false;
      generalError = generalError ??
          'settings.ocr_health_check_failed'.tr(namedArgs: {'error': '$error'});
    }

    try {
      ocrVersion = await _ocrService.getTesseractVersion();
      if (ocrVersion.trim().isEmpty) {
        ocrVersion = 'backup.not_available'.tr();
      }
    } catch (error) {
      ocrVersion = 'settings.error_with_detail'.tr(namedArgs: {'error': '$error'});
    }

    final lastError = _ocrService.getLastFailure();
    return SettingsSystemDiagnosticsData(
      appDataPath: appDataPath,
      databasePath: databasePath,
      logsPath: logsPath,
      tempPath: tempPath,
      healthOk: healthOk,
      healthMessage: healthMessage,
      ocrReady: ocrReady,
      ocrVersion: ocrVersion,
      lastOcrErrorCode: lastError?.errorCode,
      lastOcrErrorType: lastError?.type.name,
      lastOcrErrorSeverity: lastError?.severity.name,
      generalError: generalError,
    );
  }

  Future<void> _copyDiagnostics(SettingsSystemDiagnosticsData data) async {
    try {
      final lines = <String>[
        'System Diagnostics',
        'AppData Directory: ${data.appDataPath}',
        'Database Path: ${data.databasePath}',
        'Logs Path: ${data.logsPath}',
        'Temp Directory: ${data.tempPath}',
        'Health Status: ${data.healthOk ? 'Healthy' : 'Error'}',
        if (!data.healthOk) 'Health Message: ${data.healthMessage}',
        'OCR Status: ${data.ocrReady ? 'OCR Ready' : 'OCR Not Ready'}',
        'Tesseract Version: ${data.ocrVersion}',
        'Last OCR Error Code: ${data.lastOcrErrorCode ?? 'n/a'}',
        'Last OCR Error Type: ${data.lastOcrErrorType ?? 'n/a'}',
        'Last OCR Error Severity: ${data.lastOcrErrorSeverity ?? 'n/a'}',
        if (data.generalError != null)
          'Diagnostics Warning: ${data.generalError}',
      ];
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Diagnostics copied'.tr())));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.copy_diagnostics_failed'.tr(
              namedArgs: {'error': '$error'},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openAppDataFolder(SettingsSystemDiagnosticsData data) async {
    try {
      final target =
          data.databasePath == 'n/a' ||
              data.databasePath == 'settings.unavailable'.tr()
          ? data.logsPath
          : data.databasePath;
      if (target == 'n/a' || target == 'settings.unavailable'.tr()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.appdata_path_unavailable'.tr())),
        );
        return;
      }

      final opened = await _folderOpenerService.openContainingFolder(target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'settings.appdata_opened'.tr()
                : 'settings.appdata_open_failed'.tr(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.appdata_open_failed_with_error'.tr(
              namedArgs: {'error': '$error'},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _exportActivationHistory(
    List<LicenseActivationLogEntry> logs, {
    required bool asCsv,
  }) async {
    if (logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license.no_activation_history'.tr())),
      );
      return;
    }

    final fileExt = asCsv ? 'csv' : 'txt';
    final suggestedName = 'license_activation_history.$fileExt';
    final targetPath = await FilePicker.platform.saveFile(
      dialogTitle: 'license.export_dialog_title'.tr(),
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: [fileExt],
    );

    if (targetPath == null || targetPath.trim().isEmpty) {
      return;
    }

    final String content = asCsv
        ? _buildActivationHistoryCsv(logs)
        : _buildActivationHistoryTxt(logs);

    try {
      await File(targetPath).writeAsString(content, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('license.export_success'.tr())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('license.export_failed'.tr())));
    }
  }

  Future<void> _copyActivationHistory(
    List<LicenseActivationLogEntry> logs, {
    required bool asCsv,
  }) async {
    if (logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license.no_activation_history'.tr())),
      );
      return;
    }

    final content = asCsv
        ? _buildActivationHistoryCsv(logs)
        : _buildActivationHistoryTxt(logs);

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('license.copy_report_success'.tr())));
  }

  String _buildActivationHistoryTxt(List<LicenseActivationLogEntry> logs) {
    final buffer = StringBuffer();
    for (final log in logs) {
      final when = log.at
          .toLocal()
          .toString()
          .replaceFirst('T', ' ')
          .split('.')
          .first;
      buffer.writeln('time: $when');
      buffer.writeln('status: ${_activationStatusLabel(log.success)}');
      buffer.writeln('code: ${log.code}');
      if (log.message != null && log.message!.trim().isNotEmpty) {
        buffer.writeln('message: ${log.message}');
      }
      buffer.writeln('---');
    }
    return buffer.toString();
  }

  String _buildActivationHistoryCsv(List<LicenseActivationLogEntry> logs) {
    final buffer = StringBuffer();
    buffer.writeln('time,status,code,message');
    for (final log in logs) {
      final when = log.at
          .toLocal()
          .toString()
          .replaceFirst('T', ' ')
          .split('.')
          .first;
      final status = _activationStatusLabel(log.success);
      final code = _csvEscape(log.code);
      final message = _csvEscape(log.message ?? '');
      buffer.writeln('"$when","$status","$code","$message"');
    }
    return buffer.toString();
  }

  String _csvEscape(String value) {
    return value.replaceAll('"', '""');
  }

  String _activationStatusLabel(bool success) {
    if (success) {
      return 'license.activation_success_short'.tr();
    }
    return 'license.activation_failed_short'.tr();
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('license.copied'.tr())));
  }

  Future<void> _openRenewLicenseDialog() async {
    final TextEditingController controller = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('license.renew'.tr()),
              content: SizedBox(
                width: 560,
                child: TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: 'license.enter_activation_code'.tr(),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel'.tr()),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final code = controller.text.trim();
                          if (code.isEmpty) return;
                          setDialogState(() => submitting = true);
                          final result = await _licenseService.activateFromCode(
                            code,
                          );
                          if (!mounted) return;
                          _licenseStatusFuture = _licenseService
                              .validateCurrentLicense();
                          _activationLogsFuture = _licenseService
                              .getRecentActivationLogs();
                          setState(() {
                            _overviewFuture = _collectOverviewState();
                          });
                          if (result.isValid) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'license.activation_success'.tr(),
                                ),
                              ),
                            );
                          } else {
                            setDialogState(() => submitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message ??
                                      'license.activation_failed'.tr(),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    submitting ? 'Saving...'.tr() : 'license.activate'.tr(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _buildInvoicePreview(BuildContext context) {
    return AppSectionPanel(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: _CompanyInvoiceFormatPreview(
          a4Data: _buildPreviewInvoiceData(),
          logoBytes: _previewLogoBytes,
          invoiceModel: _buildPreviewInvoiceModel(),
        ),
      ),
    );
  }

  Future<void> _loadLogoPreview() async {
    setState(() => _loadingLogo = true);
    try {
      final bytes = await _service.loadLogoBytes();
      if (!mounted) return;
      setState(() {
        _previewLogoBytes = bytes;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingLogo = false);
      }
    }
  }

  Future<void> _pickLogo() async {
    setState(() => _loadingLogo = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;

      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) return;

      setState(() {
        _previewLogoBytes = bytes;
        _pendingLogoPath = file.path;
        _removeLogo = false;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingLogo = false);
      }
    }
  }

  void _removeLogoPreview() {
    setState(() {
      _previewLogoBytes = null;
      _pendingLogoPath = null;
      _removeLogo = true;
    });
  }

  Future<void> _loadFooterPreview() async {
    setState(() => _loadingFooterImage = true);
    try {
      final bytes = await _service.loadFooterImageBytes();
      if (!mounted) return;
      setState(() {
        _previewFooterImageBytes = bytes;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFooterImage = false);
      }
    }
  }

  Future<void> _pickFooterImage() async {
    setState(() => _loadingFooterImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;

      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) return;

      setState(() {
        _previewFooterImageBytes = bytes;
        _pendingFooterImagePath = file.path;
        _removeFooterImage = false;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFooterImage = false);
      }
    }
  }

  void _removeFooterImagePreview() {
    setState(() {
      _previewFooterImageBytes = null;
      _pendingFooterImagePath = null;
      _removeFooterImage = true;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.save(
        name: _nameController.text,
        address: _addressController.text,
        phoneNumbers: _splitPhones(_phonesController.text),
        invoiceFooterNote: _invoiceFooterNoteController.text,
      );

      if (_removeLogo) {
        await _service.clearLogo();
      } else if (_pendingLogoPath != null &&
          _pendingLogoPath!.trim().isNotEmpty) {
        await _service.setLogoFromPath(_pendingLogoPath!);
      }

      if (_removeFooterImage) {
        await _service.clearFooterImage();
      } else if (_pendingFooterImagePath != null &&
          _pendingFooterImagePath!.trim().isNotEmpty) {
        await _service.setFooterImageFromPath(_pendingFooterImagePath!);
      }

      _removeLogo = false;
      _pendingLogoPath = null;
      _removeFooterImage = false;
      _pendingFooterImagePath = null;
      await _loadLogoPreview();
      await _loadFooterPreview();
      _licenseStatusFuture = _licenseService.validateCurrentLicense();

      if (!mounted) return;
      _refreshOverview();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company settings saved successfully.'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to save settings'.tr()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _resetFromCurrent() {
    final settings = _service.settings;
    _nameController.text = settings.name;
    _addressController.text = settings.address;
    _phonesController.text = settings.phoneNumbers.join('\n');
    _invoiceFooterNoteController.text = settings.invoiceFooterNote;
    _removeLogo = false;
    _pendingLogoPath = null;
    _removeFooterImage = false;
    _pendingFooterImagePath = null;
    _loadLogoPreview();
    _loadFooterPreview();
    _refreshOverview();
  }

  Future<void> _openPrintPreview() async {
    final invoice = _buildPreviewInvoiceModel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePrintPreviewPage(
          invoice: invoice,
          printManager: _invoicePrintManager,
        ),
      ),
    );
  }

  String _previewPhonesText() {
    final phones = _splitPhones(_phonesController.text);
    if (phones.isEmpty) return '-';
    return phones.join(' - ');
  }

  CompanySettings _buildPreviewCompany() {
    return CompanySettings(
      name: _nameController.text.trim().isEmpty
          ? _service.settings.name
          : _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? _service.settings.address
          : _addressController.text.trim(),
      phoneNumbers: _splitPhones(_phonesController.text).isEmpty
          ? _service.settings.phoneNumbers
          : _splitPhones(_phonesController.text),
      logoPath: _service.settings.logoPath,
      invoiceFooterNote: _invoiceFooterNoteController.text,
      invoiceFooterImagePath: _removeFooterImage
          ? null
          : (_pendingFooterImagePath ?? _service.settings.invoiceFooterImagePath),
    );
  }

  A4InvoiceViewData _buildPreviewInvoiceData() {
    return _invoiceMapper.toA4ViewData(_buildPreviewInvoiceModel());
  }

  InvoicePrintModel _buildPreviewInvoiceModel() {
    final company = _buildPreviewCompany();
    final footerBytes = _removeFooterImage
        ? null
        : _previewFooterImageBytes;
    return InvoicePrintModel(
      companyName: company.name,
      address: company.address,
      phone: _previewPhonesText(),
      invoiceNumber: 'PREVIEW-001',
      date: DateTime.now(),
      customerName: 'settings.preview_customer_name'.tr(),
      items: [
        InvoiceItem(
          productName: 'settings.preview_product_a'.tr(),
          quantity: 2,
          unitPrice: 45,
        ),
        InvoiceItem(
          productName: 'settings.preview_product_b'.tr(),
          quantity: 1,
          unitPrice: 60,
        ),
      ],
      total: 150,
      title: 'Sales Invoice'.tr(),
      invoiceFooterNote: company.invoiceFooterNote,
      invoiceFooterImageBytes: footerBytes,
    );
  }
}

class _CompanyInvoiceFormatPreview extends StatefulWidget {
  const _CompanyInvoiceFormatPreview({
    required this.a4Data,
    required this.logoBytes,
    required this.invoiceModel,
  });

  final A4InvoiceViewData a4Data;
  final Uint8List? logoBytes;
  final InvoicePrintModel invoiceModel;

  @override
  State<_CompanyInvoiceFormatPreview> createState() =>
      _CompanyInvoiceFormatPreviewState();
}

class _CompanyInvoiceFormatPreviewState
    extends State<_CompanyInvoiceFormatPreview> {
  /// 0 = A4, 1 = thermal 58mm, 2 = thermal 80mm
  int _formatIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('A4'), icon: Icon(Icons.description_outlined)),
            ButtonSegment(
              value: 1,
              label: Text('58mm'),
              icon: Icon(Icons.receipt_long_outlined),
            ),
            ButtonSegment(
              value: 2,
              label: Text('80mm'),
              icon: Icon(Icons.receipt_long_outlined),
            ),
          ],
          selected: {_formatIndex},
          onSelectionChanged: (s) {
            setState(() => _formatIndex = s.first);
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 420,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.white,
              child: _formatIndex == 0
                  ? SingleChildScrollView(
                      child: A4InvoiceRtlWidget(
                        data: widget.a4Data,
                        logoBytes: widget.logoBytes,
                      ),
                    )
                  : PdfPreview(
                      build: (_) => buildThermalInvoicePdfDocument(
                        invoice: widget.invoiceModel,
                        paperWidthMm: _formatIndex == 1 ? 58 : 80,
                      ),
                      maxPageWidth: _formatIndex == 1 ? 220 : 280,
                      allowPrinting: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
