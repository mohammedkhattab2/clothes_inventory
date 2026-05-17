import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Prompts the user to choose where an export file should be saved.
class UserExportPathPicker {
  const UserExportPathPicker();

  Future<String?> pickSavePath({
    required String dialogTitle,
    required String suggestedFileName,
    required List<String> extensions,
  }) async {
    if (extensions.isEmpty) {
      throw ArgumentError('extensions must not be empty');
    }

    final ext = extensions.first.toLowerCase().replaceAll('.', '');
    final type = ext == 'csv'
        ? FileType.custom
        : ext == 'pdf'
            ? FileType.custom
            : FileType.any;

    final picked = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedFileName,
      type: type,
      allowedExtensions: type == FileType.custom ? extensions : null,
    );

    if (picked == null || picked.trim().isEmpty) {
      return null;
    }

    return _ensureExtension(picked.trim(), ext);
  }

  String _ensureExtension(String path, String extension) {
    final normalizedExt = extension.startsWith('.') ? extension : '.$extension';
    if (p.extension(path).toLowerCase() == normalizedExt.toLowerCase()) {
      return path;
    }
    return '$path$normalizedExt';
  }
}
