import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:delta_erp/features/sales/domain/sale_models.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_amend_payment_dialog.dart';

import '../../support/test_app_isolation.dart';

AmendRefundPreview _previewWith({
  double oldTotal = 500,
  double newTotal = 600,
  double delta = 100,
  double netPaid = 500,
  double outstanding = 100,
}) {
  return AmendRefundPreview(
    oldTotalAmount: oldTotal,
    returnAmountTotal: 0,
    newTotalAmount: newTotal,
    totalDelta: delta,
    netPaidAmount: netPaid,
    outstandingAfterAmend: outstanding,
    maxRefundable: 0,
    paymentMethod: PaymentMethod.cash,
    paidCash: netPaid,
    paidWallet: 0,
  );
}

double? _parseFlexibleNumber(String raw) {
  final normalized = raw
      .replaceAll('٫', '.')
      .replaceAll('٬', '')
      .replaceAll(',', '')
      .trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

Widget _appShell(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await TestAppIsolation.bootstrap();
  });

  tearDownAll(() async {
    await TestAppIsolation.shutdown();
  });

  testWidgets('defer path returns defer confirmation', (tester) async {
    AmendCollectConfirmation? result;

    await tester.pumpWidget(
      _appShell(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await SalesAmendPaymentDialog.show(
                  context,
                  preview: _previewWith(),
                  parseFlexibleNumber: _parseFlexibleNumber,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('sale.amend_collect_defer'), findsOneWidget);
    await tester.tap(find.text('sale.complete_amendment'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.handling, PositiveAmendmentHandling.defer);
    expect(result!.collectAmount, isNull);
  });

  testWidgets('collect now rejects amount above increase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _appShell(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                SalesAmendPaymentDialog.show(
                  context,
                  preview: _previewWith(delta: 100),
                  parseFlexibleNumber: _parseFlexibleNumber,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('sale.amend_collect_now'));
    await tester.tap(find.text('sale.amend_collect_now'));
    await tester.pumpAndSettle();

    final amountField = find.widgetWithText(
      TextField,
      'sale.amend_collect_amount',
    );
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '150');

    await tester.tap(find.text('sale.complete_amendment'));
    await tester.pumpAndSettle();

    expect(find.text('sale.amend_collect_amount_exceeds'), findsOneWidget);
  });

  testWidgets('split collection requires sum to match amount', (tester) async {
    AmendCollectConfirmation? result;

    await tester.pumpWidget(
      _appShell(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await SalesAmendPaymentDialog.show(
                  context,
                  preview: _previewWith(delta: 100),
                  parseFlexibleNumber: _parseFlexibleNumber,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('sale.amend_collect_now'));
    await tester.tap(find.text('sale.amend_collect_now'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payment method'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sale.amend_collect_split_label').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'sale.amend_collect_amount'),
      '100',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Cash amount'), '70');
    await tester.enterText(
      find.widgetWithText(TextField, 'Vodafone Cash amount'),
      '20',
    );

    await tester.tap(find.text('sale.complete_amendment'));
    await tester.pumpAndSettle();

    expect(find.text('sale.amend_collect_split_mismatch'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Vodafone Cash amount'),
      '30',
    );
    await tester.tap(find.text('sale.complete_amendment'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.handling, PositiveAmendmentHandling.collectNow);
    expect(result!.paymentMethod, PaymentMethod.cashAndWallet);
    expect(result!.collectAmount, 100);
    expect(result!.collectWalletAmount, 30);
  });
}
