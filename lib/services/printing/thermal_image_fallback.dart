import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

class ThermalImageFallback {
  const ThermalImageFallback();

  Future<Uint8List> captureWidgetAsPng(
    RenderRepaintBoundary boundary, {
    required int targetPaperWidthPx,
    double pixelRatio = 2,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode captured widget image.');
    }

    return byteData.buffer.asUint8List();
  }

  int paperWidthPx58mm() => 384;
  int paperWidthPx80mm() => 576;
}
