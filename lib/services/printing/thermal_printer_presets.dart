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

  /// Printable sticker area (mm) — 3.8 × 2.5 cm per user label stock.
  static const labelWidthMm = 38.0;
  static const labelHeightMm = 25.0;

  /// Blank feed before the first sticker on the roll (mm) — 2 mm on 350B.
  /// In PDF this is appended after all labels (350B prints bottom-first).
  static const labelLeadingGapMm = 2.0;

  /// Extra offset for first label alignment (added to [labelLeadingGapMm] only).
  static const labelLeadingAdjustMm = 0.0;

  /// Physical gap between consecutive stickers (mm) — 1.5 + 1.5 from adjacent labels.
  static const labelInterGapMm = 3.0;

  /// Backward-compatible alias for [labelInterGapMm].
  static const labelGapMm = labelInterGapMm;

  /// Horizontal padding inside the sticker printable area (mm).
  static const labelHorizontalMarginMm = 1.5;

  /// Backward-compatible alias for horizontal in-label padding.
  static const labelInnerMarginMm = labelHorizontalMarginMm;

  /// Top inset inside the 25 mm sticker (mm).
  static const labelVerticalPaddingTopMm = 0.5;

  /// Blank margin at sticker bottom — printed first on bottom-to-top 350B feeds.
  static const labelPrintLeadingMarginMm = 2.5;

  /// Backward-compatible alias for [labelPrintLeadingMarginMm].
  static const labelVerticalPaddingBottomMm = labelPrintLeadingMarginMm;

  /// Backward-compatible alias — use [labelPrintLeadingMarginMm].
  static const labelVerticalPaddingMm = labelVerticalPaddingTopMm;

  /// Spacing between text rows inside a sticker (mm).
  static const labelRowSpacingMm = 1.0;

  /// Store name on barcode labels — Arial bold.
  static const labelCompanyNameFontSizePt = 8.5;

  /// Price line on barcode labels.
  static const labelPriceFontSizePt = 6.5;

  /// Product name on barcode labels.
  static const labelProductFontSizePt = 6.0;

  /// Human-readable barcode digits below the bars.
  static const labelBarcodeTextFontSizePt = 6.0;

  /// CODE128 bar height on barcode labels (mm).
  static const labelBarcodeHeightMm = 8.0;

  /// Maximum barcode labels per print job.
  static const maxBarcodeLabelCopies = 500;

  /// Max strip height the XP-350B Windows driver reliably prints per PDF job.
  /// Four 25 mm labels + three 3 mm gaps = 109 mm.
  static const labelMaxStripHeightMm = 109.0;

  /// Safer strip height for stable barcode batching on X350/350B drivers.
  static const labelReliableStripHeightMm = 81.0;

  /// Pause between consecutive barcode PDF jobs so the 350B finishes feeding.
  static const labelInterBatchDelayMs = 4500;

  /// Pause between consecutive invoice PDF strips on continuous 80 mm paper.
  static const invoiceInterBatchDelayMs = 3500;

  /// One label per PDF job when total copies exceed [labelMaxStripHeightMm] capacity.
  static const labelCopiesPerJob = 1;

  /// Shared driver strip cap for barcode labels and thermal invoice receipts.
  static const driverMaxStripHeightMm = labelMaxStripHeightMm;

  /// ESC/POS line feeds between consecutive gap-sensor labels (~28 mm pitch).
  static const labelPitchFeedLines = 9;

  /// Extra feeds before the first label when the roll is already at a gap.
  static const labelLeadingFeedLines = 1;

  /// CODE128 bar height in ESC/POS dots (1–255).
  static const labelEscPosBarcodeHeightDots = 40;

  /// Human-readable hint for settings UI.
  static const settingsHint =
      '350B: invoices 80mm, barcode labels ${labelWidthMm}x${labelHeightMm}mm';
}
