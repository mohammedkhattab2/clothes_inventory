/// Normalizes stored machine invoice numbers for UI (letter + min 4 digits).
String displayMachineInvoiceNumber({
  required int id,
  String? rawInvoiceNumber,
  required String letterUpper,
  required RegExp machinePattern,
}) {
  final raw = (rawInvoiceNumber ?? '').trim();
  if (raw.isEmpty || raw == '-') {
    return '#$id';
  }
  final m = machinePattern.firstMatch(raw);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      final suffix =
          n <= 9999 ? n.toString().padLeft(4, '0') : n.toString();
      return '$letterUpper$suffix';
    }
  }
  return raw;
}

String displaySaleInvoiceNumber({
  required int id,
  String? rawInvoiceNumber,
}) {
  return displayMachineInvoiceNumber(
    id: id,
    rawInvoiceNumber: rawInvoiceNumber,
    letterUpper: 'S',
    machinePattern: RegExp(r'^[Ss](\d+)$'),
  );
}

String displayPurchaseInvoiceNumber({
  required int id,
  String? rawInvoiceNumber,
}) {
  return displayMachineInvoiceNumber(
    id: id,
    rawInvoiceNumber: rawInvoiceNumber,
    letterUpper: 'P',
    machinePattern: RegExp(r'^[Pp](\d+)$'),
  );
}
