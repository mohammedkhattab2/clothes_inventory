/// SQL fragment for per-invoice added monetary value from amendment lines.
const String salesInvoiceAddedAmountSql = '''
COALESCE(
  NULLIF(s.added_total, 0),
  NULLIF((
    SELECT COALESCE(SUM(si.line_total), 0)
    FROM sale_items si
    WHERE si.sale_id = s.id
      AND si.added_after_amendment = 1
  ), 0),
  0
)
''';
