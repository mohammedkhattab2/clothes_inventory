/// Thrown when insert/update would violate the unique [products.barcode] constraint.
class DuplicateProductBarcodeException implements Exception {
  const DuplicateProductBarcodeException();
}
