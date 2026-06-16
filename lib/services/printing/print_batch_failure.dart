/// Thrown when a multi-job print run stops before all copies/strips finish.
class PrintBatchFailure implements Exception {
  PrintBatchFailure({
    required this.completedCopies,
    required this.requestedCopies,
    required this.batchIndex,
    required this.batchCount,
    required this.cause,
  });

  final int completedCopies;
  final int requestedCopies;
  final int batchIndex;
  final int batchCount;
  final Object cause;

  @override
  String toString() {
    if (completedCopies <= 0) {
      return cause.toString();
    }
    return 'Printed $completedCopies of $requestedCopies before batch '
        '$batchIndex/$batchCount failed: $cause';
  }
}
