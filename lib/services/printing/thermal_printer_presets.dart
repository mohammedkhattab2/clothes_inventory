/// Preset dimensions for XP-350B / 350B thermal label printers.
///
/// Paper width range: 20–82 mm, USB interface, gap-sensor label mode.
abstract final class ThermalPrinterPresets {
  static const modelName = '350B';

  /// Recommended invoice roll width for this model.
  static const recommendedInvoiceWidthMm = 80.0;

  /// Thermal invoice horizontal margins (mm) for RTL receipts on this printer.
  static const invoiceMarginLeftMm = 2.0;
  static const invoiceMarginRightMm = 5.0;

  /// Printable sticker area (mm).
  static const labelWidthMm = 37.0;
  static const labelHeightMm = 22.0;

  /// Physical gap between consecutive stickers on the roll (mm).
  static const labelGapMm = 2.0;

  /// Extra top offset inside the sticker to avoid clipping the store name.
  static const labelTopMarginMm = 2.5;

  /// Safe horizontal/vertical padding inside the sticker (mm).
  static const labelInnerMarginMm = 1.5;

  /// Human-readable hint for settings UI.
  static const settingsHint =
      '350B: invoices 80mm, barcode labels ${labelWidthMm}x${labelHeightMm}mm';
}
