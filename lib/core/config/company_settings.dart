class CompanySettings {
  const CompanySettings({
    required this.name,
    required this.address,
    required this.phoneNumbers,
    this.logoPath,
  });

  final String name;
  final String address;
  final List<String> phoneNumbers;
  final String? logoPath;

  String get phonesText => phoneNumbers.join(' - ');

  CompanySettings copyWith({
    String? name,
    String? address,
    List<String>? phoneNumbers,
    String? logoPath,
  }) {
    return CompanySettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
