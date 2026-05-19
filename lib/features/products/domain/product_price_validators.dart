/// Shared validation helpers for product sale (retail) prices.
class ProductPriceValidators {
  ProductPriceValidators._();

  static bool isRetailPriceMissing(double? sale) =>
      sale == null || sale <= 0.000001;

  static String? retailPriceValidator(
    String? value,
    double? Function(String raw) parse, {
    String requiredMessage = 'products.retail_price_required',
    double? purchasePrice,
    String? belowCostMessage,
  }) {
    final sale = parse(value ?? '');
    if (isRetailPriceMissing(sale)) {
      return requiredMessage;
    }
    if (purchasePrice != null && sale! < purchasePrice) {
      return belowCostMessage;
    }
    return null;
  }
}
