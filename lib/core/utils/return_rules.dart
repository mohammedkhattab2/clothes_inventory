import 'package:delta_erp/core/utils/number_utils.dart';

class ReturnValidationResult {
  const ReturnValidationResult({
    required this.isValid,
    required this.remainingQuantity,
    this.error,
  });

  final bool isValid;
  final double remainingQuantity;
  final String? error;
}

class ReturnRules {
  const ReturnRules._();

  static ReturnValidationResult validate({
    required double originalQuantity,
    required double alreadyReturned,
    required double requestedQuantity,
    required String unitType,
  }) {
    if (requestedQuantity <= 0) {
      return const ReturnValidationResult(
        isValid: false,
        remainingQuantity: 0,
        error: 'Return quantity must be greater than zero.',
      );
    }

    if (unitType == 'piece' && !isIntegerLike(requestedQuantity)) {
      return const ReturnValidationResult(
        isValid: false,
        remainingQuantity: 0,
        error: 'Piece products require integer quantity.',
      );
    }

    final remaining = roundQuantity(originalQuantity - alreadyReturned);
    if (requestedQuantity > remaining) {
      return ReturnValidationResult(
        isValid: false,
        remainingQuantity: remaining,
        error: 'Return quantity exceeds remaining quantity.',
      );
    }

    return ReturnValidationResult(isValid: true, remainingQuantity: remaining);
  }
}
