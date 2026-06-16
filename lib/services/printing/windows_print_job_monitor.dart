import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Polls the Windows spooler until a print job finishes or fails.
abstract final class WindowsPrintJobMonitor {
  static const pollInterval = Duration(milliseconds: 200);
  static const defaultTimeout = Duration(seconds: 60);

  static const int statusSpooling = 0x00000001;
  static const int statusPrinting = 0x00000002;
  static const int statusError = 0x00000008;
  static const int statusOffline = 0x00000020;
  static const int statusPaperOut = 0x00000040;
  static const int statusDeleted = 0x00000100;

  static int? interpretActiveJobStatus(int? status) {
    if (status == null) return null;
    if ((status & statusError) != 0) return statusError;
    if ((status & statusPaperOut) != 0) return statusPaperOut;
    if ((status & statusOffline) != 0) return statusOffline;
    if ((status & statusDeleted) != 0) return statusDeleted;
    if ((status & (statusSpooling | statusPrinting)) != 0) {
      return statusSpooling | statusPrinting;
    }
    return null;
  }

  static String messageForStatus(int status) {
    if ((status & statusPaperOut) != 0) {
      return 'Printer is out of paper.';
    }
    if ((status & statusOffline) != 0) {
      return 'Printer is offline or disconnected.';
    }
    if ((status & statusDeleted) != 0) {
      return 'Print job was cancelled before completion.';
    }
    if ((status & statusError) != 0) {
      return 'Windows spooler reported a print error.';
    }
    return 'Print job failed (spooler status $status).';
  }

  /// Returns current Windows spooler job ids for [printerName].
  static Future<Set<int>> snapshotJobIds(String printerName) async {
    if (!Platform.isWindows) return const {};

    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<IntPtr>();
    try {
      if (OpenPrinter(printerNamePtr, printerHandlePtr, nullptr) == 0) {
        throw StateError(
          'Could not monitor print job (OpenPrinter error ${GetLastError()}).',
        );
      }

      return _listJobs(printerHandlePtr.value).map((job) => job.jobId).toSet();
    } finally {
      if (printerHandlePtr.value != 0) {
        ClosePrinter(printerHandlePtr.value);
      }
      calloc.free(printerHandlePtr);
      calloc.free(printerNamePtr);
    }
  }

  /// Picks the newest spooler job id that was not present in [idsBefore].
  static int? resolveNextSpoolerJobId({
    required Set<int> idsBefore,
    required Set<int> idsAfter,
  }) {
    final fresh = idsAfter.difference(idsBefore);
    if (fresh.isEmpty) return null;
    return fresh.reduce((a, b) => a > b ? a : b);
  }

  /// Finds a newly submitted job, preferring [documentName] matches.
  static int? findSubmittedJobId({
    required Set<int> idsBefore,
    required List<SpoolerJobSnapshot> jobs,
    required String documentName,
  }) {
    SpoolerJobSnapshot? documentMatch;
    for (final job in jobs) {
      if (idsBefore.contains(job.jobId)) continue;
      if (_documentMatches(job.document, documentName)) {
        if (documentMatch == null || job.jobId > documentMatch.jobId) {
          documentMatch = job;
        }
      }
    }
    if (documentMatch != null) {
      return documentMatch.jobId;
    }

    return resolveNextSpoolerJobId(
      idsBefore: idsBefore,
      idsAfter: jobs.map((job) => job.jobId).toSet(),
    );
  }

  /// Returns true when no spooler jobs are actively printing or spooling.
  static bool isQueueIdle(List<SpoolerJobSnapshot> jobs) {
    if (jobs.isEmpty) return true;
    for (final job in jobs) {
      final interpreted = interpretActiveJobStatus(job.status);
      if (interpreted == (statusSpooling | statusPrinting)) {
        return false;
      }
    }
    return true;
  }

  /// Reads current spooler jobs for [printerName].
  static Future<List<SpoolerJobSnapshot>> snapshotJobs(String printerName) async {
    if (!Platform.isWindows) return const [];

    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<IntPtr>();
    try {
      if (OpenPrinter(printerNamePtr, printerHandlePtr, nullptr) == 0) {
        throw StateError(
          'Could not monitor print job (OpenPrinter error ${GetLastError()}).',
        );
      }

      return _listJobs(printerHandlePtr.value)
          .map(
            (job) => SpoolerJobSnapshot(
              jobId: job.jobId,
              status: job.status,
              document: job.document,
            ),
          )
          .toList(growable: false);
    } finally {
      if (printerHandlePtr.value != 0) {
        ClosePrinter(printerHandlePtr.value);
      }
      calloc.free(printerHandlePtr);
      calloc.free(printerNamePtr);
    }
  }

