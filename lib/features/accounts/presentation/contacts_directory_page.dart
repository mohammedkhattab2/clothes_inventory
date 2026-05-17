import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/accounts/data/contacts_directory_csv_service.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/export/user_export_path_picker.dart';
import 'package:delta_erp/services/pdf/contacts_directory_pdf_service.dart';

/// Customers and suppliers with phone numbers; tap opens account statement.
class ContactsDirectoryPage extends StatefulWidget {
  const ContactsDirectoryPage({super.key});

  @override
  State<ContactsDirectoryPage> createState() => _ContactsDirectoryPageState();
}

class _ContactsDirectoryPageState extends State<ContactsDirectoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _accountsRepo = getIt<AccountsRepository>();

  List<AccountLookup> _customers = const [];
  List<AccountLookup> _suppliers = const [];
  bool _loading = true;
  String? _error;
  bool _exportingPdf = false;
  bool _exportingCsv = false;

  static const _csvService = ContactsDirectoryCsvService();
  static const _pdfService = ContactsDirectoryPdfService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customers = await _accountsRepo.listByType('customer');
      final suppliers = await _accountsRepo.listByType('supplier');
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _suppliers = suppliers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<AccountLookup> _activeListForExport() {
    return _tabController.index == 0 ? _customers : _suppliers;
  }

  String _exportFileNamePrefix() {
    return _tabController.index == 0 ? 'customers' : 'suppliers';
  }

  String _exportListTitle() {
    return _tabController.index == 0
        ? 'contacts.export_title_customers'.tr()
        : 'contacts.export_title_suppliers'.tr();
  }

  Future<void> _exportPdf() async {
    final list = _activeListForExport();
    if (_exportingPdf || list.isEmpty) {
      if (mounted && list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contacts.export_empty'.tr())),
        );
      }
      return;
    }

    final targetPath = await getIt<UserExportPathPicker>().pickSavePath(
      dialogTitle: 'export.save_dialog_title'.tr(),
      suggestedFileName:
          'contacts_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      extensions: const ['pdf'],
    );
    if (targetPath == null) return;

    setState(() => _exportingPdf = true);
    try {
      final path = await _pdfService.exportToPdf(
        accounts: list,
        title: _exportListTitle(),
        targetPath: targetPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'PDF exported'.tr()}: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'PDF export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportCsv() async {
    final list = _activeListForExport();
    if (_exportingCsv || list.isEmpty) {
      if (mounted && list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contacts.export_empty'.tr())),
        );
      }
      return;
    }

    final prefix = _exportFileNamePrefix();
    final targetPath = await getIt<UserExportPathPicker>().pickSavePath(
      dialogTitle: 'export.save_dialog_title'.tr(),
      suggestedFileName:
          '${prefix}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      extensions: const ['csv'],
    );
    if (targetPath == null) return;

    setState(() => _exportingCsv = true);
    try {
      final path = await _csvService.exportToCsv(
        accounts: list,
        fileNamePrefix: prefix,
        targetPath: targetPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'CSV exported'.tr()}: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'CSV export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('contacts.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'contacts.customers_tab'.tr()),
            Tab(text: 'contacts.suppliers_tab'.tr()),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'contacts.export_excel'.tr(),
            onPressed:
                _loading || _exportingCsv || _exportingPdf ? null : _exportCsv,
            icon: _exportingCsv
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            tooltip: 'contacts.export_pdf'.tr(),
            onPressed:
                _loading || _exportingPdf || _exportingCsv ? null : _exportPdf,
            icon: _exportingPdf
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Refresh'.tr(),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _AccountList(accounts: _customers),
                _AccountList(accounts: _suppliers),
              ],
            ),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.accounts});

  final List<AccountLookup> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Center(child: Text('contacts.empty'.tr()));
    }
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: accounts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = accounts[index];
        final phone = (a.phone ?? '').trim();
        final phoneDisplay = phone.isEmpty ? '—' : phone;
        return Material(
          color: colorScheme.surfaceContainerHighest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/accounts/statement/${a.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phoneDisplay,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
