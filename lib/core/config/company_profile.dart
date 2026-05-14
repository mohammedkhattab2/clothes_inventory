class CompanyProfile {
  const CompanyProfile._();

  // Update these values with your official company details.
  static const String name = 'شركة المشد لتجارة الحدايد والبويات والديكور ';
  static const String address = 'طنطا - أول ميت حبيش - عمارة المشد ';
  static const List<String> phoneNumbers = <String>[
    '01017149438',
    '01550819097',
  ];

  static String get phonesText => phoneNumbers.join(' - ');
}
