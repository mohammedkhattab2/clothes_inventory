double roundCurrency(double value) {
  return (value * 100).roundToDouble() / 100;
}

double roundQuantity(double value) {
  return (value * 10000).roundToDouble() / 10000;
}

bool isIntegerLike(double value) {
  return value == value.roundToDouble();
}