  /// Waits until a newly submitted job with [documentName] appears and finishes.
  static Future<void> waitForSubmittedJob({
    required String printerName,
    required Set<int> idsBefore,
    required String documentName,
    Duration timeout = defaultTimeout,
  }) async {
    if (!Platform.isWindows) return;

    final deadline = DateTime.now().add(timeout);
    int? trackedJobId;

    while (DateTime.now().isBefore(deadline)) {
      final jobs = await snapshotJobs(printerName);
      trackedJobId ??= findSubmittedJobId(
        idsBefore: idsBefore,
        jobs: jobs,
        documentName: documentName,
      );
      if (trackedJobId != null) {
        break;
      }
      await Future<void>.delayed(pollInterval);
    }

    if (trackedJobId == null) {
      throw StateError(
        'Print job "$documentName" did not reach the spooler.',
      );
    }

    final remaining = deadline.difference(DateTime.now());
    await waitForCompletion(
      printerName: printerName,
      jobId: trackedJobId,
      timeout: remaining.isNegative ? pollInterval : remaining,
    );
  }

  /// Waits until the printer queue has no active spooler jobs.
  static Future<void> waitUntilQueueIdle({
    required String printerName,
    Duration timeout = defaultTimeout,
  }) async {
    if (!Platform.isWindows) return;

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final jobs = await snapshotJobs(printerName);
      if (isQueueIdle(jobs)) {
        return;
      }
      await Future<void>.delayed(pollInterval);
    }

