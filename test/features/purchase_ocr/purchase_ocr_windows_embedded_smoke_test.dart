import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/purchase_ocr/data/purchase_ocr_service.dart';
import 'package:path/path.dart' as path;

void main() {
  test('embedded windows OCR smoke test prints extracted text', () async {
    if (!Platform.isWindows) {
      debugPrint('Skipping embedded OCR smoke test: Windows only.');
      return;
    }

    final service = OfflinePurchaseOcrService();
    final samplePath = path.join(
      Directory.current.path,
      'test',
      'features',
      'purchase_ocr',
      'fixtures',
      'sample_invoice.png',
    );

    final sampleFile = File(samplePath);
    if (!sampleFile.existsSync()) {
      debugPrint(
        'Skipping embedded OCR smoke test: sample image not found at $samplePath',
      );
      return;
    }

    final text = await service.debugExtractTextFromSample(
      imagePath: samplePath,
    );
    debugPrint('Embedded OCR smoke test output:\n$text');
    expect(text.trim().isNotEmpty, isTrue);
  });
}
