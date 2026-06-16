import 'package:delta_erp/services/printing/rtl_printer_formatter.dart';

/// ESC/POS raster/text DPI for XP-350B class devices.
const double thermalEscPosDpi = 203.0;

/// Printable text columns for thermal paper width.
int lineWidthForPaper(double paperWidthMm) {
  if (paperWidthMm <= 58) {
    return kThermal58mmLineWidth;
  }
  return kThermal80mmLineWidth;
}

/// Dot width at [thermalEscPosDpi] for a given printable width in millimeters.
int escPosDotsForWidthMm(double paperWidthMm) {
  return (paperWidthMm * thermalEscPosDpi / 25.4).round();
}