    throw StateError(
      'Printer queue did not become idle within ${timeout.inSeconds}s.',
    );
  }

  /// Waits for the next spooler job submitted after [idsBefore] to finish.
  static Future<void> waitForNextSpoolerJob({
    required String printerName,
    required Set<int> idsBefore,
    Duration timeout = defaultTimeout,
  }) async {
    if (!Platform.isWindows) return;

    final deadline = DateTime.now().add(timeout);
    int? trackedJobId;

    while (DateTime.now().isBefore(deadline)) {
      final currentIds = await snapshotJobIds(printerName);
      trackedJobId ??= resolveNextSpoolerJobId(
        idsBefore: idsBefore,
        idsAfter: currentIds,
      );
      if (trackedJobId != null) {
        break;
      }
      await Future<void>.delayed(pollInterval);
    }

    if (trackedJobId == null) {
      throw StateError('Print job did not reach the spooler.');
    }

    final remaining = deadline.difference(DateTime.now());
    await waitForCompletion(
      printerName: printerName,
      jobId: trackedJobId,
      timeout: remaining.isNegative ? pollInterval : remaining,
    );
  }

  /// Waits until a driver PDF job with [documentName] completes in the spooler.
  static Future<void> waitForDocumentJob({
    required String printerName,
    required String documentName,
    Duration timeout = defaultTimeout,
  }) async {
    if (!Platform.isWindows) return;

    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<IntPtr>();
    try {
      if (OpenPrinter(printerNamePtr, printerHandlePtr, nullptr) == 0) {
        throw StateError(
          'Could not monitor print job (OpenPrinter error ${GetLastError()}).',
        );
      }

      final hPrinter = printerHandlePtr.value;
      final deadline = DateTime.now().add(timeout);
      var seenJob = false;

      while (DateTime.now().isBefore(deadline)) {
        final job = _findJobByDocument(hPrinter, documentName);
        if (job != null) {
          seenJob = true;
          final interpreted = interpretActiveJobStatus(job.status);
          if (interpreted != null &&
              interpreted != (statusSpooling | statusPrinting)) {
            throw StateError(messageForStatus(interpreted));
          }
        } else if (seenJob) {
          return;
        }

        await Future<void>.delayed(pollInterval);
      }

      if (!seenJob) {
        throw StateError(
          'Print job "$documentName" did not reach the spooler.',
        );
      }

      throw StateError(
        'Print job timed out after ${timeout.inSeconds}s waiting for the printer.',
      );
    } finally {
      if (printerHandlePtr.value != 0) {
        ClosePrinter(printerHandlePtr.value);
      }
      calloc.free(printerHandlePtr);
      calloc.free(printerNamePtr);
    }
  }

  static Future<void> waitForCompletion({
    required String printerName,
    required int jobId,
    Duration timeout = defaultTimeout,
  }) async {
    if (!Platform.isWindows) return;

    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<IntPtr>();
    try {
      if (OpenPrinter(printerNamePtr, printerHandlePtr, nullptr) == 0) {
        throw StateError(
          'Could not monitor print job (OpenPrinter error ${GetLastError()}).',
        );
      }

      final hPrinter = printerHandlePtr.value;
      final deadline = DateTime.now().add(timeout);
      var seenJob = false;

      while (DateTime.now().isBefore(deadline)) {
        final status = _readJobStatus(hPrinter, jobId);
        if (status != null) {
          seenJob = true;
          final interpreted = interpretActiveJobStatus(status);
          if (interpreted == null) {
            return;
          }
          if (interpreted != (statusSpooling | statusPrinting)) {
            throw StateError(messageForStatus(interpreted));
          }
        } else if (seenJob) {
          return;
        }

        await Future<void>.delayed(pollInterval);
      }

      if (!seenJob) {
        throw StateError(
          'Print job $jobId did not appear in the spooler.',
        );
      }

      throw StateError(
        'Print job timed out after ${timeout.inSeconds}s waiting for the printer.',
      );
    } finally {
      if (printerHandlePtr.value != 0) {
        ClosePrinter(printerHandlePtr.value);
      }
      calloc.free(printerHandlePtr);
      calloc.free(printerNamePtr);
    }
  }

  static _SpoolerJob? _findJobByDocument(int hPrinter, String documentName) {
    final jobs = _listJobs(hPrinter);
    for (final job in jobs) {
      if (_documentMatches(job.document, documentName)) {
        return job;
      }
    }
    return null;
  }

  static bool _documentMatches(String spoolerDocument, String expected) {
    final actual = spoolerDocument.trim().toLowerCase();
    final target = expected.trim().toLowerCase();
    if (actual.isEmpty || target.isEmpty) return false;
    if (actual == target) return true;
    if (actual == '$target.pdf') return true;
    if (target == '$actual.pdf') return true;
    return false;
  }

  /// Visible for tests — matches Windows spooler document titles to app job names.
  static bool documentNameMatches(String spoolerDocument, String expected) {
    return _documentMatches(spoolerDocument, expected);
  }

  static List<_SpoolerJob> _listJobs(int hPrinter) {
    final needed = calloc<Uint32>();
    final returned = calloc<Uint32>();
    try {
      EnumJobs(hPrinter, 0, 0xFFFFFFFF, 1, nullptr, 0, needed, returned);
      final required = needed.value;
      if (required == 0) {
        return const [];
      }

      final buffer = calloc<Uint8>(required);
      try {
        final ok = EnumJobs(
          hPrinter,
          0,
          0xFFFFFFFF,
          1,
          buffer,
          required,
          needed,
          returned,
        );
        if (ok == 0) {
          return const [];
        }

        final count = returned.value;
        final jobs = <_SpoolerJob>[];
        final pointer = buffer.cast<JOB_INFO_1>();
        for (var i = 0; i < count; i++) {
          final info = pointer[i];
          jobs.add(
            _SpoolerJob(
              jobId: info.JobId,
              status: info.Status,
              document: info.pDocument.address == 0
                  ? ''
                  : info.pDocument.toDartString(),
            ),
          );
        }
        return jobs;
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(needed);
      calloc.free(returned);
    }
  }

  static int? _readJobStatus(int hPrinter, int jobId) {
    final needed = calloc<Uint32>();
    try {
      GetJob(hPrinter, jobId, 1, nullptr, 0, needed);
      final required = needed.value;
      if (required == 0) {
        return null;
      }

      final buffer = calloc<Uint8>(required);
      try {
        final ok = GetJob(
          hPrinter,
          jobId,
          1,
          buffer,
          required,
          needed,
        );
        if (ok == 0) {
          return null;
        }
        return buffer.cast<JOB_INFO_1>().ref.Status;
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(needed);
    }
  }
}

class SpoolerJobSnapshot {
  const SpoolerJobSnapshot({
    required this.jobId,
    required this.status,
    required this.document,
  });

  final int jobId;
  final int status;
  final String document;
}

class _SpoolerJob {
  const _SpoolerJob({
    required this.jobId,
    required this.status,
    required this.document,
  });

  final int jobId;
  final int status;
  final String document;
}
