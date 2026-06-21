import 'dart:typed_data';

import 'package:delta_erp/services/printing/esc_pos_constants.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

typedef EscPosRasterPdfJobBuilder = Future<Uint8List> Function({
  required Uint8List pdfBytes,
  required double paperWidthMm,
  double dpi,
  int feedLines,
  bool cut,
});

/// Builds one continuous ESC/POS raster job from PDF bytes.
abstract final class EscPosRasterJobBuilder {
  // XP-350 class printers are sensitive to very tall single raster commands.
  static const int _maxRasterBandHeightPx = 128;

  static Future<Uint8List> buildFromPdf({
    required Uint8List pdfBytes,
    required double paperWidthMm,
    double dpi = thermalEscPosDpi,
    int feedLines = 2,
    bool cut = true,
  }) async {
    if (pdfBytes.isEmpty) {
      throw StateError('Cannot build raster print job from empty PDF bytes.');
    }

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);

    final rasters = await _decodePdfPages(pdfBytes, dpi: dpi);
    if (rasters.isEmpty) {
      throw StateError('PDF rasterization returned no pages.');
    }

    final merged = _mergeVertical(rasters);
    final maxDots = _toLowerMultipleOf8(escPosDotsForWidthMm(paperWidthMm));
    final resized =
        merged.width > maxDots ? img.copyResize(merged, width: maxDots) : merged;
    final sourceImage = _padWidthToByteBoundary(resized, maxWidth: maxDots);

    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(_encodeRasterBands(generator, sourceImage));
    if (feedLines > 0) {
      bytes.addAll(generator.feed(feedLines));
    }
    if (cut) {
      bytes.addAll(generator.cut(mode: PosCutMode.partial));
    }

    if (bytes.length < 32) {
      throw StateError('Generated ESC/POS raster payload is too small.');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<List<img.Image>> _decodePdfPages(
    Uint8List pdfBytes, {
    required double dpi,
  }) async {
    final pages = <img.Image>[];
    await for (final raster in Printing.raster(pdfBytes, dpi: dpi)) {
      final png = await raster.toPng();
      final decoded = img.decodePng(png);
      if (decoded != null) {
        pages.add(decoded);
      }
    }
    return pages;
  }

  static img.Image _mergeVertical(List<img.Image> pages) {
    if (pages.length == 1) {
      return pages.first;
    }

    var width = 0;
    var height = 0;
    for (final page in pages) {
      if (page.width > width) {
        width = page.width;
      }
      height += page.height;
    }

    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    var offsetY = 0;
    for (final page in pages) {
      img.compositeImage(canvas, page, dstX: 0, dstY: offsetY);
      offsetY += page.height;
    }
    return canvas;
  }

  static int _toLowerMultipleOf8(int value) {
    final normalized = value < 8 ? 8 : value;
    return normalized - (normalized % 8);
  }

  static img.Image _padWidthToByteBoundary(
    img.Image source, {
    required int maxWidth,
  }) {
    var targetWidth = source.width;
    if (targetWidth % 8 != 0) {
      targetWidth += 8 - (targetWidth % 8);
    }
    if (targetWidth > maxWidth) {
      targetWidth = maxWidth;
    }
    if (targetWidth == source.width) {
      return source;
    }

    final canvas = img.Image(width: targetWidth, height: source.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, source, dstX: 0, dstY: 0);
    return canvas;
  }

  static List<int> _encodeRasterBands(Generator generator, img.Image source) {
    final bytes = <int>[];
    if (source.height <= _maxRasterBandHeightPx) {
      bytes.addAll(generator.imageRaster(source, align: PosAlign.left));
      return bytes;
    }

    for (var y = 0; y < source.height; y += _maxRasterBandHeightPx) {
      final bandHeight =
          (source.height - y) < _maxRasterBandHeightPx
              ? (source.height - y)
              : _maxRasterBandHeightPx;
      final band = img.copyCrop(
        source,
        x: 0,
        y: y,
        width: source.width,
        height: bandHeight,
      );
      bytes.addAll(generator.imageRaster(band, align: PosAlign.left));
    }
    return bytes;
  }
}