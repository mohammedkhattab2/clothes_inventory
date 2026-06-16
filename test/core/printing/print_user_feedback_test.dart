import 'package:delta_erp/services/printing/print_batch_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PrintBatchFailure describes partial progress', () {
    final failure = PrintBatchFailure(
      completedCopies: 4,
      requestedCopies: 10,
      batchIndex: 5,
      batchCount: 10,
      cause: StateError('Print job did not reach the spooler.'),
    );

    expect(failure.toString(), contains('4'));
    expect(failure.toString(), contains('10'));
    expect(failure.toString(), contains('spooler'));
  });
}
