import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

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
