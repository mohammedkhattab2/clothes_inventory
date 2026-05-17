import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';

class PurchaseOcrIntelligencePanel extends StatelessWidget {
  const PurchaseOcrIntelligencePanel({
    required this.temporalInsights,
    required this.trendAnomalies,
    required this.behavioralSignals,
    required this.learnedMappingsAppliedCount,
    required this.actionableRecommendations,
    required this.riskScore,
    super.key,
  });

  final List<PurchaseOcrTemporalInsight> temporalInsights;
  final List<PurchaseOcrTrendAnomaly> trendAnomalies;
  final List<PurchaseOcrBehavioralSignal> behavioralSignals;
  final int learnedMappingsAppliedCount;
  final List<PurchaseOcrActionableRecommendation> actionableRecommendations;
  final double riskScore;

  @override
  Widget build(BuildContext context) {
    final stabilityScore = _extractSupplierStabilityScore(temporalInsights);
    final supplierTrend = _supplierTrendLabel(stabilityScore, trendAnomalies);
    final productTrend = _productTrendLabel(trendAnomalies);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text('ocr.intelligence.title'.tr()),
        subtitle: Text(
          '${'ocr.intelligence.risk_score'.tr()}: ${(riskScore * 100).toStringAsFixed(0)}%',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _sectionTitle(context, 'ocr.intelligence.supplier_insights'.tr()),
          const SizedBox(height: 8),
          _statusRow(
            context,
            label: 'ocr.intelligence.stability_score'.tr(),
            value: stabilityScore == null
                ? 'ocr.intelligence.no_history_yet'.tr()
                : '${stabilityScore.toStringAsFixed(0)} / 100',
            tone: stabilityScore == null
                ? _PanelTone.warning
                : _stabilityTone(stabilityScore),
          ),
          _statusRow(
            context,
            label: 'ocr.intelligence.behavior_trend'.tr(),
            value: _translateTrendLabel(supplierTrend),
            tone: _supplierTrendTone(supplierTrend),
          ),
          const SizedBox(height: 12),
          _sectionTitle(context, 'ocr.intelligence.product_insights'.tr()),
          const SizedBox(height: 8),
          _statusRow(
            context,
            label: 'ocr.intelligence.price_trend'.tr(),
            value: _translateTrendLabel(productTrend),
            tone: _productTrendTone(productTrend),
          ),
          if (trendAnomalies.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...trendAnomalies
                .take(2)
                .map(
                  (anomaly) => _bulletMessage(
                    context,
                    _translateInsightMessage(anomaly.message),
                    _anomalyTone(anomaly.severity.name),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          _sectionTitle(context, 'ocr.intelligence.system_signals'.tr()),
          const SizedBox(height: 8),
          _statusRow(
            context,
            label: 'ocr.intelligence.user_correction_frequency'.tr(),
            value: _translateLevel(_userCorrectionSummary(behavioralSignals)),
            tone: behavioralSignals.isEmpty
                ? _PanelTone.safe
                : _PanelTone.warning,
          ),
          _statusRow(
            context,
            label: 'ocr.intelligence.auto_learned_adjustments'.tr(),
            value:
                '$learnedMappingsAppliedCount ${'ocr.intelligence.applied'.tr()}',
            tone: learnedMappingsAppliedCount > 0
                ? _PanelTone.safe
                : _PanelTone.warning,
          ),
          if (actionableRecommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle(context, 'ocr.intelligence.recommended_actions'.tr()),
            const SizedBox(height: 8),
            ...actionableRecommendations.map(
              (recommendation) => _recommendationCard(context, recommendation),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recommendationCard(
    BuildContext context,
    PurchaseOcrActionableRecommendation recommendation,
  ) {
    final tone = _anomalyTone(recommendation.severity.name);
    final color = _toneColor(context, tone);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_recommendationIcon(recommendation.type), color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translateInsightMessage(recommendation.message),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _translateInsightMessage(recommendation.suggestedAction),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _statusRow(
    BuildContext context, {
    required String label,
    required String value,
    required _PanelTone tone,
  }) {
    final color = _toneColor(context, tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletMessage(BuildContext context, String message, _PanelTone tone) {
    final color = _toneColor(context, tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Icon(Icons.circle, size: 8, color: color),
          ),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  double? _extractSupplierStabilityScore(
    List<PurchaseOcrTemporalInsight> insights,
  ) {
    final candidate = insights.where((i) => i.key == 'supplier_stability');
    if (candidate.isEmpty) return null;
    final text = candidate.first.message;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(text);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1)!);
    if (parsed == null) return null;
    final scaled = (parsed * 100).clamp(0, 100).toDouble();
    return scaled;
  }

  String _supplierTrendLabel(
    double? stabilityScore,
    List<PurchaseOcrTrendAnomaly> anomalies,
  ) {
    if (stabilityScore == null) return 'New supplier warning';
    if (anomalies.any((a) => a.message.toLowerCase().contains('supplier'))) {
      return 'Volatile';
    }
    if (stabilityScore >= 70) return 'Stable';
    if (stabilityScore >= 45) return 'Caution';
    return 'Volatile';
  }

  String _translateTrendLabel(String value) {
    switch (value) {
      case 'New supplier warning':
        return 'ocr.intelligence.new_supplier_warning'.tr();
      case 'Volatile':
        return 'ocr.intelligence.volatile'.tr();
      case 'Stable':
        return 'ocr.intelligence.stable'.tr();
      case 'Caution':
        return 'ocr.intelligence.caution'.tr();
      case 'Up':
        return 'ocr.intelligence.up'.tr();
      case 'Down':
        return 'ocr.intelligence.down'.tr();
      case 'Warning':
        return 'ocr.intelligence.warning'.tr();
      default:
        return value;
    }
  }

  String _translateLevel(String value) {
    switch (value) {
      case 'High':
        return 'ocr.intelligence.high'.tr();
      case 'Medium':
        return 'ocr.intelligence.medium'.tr();
      case 'Low':
        return 'ocr.intelligence.low'.tr();
      default:
        return value;
    }
  }

  String _translateInsightMessage(String message) {
    switch (message) {
      case 'Supplier shows unstable pricing behavior over time.':
        return 'ocr.intelligence.msg.supplier_unstable_pricing'.tr();
      case 'The system observed repeated manual adjustments.':
        return 'ocr.intelligence.msg.system_repeated_adjustments'.tr();
      case 'Improve automation using barcode linking, better aliases, or faster autofill shortcuts.':
        return 'ocr.intelligence.msg.improve_automation'.tr();
      case 'Unusual product pricing detected in this invoice.':
        return 'ocr.intelligence.msg.unusual_product_pricing'.tr();
      case 'Check recent invoices for this product and verify whether the price change is intentional.':
        return 'ocr.intelligence.msg.check_recent_invoices'.tr();
      case 'Supplier behavior looks unstable compared to past invoices.':
        return 'ocr.intelligence.msg.supplier_behavior_unstable'.tr();
      case 'Review this supplier invoice history and consider comparing with alternative suppliers.':
        return 'ocr.intelligence.msg.review_supplier_history'.tr();
      default:
        return message;
    }
  }

  String _productTrendLabel(List<PurchaseOcrTrendAnomaly> anomalies) {
    if (anomalies.isEmpty) return 'Stable';
    final joined = anomalies.map((a) => a.message.toLowerCase()).join(' ');
    if (joined.contains('upward') || joined.contains('drift')) return 'Up';
    if (joined.contains('down')) return 'Down';
    return 'Warning';
  }

  String _userCorrectionSummary(List<PurchaseOcrBehavioralSignal> signals) {
    final correctionSignals = signals.where(
      (s) => s.signal == 'user_correction_preference',
    );
    if (correctionSignals.isEmpty) {
      return 'Low';
    }

    final avg =
        correctionSignals.map((e) => e.strength).reduce((a, b) => a + b) /
        correctionSignals.length;

    if (avg >= 0.7) return 'High';
    if (avg >= 0.35) return 'Medium';
    return 'Low';
  }

  _PanelTone _stabilityTone(double value) {
    if (value >= 70) return _PanelTone.safe;
    if (value >= 45) return _PanelTone.warning;
    return _PanelTone.risk;
  }

  _PanelTone _supplierTrendTone(String trend) {
    switch (trend) {
      case 'Stable':
        return _PanelTone.safe;
      case 'Caution':
      case 'New supplier warning':
        return _PanelTone.warning;
      default:
        return _PanelTone.risk;
    }
  }

  _PanelTone _productTrendTone(String trend) {
    switch (trend) {
      case 'Stable':
        return _PanelTone.safe;
      case 'Up':
      case 'Down':
      case 'Warning':
        return _PanelTone.warning;
      default:
        return _PanelTone.risk;
    }
  }

  _PanelTone _anomalyTone(String severity) {
    if (severity == 'high') return _PanelTone.risk;
    if (severity == 'medium') return _PanelTone.warning;
    return _PanelTone.safe;
  }

  Color _toneColor(BuildContext context, _PanelTone tone) {
    switch (tone) {
      case _PanelTone.safe:
        return Colors.green.shade700;
      case _PanelTone.warning:
        return Colors.amber.shade800;
      case _PanelTone.risk:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData _recommendationIcon(PurchaseOcrRecommendationType type) {
    switch (type) {
      case PurchaseOcrRecommendationType.supplier:
        return Icons.storefront_outlined;
      case PurchaseOcrRecommendationType.product:
        return Icons.price_check_outlined;
      case PurchaseOcrRecommendationType.system:
        return Icons.auto_fix_high_outlined;
    }
  }
}

enum _PanelTone { safe, warning, risk }
