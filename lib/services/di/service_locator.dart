import 'package:delta_erp/app/app_startup_coordinator.dart';
import 'package:delta_erp/core/config/first_run_state_store.dart';
import 'package:get_it/get_it.dart';
import 'package:delta_erp/features/accounts/data/cash_box_repository.dart';
import 'package:delta_erp/features/accounts/data/cash_box_csv_service.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/accounts/data/account_statement_repository.dart';
import 'package:delta_erp/features/accounts/data/account_statement_csv_service.dart';
import 'package:delta_erp/features/backup/data/backup_lifecycle_service.dart';
import 'package:delta_erp/features/backup/data/backup_logger.dart';
import 'package:delta_erp/features/backup/data/backup_preferences_store.dart';
import 'package:delta_erp/features/backup/data/backup_repository_impl.dart';
import 'package:delta_erp/features/backup/domain/backup_repository.dart';
import 'package:delta_erp/features/backup/presentation/backup_cubit.dart';
import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/features/auth/data/auth_repository.dart';
import 'package:delta_erp/features/accounts/presentation/account_statement_cubit.dart';
import 'package:delta_erp/features/dashboard/data/dashboard_repository.dart';
import 'package:delta_erp/features/dashboard/data/dashboard_drilldown_export_service.dart';
import 'package:delta_erp/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:delta_erp/features/expenses/data/expenses_csv_service.dart';
import 'package:delta_erp/features/expenses/data/expenses_repository.dart';
import 'package:delta_erp/features/inventory/data/inventory_repository.dart';
import 'package:delta_erp/features/license/data/license_store.dart';
import 'package:delta_erp/features/license/domain/license_service.dart';
import 'package:delta_erp/features/license/domain/machine_fingerprint_service.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/features/products/data/products_csv_service.dart';
import 'package:delta_erp/features/products/data/products_import_service.dart';
import 'package:delta_erp/features/products/data/products_import_template_service.dart';
import 'package:delta_erp/features/products/data/products_pdf_service.dart';
import 'package:delta_erp/features/products/presentation/products_cubit.dart';
import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_service.dart';
import 'package:delta_erp/features/purchase_ocr/data/ocr_product_mappings_repository.dart';
import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_anomaly_history_provider.dart';
import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_temporal_memory_repository.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_intelligence_engine.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';
import 'package:delta_erp/features/purchase_ocr/presentation/purchase_ocr_cubit.dart';
import 'package:delta_erp/features/purchases/data/purchase_import_template_service.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/purchases/presentation/purchases_cubit.dart';
import 'package:delta_erp/features/sales/data/sales_repository.dart';
import 'package:delta_erp/features/sales/presentation/sales_cubit.dart';
import 'package:delta_erp/features/settings/data/app_reset_service.dart';
import 'package:delta_erp/core/theme/theme_cubit.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/database/db_transaction_runner.dart';
import 'package:delta_erp/services/database/maintenance_coordinator.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/export/user_export_path_picker.dart';
import 'package:delta_erp/services/platform/folder_opener_service.dart';
import 'package:delta_erp/services/pdf/account_statement_pdf_service.dart';
import 'package:delta_erp/services/pdf/cash_box_pdf_service.dart';
import 'package:delta_erp/services/pdf/dashboard_pdf_service.dart';
import 'package:delta_erp/services/pdf/expenses_pdf_service.dart';
import 'package:delta_erp/services/pdf/purchase_invoice_pdf_service.dart';
import 'package:delta_erp/features/invoices/data/sale_invoice_print_data_builder.dart';
import 'package:delta_erp/services/pdf/sales_invoice_pdf_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (!getIt.isRegistered<AppDatabase>()) {
    getIt.registerSingleton<AppDatabase>(AppDatabase.instance);
  }

  if (!getIt.isRegistered<MaintenanceCoordinator>()) {
    getIt.registerSingleton<MaintenanceCoordinator>(MaintenanceCoordinator());
  }

  if (!getIt.isRegistered<DbTransactionRunner>()) {
    getIt.registerSingleton<DbTransactionRunner>(
      DbTransactionRunner(
        getIt<AppDatabase>(),
        getIt<MaintenanceCoordinator>(),
      ),
    );
  }

  if (!getIt.isRegistered<BackupLogger>()) {
    getIt.registerLazySingleton<BackupLogger>(BackupLogger.new);
  }

  if (!getIt.isRegistered<BackupPreferencesStore>()) {
    getIt.registerLazySingleton<BackupPreferencesStore>(
      BackupPreferencesStore.new,
    );
  }

  if (!getIt.isRegistered<BackupRepository>()) {
    getIt.registerLazySingleton<BackupRepository>(
      () => BackupRepositoryImpl(
        appDatabase: getIt<AppDatabase>(),
        maintenanceCoordinator: getIt<MaintenanceCoordinator>(),
        preferencesStore: getIt<BackupPreferencesStore>(),
        logger: getIt<BackupLogger>(),
        productRepository: getIt<ProductRepository>(),
      ),
    );
  }

  if (!getIt.isRegistered<BackupLifecycleService>()) {
    getIt.registerLazySingleton<BackupLifecycleService>(
      () => BackupLifecycleService(
        repository: getIt<BackupRepository>(),
        preferencesStore: getIt<BackupPreferencesStore>(),
        logger: getIt<BackupLogger>(),
      ),
    );
  }

  if (!getIt.isRegistered<FirstRunStateStore>()) {
    getIt.registerLazySingleton<FirstRunStateStore>(FirstRunStateStore.new);
  }

  if (!getIt.isRegistered<AppStartupCoordinator>()) {
    getIt.registerLazySingleton<AppStartupCoordinator>(
      () => AppStartupCoordinator(
        firstRunStateStore: getIt<FirstRunStateStore>(),
        backupLifecycleService: getIt<BackupLifecycleService>(),
      ),
    );
  }

  if (!getIt.isRegistered<BackupCubit>()) {
    getIt.registerFactory<BackupCubit>(
      () => BackupCubit(repository: getIt<BackupRepository>()),
    );
  }

  if (!getIt.isRegistered<ThemeCubit>()) {
    getIt.registerLazySingleton<ThemeCubit>(ThemeCubit.new);
  }

  if (!getIt.isRegistered<MachineFingerprintService>()) {
    getIt.registerLazySingleton<MachineFingerprintService>(
      MachineFingerprintService.new,
    );
  }

  if (!getIt.isRegistered<LicenseStore>()) {
    getIt.registerLazySingleton<LicenseStore>(LicenseStore.new);
  }

  if (!getIt.isRegistered<LicenseService>()) {
    getIt.registerLazySingleton<LicenseService>(
      () => LicenseService(
        getIt<LicenseStore>(),
        getIt<MachineFingerprintService>(),
      ),
    );
  }

  if (!getIt.isRegistered<CompanySettingsService>()) {
    getIt.registerLazySingleton<CompanySettingsService>(
      () => CompanySettingsService(
        getIt<AppDatabase>(),
        getIt<MaintenanceCoordinator>(),
      ),
    );
    await getIt<CompanySettingsService>().initialize();
  }

  if (!getIt.isRegistered<AppResetService>()) {
    getIt.registerLazySingleton<AppResetService>(
      () => AppResetService(
        appDatabase: getIt<AppDatabase>(),
        maintenanceCoordinator: getIt<MaintenanceCoordinator>(),
      ),
    );
  }

  if (!getIt.isRegistered<SessionService>()) {
    getIt.registerSingleton<SessionService>(SessionService());
  }

  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepository(getIt<AppDatabase>()),
    );
    await getIt<AuthRepository>().ensureOwnerSeeded();
  }

  if (!getIt.isRegistered<ProductRepository>()) {
    getIt.registerLazySingleton<ProductRepository>(
      () => ProductRepository(
        getIt<AppDatabase>(),
        getIt<MaintenanceCoordinator>(),
      ),
    );
  }

  if (!getIt.isRegistered<ProductsCubit>()) {
    getIt.registerFactory<ProductsCubit>(
      () => ProductsCubit(getIt<ProductRepository>()),
    );
  }

  if (!getIt.isRegistered<ProductsCsvService>()) {
    getIt.registerLazySingleton<ProductsCsvService>(ProductsCsvService.new);
  }

  if (!getIt.isRegistered<ProductsPdfService>()) {
    getIt.registerLazySingleton<ProductsPdfService>(ProductsPdfService.new);
  }

  if (!getIt.isRegistered<ProductsImportService>()) {
    getIt.registerLazySingleton<ProductsImportService>(
      ProductsImportService.new,
    );
  }

  if (!getIt.isRegistered<ProductsImportTemplateService>()) {
    getIt.registerLazySingleton<ProductsImportTemplateService>(
      ProductsImportTemplateService.new,
    );
  }

  if (!getIt.isRegistered<PurchaseImportTemplateService>()) {
    getIt.registerLazySingleton<PurchaseImportTemplateService>(
      PurchaseImportTemplateService.new,
    );
  }

  if (!getIt.isRegistered<InventoryRepository>()) {
    getIt.registerLazySingleton<InventoryRepository>(
      () => InventoryRepository(getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<AccountsRepository>()) {
    getIt.registerLazySingleton<AccountsRepository>(
      () => AccountsRepository(
        getIt<AppDatabase>(),
        getIt<DbTransactionRunner>(),
        getIt<SessionService>(),
      ),
    );
  }

  if (!getIt.isRegistered<CashBoxRepository>()) {
    getIt.registerLazySingleton<CashBoxRepository>(
      () => CashBoxRepository(getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<ExpensesRepository>()) {
    getIt.registerLazySingleton<ExpensesRepository>(
      () => ExpensesRepository(
        getIt<AppDatabase>(),
        getIt<DbTransactionRunner>(),
      ),
    );
  }

  if (!getIt.isRegistered<ExpensesCsvService>()) {
    getIt.registerLazySingleton<ExpensesCsvService>(ExpensesCsvService.new);
  }

  if (!getIt.isRegistered<ExpensesPdfService>()) {
    getIt.registerLazySingleton<ExpensesPdfService>(
      () => ExpensesPdfService(getIt<CompanySettingsService>()),
    );
  }

  if (!getIt.isRegistered<CashBoxCsvService>()) {
    getIt.registerLazySingleton<CashBoxCsvService>(CashBoxCsvService.new);
  }

  if (!getIt.isRegistered<SalesRepository>()) {
    getIt.registerLazySingleton<SalesRepository>(
      () => SalesRepository(
        getIt<AppDatabase>(),
        getIt<DbTransactionRunner>(),
        getIt<SessionService>(),
      ),
    );
  }

  if (!getIt.isRegistered<SalesCubit>()) {
    getIt.registerFactory<SalesCubit>(
      () => SalesCubit(getIt<SalesRepository>()),
    );
  }

  if (!getIt.isRegistered<PurchasesRepository>()) {
    getIt.registerLazySingleton<PurchasesRepository>(
      () => PurchasesRepository(
        getIt<AppDatabase>(),
        getIt<DbTransactionRunner>(),
        getIt<SessionService>(),
      ),
    );
  }

  if (!getIt.isRegistered<PurchasesCubit>()) {
    getIt.registerFactory<PurchasesCubit>(
      () => PurchasesCubit(getIt<PurchasesRepository>()),
    );
  }

  if (!getIt.isRegistered<PurchaseInvoiceParser>()) {
    getIt.registerLazySingleton<PurchaseInvoiceParser>(
      PurchaseInvoiceParser.new,
    );
  }

  if (!getIt.isRegistered<OcrProductMappingsStore>()) {
    getIt.registerLazySingleton<OcrProductMappingsStore>(
      () => OcrProductMappingsRepository(getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrProductMatcher>()) {
    getIt.registerLazySingleton<PurchaseOcrProductMatcher>(
      () => PurchaseOcrProductMatcher(
        mappingsStore: getIt<OcrProductMappingsStore>(),
      ),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrAnomalyHistoryProvider>()) {
    getIt.registerLazySingleton<PurchaseOcrAnomalyHistoryProvider>(
      () => PurchasesOcrAnomalyHistoryProvider(getIt<PurchasesRepository>()),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrAnomalyDetector>()) {
    getIt.registerLazySingleton<PurchaseOcrAnomalyDetector>(
      () => PurchaseOcrAnomalyDetector(
        historyProvider: getIt<PurchaseOcrAnomalyHistoryProvider>(),
      ),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrTemporalMemoryStore>()) {
    getIt.registerLazySingleton<PurchaseOcrTemporalMemoryStore>(
      () => PurchaseOcrTemporalMemoryRepository(getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrTemporalIntelligenceLayer>()) {
    getIt.registerLazySingleton<PurchaseOcrTemporalIntelligenceLayer>(
      () => PurchaseOcrTemporalIntelligenceLayer(
        memoryStore: getIt<PurchaseOcrTemporalMemoryStore>(),
      ),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrIntelligenceEngine>()) {
    getIt.registerLazySingleton<PurchaseOcrIntelligenceEngine>(
      () => PurchaseOcrIntelligenceEngine(
        parser: getIt<PurchaseInvoiceParser>(),
        matcher: getIt<PurchaseOcrProductMatcher>(),
        anomalyDetector: getIt<PurchaseOcrAnomalyDetector>(),
        temporalLayer: getIt<PurchaseOcrTemporalIntelligenceLayer>(),
      ),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrService>()) {
    getIt.registerLazySingleton<PurchaseOcrService>(
      () => OfflinePurchaseOcrService(),
    );
  }

  if (!getIt.isRegistered<PurchaseOcrCubit>()) {
    getIt.registerFactory<PurchaseOcrCubit>(
      () => PurchaseOcrCubit(
        ocrService: getIt<PurchaseOcrService>(),
        parser: getIt<PurchaseInvoiceParser>(),
        matcher: getIt<PurchaseOcrProductMatcher>(),
        anomalyDetector: getIt<PurchaseOcrAnomalyDetector>(),
        intelligenceEngine: getIt<PurchaseOcrIntelligenceEngine>(),
        temporalLayer: getIt<PurchaseOcrTemporalIntelligenceLayer>(),
        accountsRepository: getIt<AccountsRepository>(),
        productRepository: getIt<ProductRepository>(),
        purchasesRepository: getIt<PurchasesRepository>(),
      ),
    );
  }

  if (!getIt.isRegistered<SaleInvoicePrintDataBuilder>()) {
    getIt.registerLazySingleton<SaleInvoicePrintDataBuilder>(
      () => SaleInvoicePrintDataBuilder(
        getIt<AppDatabase>(),
        getIt<CompanySettingsService>(),
      ),
    );
  }

  if (!getIt.isRegistered<SalesInvoicePdfService>()) {
    getIt.registerLazySingleton<SalesInvoicePdfService>(
      () => SalesInvoicePdfService(getIt<SaleInvoicePrintDataBuilder>()),
    );
  }

  if (!getIt.isRegistered<PurchaseInvoicePdfService>()) {
    getIt.registerLazySingleton<PurchaseInvoicePdfService>(
      () => PurchaseInvoicePdfService(
        getIt<AppDatabase>(),
        getIt<CompanySettingsService>(),
      ),
    );
  }

  if (!getIt.isRegistered<AccountStatementRepository>()) {
    getIt.registerLazySingleton<AccountStatementRepository>(
      () => AccountStatementRepository(getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<AccountStatementCubit>()) {
    getIt.registerFactory<AccountStatementCubit>(
      () => AccountStatementCubit(getIt<AccountStatementRepository>()),
    );
  }

  if (!getIt.isRegistered<AccountStatementPdfService>()) {
    getIt.registerLazySingleton<AccountStatementPdfService>(
      AccountStatementPdfService.new,
    );
  }

  if (!getIt.isRegistered<CashBoxPdfService>()) {
    getIt.registerLazySingleton<CashBoxPdfService>(
      () => CashBoxPdfService(getIt<CompanySettingsService>()),
    );
  }

  if (!getIt.isRegistered<AccountStatementCsvService>()) {
    getIt.registerLazySingleton<AccountStatementCsvService>(
      AccountStatementCsvService.new,
    );
  }

  if (!getIt.isRegistered<UserExportPathPicker>()) {
    getIt.registerLazySingleton<UserExportPathPicker>(
      () => const UserExportPathPicker(),
    );
  }

  if (!getIt.isRegistered<FolderOpenerService>()) {
    getIt.registerLazySingleton<FolderOpenerService>(FolderOpenerService.new);
  }

  if (!getIt.isRegistered<DashboardRepository>()) {
    getIt.registerLazySingleton<DashboardRepository>(
      () => DashboardRepository(getIt<AppDatabase>(), getIt<SessionService>()),
    );
  }

  if (!getIt.isRegistered<DashboardPdfService>()) {
    getIt.registerLazySingleton<DashboardPdfService>(DashboardPdfService.new);
  }

  if (!getIt.isRegistered<DashboardDrillDownExportService>()) {
    getIt.registerLazySingleton<DashboardDrillDownExportService>(
      DashboardDrillDownExportService.new,
    );
  }

  if (!getIt.isRegistered<DashboardCubit>()) {
    getIt.registerFactory<DashboardCubit>(
      () => DashboardCubit(
        getIt<DashboardRepository>(),
        getIt<DashboardPdfService>(),
      ),
    );
  }
}
