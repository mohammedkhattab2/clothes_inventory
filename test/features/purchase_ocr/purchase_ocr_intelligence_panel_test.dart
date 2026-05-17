import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';
import 'package:delta_erp/features/purchase_ocr/presentation/widgets/purchase_ocr_intelligence_panel.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('empty intelligence case still renders panel shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PurchaseOcrIntelligencePanel(
          temporalInsights: <PurchaseOcrTemporalInsight>[],
          trendAnomalies: <PurchaseOcrTrendAnomaly>[],
          behavioralSignals: <PurchaseOcrBehavioralSignal>[],
          learnedMappingsAppliedCount: 0,
          actionableRecommendations: <PurchaseOcrActionableRecommendation>[],
          riskScore: 0,
        ),
      ),
    );

    expect(find.text('ocr.intelligence.title'), findsOneWidget);
  });

  testWidgets('supplier with stable history', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PurchaseOcrIntelligencePanel(
          temporalInsights: <PurchaseOcrTemporalInsight>[
            PurchaseOcrTemporalInsight(
              key: 'supplier_stability',
              message: 'Supplier stability score: 0.92 across 12 invoices.',
            ),
          ],
          trendAnomalies: <PurchaseOcrTrendAnomaly>[],
          behavioralSignals: <PurchaseOcrBehavioralSignal>[],
          learnedMappingsAppliedCount: 1,
          actionableRecommendations: <PurchaseOcrActionableRecommendation>[
            PurchaseOcrActionableRecommendation(
              type: PurchaseOcrRecommendationType.supplier,
              message:
                  'Supplier behavior looks unstable compared to past invoices.',
              severity: OcrAnomalySeverity.medium,
              suggestedAction:
                  'Review this supplier invoice history and consider comparing with alternative suppliers.',
            ),
          ],
          riskScore: 0.18,
        ),
      ),
    );

    expect(find.text('ocr.intelligence.title'), findsOneWidget);
    await tester.tap(find.text('ocr.intelligence.title'));
    await tester.pumpAndSettle();

    expect(find.text('ocr.intelligence.supplier_insights'), findsOneWidget);
    expect(find.text('ocr.intelligence.stable'), findsWidgets);
    expect(find.text('ocr.intelligence.recommended_actions'), findsOneWidget);
  });

  testWidgets('high anomaly and drift case', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PurchaseOcrIntelligencePanel(
          temporalInsights: <PurchaseOcrTemporalInsight>[
            PurchaseOcrTemporalInsight(
              key: 'supplier_stability',
              message: 'Supplier stability score: 0.33 across 4 invoices.',
            ),
          ],
          trendAnomalies: <PurchaseOcrTrendAnomaly>[
            PurchaseOcrTrendAnomaly(
              severity: OcrAnomalySeverity.high,
              message: 'Price trend anomaly: detected upward drift at 48%.',
            ),
          ],
          behavioralSignals: <PurchaseOcrBehavioralSignal>[
            PurchaseOcrBehavioralSignal(
              signal: 'user_correction_preference',
              message: 'Applied frequent correction preference.',
              strength: 0.9,
            ),
          ],
          learnedMappingsAppliedCount: 2,
          actionableRecommendations: <PurchaseOcrActionableRecommendation>[
            PurchaseOcrActionableRecommendation(
              type: PurchaseOcrRecommendationType.product,
              message: 'Unusual product pricing detected in this invoice.',
              severity: OcrAnomalySeverity.high,
              suggestedAction:
                  'Check recent invoices for this product and verify whether the price change is intentional.',
            ),
          ],
          riskScore: 0.82,
        ),
      ),
    );

    await tester.tap(find.text('ocr.intelligence.title'));
    await tester.pumpAndSettle();

    expect(find.text('ocr.intelligence.volatile'), findsOneWidget);
    expect(find.text('ocr.intelligence.up'), findsOneWidget);
    expect(find.textContaining('upward drift'), findsOneWidget);
    expect(find.text('ocr.intelligence.high'), findsOneWidget);
    expect(
      find.text('ocr.intelligence.msg.unusual_product_pricing'),
      findsOneWidget,
    );
  });
}
