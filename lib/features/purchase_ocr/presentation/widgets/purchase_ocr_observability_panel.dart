import 'package:flutter/material.dart';

import 'package:clothes_inventory/features/purchase_ocr/data/purchase_ocr_service.dart';

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
              const Expanded(
                child: Text(
                  'OCR Observability',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'Refresh',
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
                title: const Text('Unresolved Issues'),
                children: _snapshot.unresolvedIssues.isEmpty
                    ? const [
                        ListTile(
                          title: Text('No unresolved fingerprints in session.'),
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
                title: const Text('Recently Resolved'),
                children: _snapshot.recentlyResolved.isEmpty
                    ? const [
                        ListTile(
                          title: Text('No resolved fingerprints in session.'),
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
                title: const Text('System Health Summary'),
                initiallyExpanded: true,
                children: [
                  ListTile(
                    title: const Text('Total failures'),
                    trailing: Text('${_snapshot.totalFailures}'),
                  ),
                  ListTile(
                    title: const Text('Total resolved'),
                    trailing: Text('${_snapshot.totalResolved}'),
                  ),
                  ListTile(
                    title: const Text('Unresolved count'),
                    trailing: Text('${_snapshot.unresolvedCount}'),
                  ),
                  ListTile(
                    title: const Text('Most frequent fingerprint'),
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
        'count: ${item.occurrenceCount} | code: ${item.lastErrorCode} | '
        'severity: ${item.severity.name} | status: ${item.resolutionStatus}',
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
              child: const Text('Mark as resolved'),
            ),
          TextButton(
            onPressed: () {
              widget.manager.resetCount(item.fingerprint);
              _refresh();
            },
            child: const Text('Reset count'),
          ),
        ],
      ),
    );
  }
}
