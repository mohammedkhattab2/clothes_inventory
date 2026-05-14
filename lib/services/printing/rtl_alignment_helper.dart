String alignRight(String text, int lineWidth) {
  final fitted = _fit(text, lineWidth);
  return '${' ' * (lineWidth - fitted.length)}$fitted';
}

String alignCenter(String text, int lineWidth) {
  final fitted = _fit(text, lineWidth);
  final leftPad = (lineWidth - fitted.length) ~/ 2;
  final rightPad = lineWidth - fitted.length - leftPad;
  return '${' ' * leftPad}$fitted${' ' * rightPad}';
}

String alignLeft(String text, int lineWidth) {
  final fitted = _fit(text, lineWidth);
  return '$fitted${' ' * (lineWidth - fitted.length)}';
}

String _fit(String input, int lineWidth) {
  final normalized = input.trim();
  if (lineWidth <= 0) {
    return '';
  }
  if (normalized.length <= lineWidth) {
    return normalized;
  }
  if (lineWidth <= 1) {
    return normalized.substring(0, 1);
  }
  return '${normalized.substring(0, lineWidth - 1)}…';
}
