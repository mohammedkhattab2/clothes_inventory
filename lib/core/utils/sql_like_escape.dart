/// Escapes `%`, `_`, and `\` for use in a SQLite `LIKE` pattern with
/// `ESCAPE '\\'`. The caller should append `%` / `_` as needed.
String escapeSqlLikeLiteral(String input) {
  final b = StringBuffer();
  for (final c in input.runes) {
    final ch = String.fromCharCode(c);
    if (ch == r'\' || ch == '%' || ch == '_') {
      b.write(r'\');
    }
    b.write(ch);
  }
  return b.toString();
}
