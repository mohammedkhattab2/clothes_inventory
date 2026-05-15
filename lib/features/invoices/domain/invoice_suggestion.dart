class InvoiceSuggestion {
  const InvoiceSuggestion({
    required this.id,
    required this.invoiceNumber,
    required this.accountLabel,
  });

  final int id;
  final String invoiceNumber;
  final String accountLabel;
}
