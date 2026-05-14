import 'dart:io';
import 'dart:developer' as dev;

class FolderOpenerService {
  const FolderOpenerService();

  Future<bool> openContainingFolder(String filePath) async {
    try {
      final file = File(filePath);
      final folder = file.parent;
      if (!await folder.exists()) {
        dev.log(
          'Folder does not exist for path: $filePath',
          name: 'FolderOpenerService',
        );
        return false;
      }

      if (Platform.isWindows) {
        final result = await Process.run('explorer', [folder.path]);
        if (result.exitCode != 0) {
          dev.log(
            'Failed to open folder on Windows: ${result.stderr}',
            name: 'FolderOpenerService',
          );
        }
        return result.exitCode == 0;
      }
      if (Platform.isMacOS) {
        final result = await Process.run('open', [folder.path]);
        if (result.exitCode != 0) {
          dev.log(
            'Failed to open folder on macOS: ${result.stderr}',
            name: 'FolderOpenerService',
          );
        }
        return result.exitCode == 0;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [folder.path]);
        if (result.exitCode != 0) {
          dev.log(
            'Failed to open folder on Linux: ${result.stderr}',
            name: 'FolderOpenerService',
          );
        }
        return result.exitCode == 0;
      }

      return false;
    } catch (e, st) {
      dev.log(
        'Exception while opening folder for path: $filePath',
        name: 'FolderOpenerService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
