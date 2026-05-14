import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;

import 'package:clothes_inventory/core/utils/app_paths.dart';
import 'package:clothes_inventory/features/purchase_ocr/data/purchase_ocr_service.dart';

class OcrLogger {
  const OcrLogger();

  static const int _maxLogBytes = 1024 * 1024;
  static const int _retainLogBytes = 512 * 1024;

  Future<void> logOcrFailure(OcrFailure failure, String? imagePath) async {
    try {
      final logPath = await AppPaths.getLogsPath();
      final logFile = File(logPath);
      final logDir = logFile.parent;
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String();
      final imageName = imagePath == null ? 'n/a' : path.basename(imagePath);
      final logEntry = StringBuffer()
        ..writeln('[$timestamp] OCR failure')
        ..writeln('message: ${failure.message}')
        ..writeln('debugDetails: ${failure.debugDetails}')
        ..writeln('imagePath: $imageName')
        ..writeln('---');

      await _rotateIfNeeded(logFile);
      await logFile.writeAsString(logEntry.toString(), mode: FileMode.append);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to write OCR log file: $error\n$stackTrace');
      }
    }
  }

  Future<void> _rotateIfNeeded(File logFile) async {
    if (!await logFile.exists()) return;

    final int currentSize = await logFile.length();
    if (currentSize < _maxLogBytes) return;

    try {
      final content = await logFile.readAsString();
      final int keepFrom = content.length > _retainLogBytes
          ? content.length - _retainLogBytes
          : 0;
      final trimmed = content.substring(keepFrom);
      await logFile.writeAsString(trimmed, mode: FileMode.write, flush: false);
    } catch (_) {
      // Best-effort rotation only.
    }
  }
}
