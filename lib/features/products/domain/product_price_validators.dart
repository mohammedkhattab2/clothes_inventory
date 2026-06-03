/// Shared validation helpers for product sale (retail) prices.
class ProductPriceValidators {
  ProductPriceValidators._();

  static const double _epsilon = 0.000001;

  static bool isRetailPriceMissing(double? sale) =>
      sale == null || sale <= _epsilon;

  static bool isActivePriceBelowCost(double price, double purchase) =>
      price > _epsilon && purchase > _epsilon && price < purchase - _epsilon;

  static bool anyActiveSalePriceBelowCost({
    required double retail,
    required double purchase,
    double? halfWholesale,
    double? wholesale,
  }) {
    if (isActivePriceBelowCost(retail, purchase)) {
      return true;
    }
    if (halfWholesale != null &&
        isActivePriceBelowCost(halfWholesale, purchase)) {
      return true;
    }
    if (wholesale != null && isActivePriceBelowCost(wholesale, purchase)) {
      return true;
    }
    return false;
  }

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
    if (purchasePrice != null &&
        purchasePrice > _epsilon &&
        isActivePriceBelowCost(sale!, purchasePrice)) {
      return belowCostMessage;
    }
    return null;
  }
}
