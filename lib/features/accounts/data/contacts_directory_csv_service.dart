import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:delta_erp/features/accounts/data/accounts_repository.dart';

class ContactsDirectoryCsvService {
  const ContactsDirectoryCsvService();

  Future<String> exportToCsv({
    required List<AccountLookup> accounts,
    required String fileNamePrefix,
    required String targetPath,
  }) async {
    try {
      String esc(String value) {
        final escaped = value.replaceAll('"', '""');
        return '"$escaped"';
      }

      final buffer = StringBuffer();
      buffer.writeln('id,name,account_type,phone');
      for (final a in accounts) {
        buffer.writeln(
          '${a.id},${esc(a.name)},${esc(a.accountType)},${esc(a.phone ?? '')}',
        );
      }

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      final bytes = utf8.encode('\uFEFF${buffer.toString()}');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting contacts CSV',
        name: 'ContactsDirectoryCsvService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
