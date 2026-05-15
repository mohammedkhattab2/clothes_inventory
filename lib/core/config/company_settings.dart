class _UnspecifiedValue {
  const _UnspecifiedValue();
}

class CompanySettings {
  /// Sentinel so [copyWith] can set nullable paths to null explicitly.
  static const Object _unspecified = _UnspecifiedValue();

  const CompanySettings({
    required this.name,
    required this.address,
    required this.phoneNumbers,
    this.logoPath,
    this.invoiceFooterNote = '',
    this.invoiceFooterImagePath,
  });

  final String name;
  final String address;
  final List<String> phoneNumbers;
  final String? logoPath;
  /// Free text printed at the bottom of invoices (e.g. notes, terms).
  final String invoiceFooterNote;
  /// Optional image (e.g. store barcode) printed below the invoice body.
  final String? invoiceFooterImagePath;

  String get phonesText => phoneNumbers.join(' - ');

  CompanySettings copyWith({
    String? name,
    String? address,
    List<String>? phoneNumbers,
    Object? logoPath = _unspecified,
    String? invoiceFooterNote,
    Object? invoiceFooterImagePath = _unspecified,
  }) {
    return CompanySettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      logoPath: identical(logoPath, _unspecified)
          ? this.logoPath
          : logoPath as String?,
      invoiceFooterNote: invoiceFooterNote ?? this.invoiceFooterNote,
      invoiceFooterImagePath: identical(invoiceFooterImagePath, _unspecified)
          ? this.invoiceFooterImagePath
          : invoiceFooterImagePath as String?,
    );
  }
}
