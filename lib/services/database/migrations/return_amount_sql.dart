/// SQL fragment for per-invoice returned monetary value on sales drilldown.
const String salesInvoiceReturnedAmountSql = '''
COALESCE(
  NULLIF(s.returned_total, 0),
  NULLIF((
    SELECT COALESCE(SUM(ret.amount), 0)
    FROM returns ret
    WHERE ret.invoice_type = 'sale' AND ret.invoice_id = s.id
  ), 0),
  NULLIF((
    SELECT COALESCE(SUM(lt.amount), 0)
    FROM returns ret
    INNER JOIN ledger_transactions lt
      ON lt.source_type = 'return' AND lt.source_id = ret.id
    WHERE ret.invoice_type = 'sale'
      AND ret.invoice_id = s.id
      AND lt.reversal_for_id IS NULL
  ), 0),
  NULLIF((
    SELECT COALESCE(ABS(SUM(pp.amount)), 0)
    FROM payments pp
    WHERE pp.invoice_type = 'sale'
      AND pp.invoice_id = s.id
      AND pp.reversal_for_id IS NULL
      AND pp.is_refund = 1
  ), 0),
  0
)
''';
