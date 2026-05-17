import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_service.dart';

class PurchaseOcrObservabilityPanel extends StatefulWidget {
  const PurchaseOcrObservabilityPanel({required this.manager, super.key});

  final PurchaseOcrObservabilityManager manager;

  @override
  State<PurchaseOcrObservabilityPanel> createState() =>
      _PurchaseOcrObservabilityPanelState();
}

class _PurchaseOcrObservabilityPanelState
    extends State<PurchaseOcrObservabilityPanel> {
  late PurchaseOcrObservabilitySnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.manager.buildSnapshot();
  }

  void _refresh() {
    setState(() {
      _snapshot = widget.manager.buildSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ocr.observability.title'.tr(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'Refresh'.tr(),
                icon: const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text('ocr.observability.unresolved_issues'.tr()),
                children: _snapshot.unresolvedIssues.isEmpty
                    ? [
                        ListTile(
                          title: Text(
                            'ocr.observability.no_unresolved'.tr(),
                          ),
                        ),
                      ]
                    : _snapshot.unresolvedIssues
                          .map(
                            (item) => _buildItemTile(item, allowResolve: true),
                          )
                          .toList(growable: false),
              ),
              ExpansionTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.amber,
                ),
                title: Text('ocr.observability.recently_resolved'.tr()),
                children: _snapshot.recentlyResolved.isEmpty
                    ? [
                        ListTile(
                          title: Text(
                            'ocr.observability.no_resolved'.tr(),
                          ),
                        ),
                      ]
                    : _snapshot.recentlyResolved
                          .map(
                            (item) => _buildItemTile(item, allowResolve: false),
                          )
                          .toList(growable: false),
              ),
              ExpansionTile(
                leading: const Icon(
                  Icons.health_and_safety_outlined,
                  color: Colors.green,
                ),
                title: Text('ocr.observability.system_health_summary'.tr()),
                initiallyExpanded: true,
                children: [
                  ListTile(
                    title: Text('ocr.observability.total_failures'.tr()),
                    trailing: Text('${_snapshot.totalFailures}'),
                  ),
                  ListTile(
                    title: Text('ocr.observability.total_resolved'.tr()),
                    trailing: Text('${_snapshot.totalResolved}'),
                  ),
                  ListTile(
                    title: Text('ocr.observability.unresolved_count'.tr()),
                    trailing: Text('${_snapshot.unresolvedCount}'),
                  ),
                  ListTile(
                    title: Text('ocr.observability.most_frequent'.tr()),
                    subtitle: Text(_snapshot.mostFrequentFingerprint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(
    OcrFingerprintHealthItem item, {
    required bool allowResolve,
  }) {
    return ListTile(
      dense: true,
      title: Text(
        item.fingerprint,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      subtitle: Text(
        '${'ocr.observability.count'.tr()}: ${item.occurrenceCount} | '
        '${'ocr.observability.code'.tr()}: ${item.lastErrorCode} | '
        '${'ocr.observability.severity'.tr()}: ${item.severity.name} | '
        '${'ocr.observability.status'.tr()}: ${item.resolutionStatus}',
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          if (allowResolve)
            TextButton(
              onPressed: () {
                widget.manager.markResolved(item.fingerprint);
                _refresh();
              },
              child: Text('ocr.observability.mark_resolved'.tr()),
            ),
          TextButton(
            onPressed: () {
              widget.manager.resetCount(item.fingerprint);
              _refresh();
            },
            child: Text('ocr.observability.reset_count'.tr()),
          ),
        ],
      ),
    );
  }
}
