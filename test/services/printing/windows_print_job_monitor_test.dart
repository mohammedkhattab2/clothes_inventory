import 'package:delta_erp/services/printing/windows_print_job_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowsPrintJobMonitor', () {
    test('interpretActiveJobStatus returns null when job is done', () {
      expect(WindowsPrintJobMonitor.interpretActiveJobStatus(null), isNull);
      expect(WindowsPrintJobMonitor.interpretActiveJobStatus(0), isNull);
      expect(
        WindowsPrintJobMonitor.interpretActiveJobStatus(0x00000080),
        isNull,
      );
    });

    test('interpretActiveJobStatus detects active spooler states', () {
      expect(
        WindowsPrintJobMonitor.interpretActiveJobStatus(
          WindowsPrintJobMonitor.statusSpooling,
        ),
        WindowsPrintJobMonitor.statusSpooling |
            WindowsPrintJobMonitor.statusPrinting,
      );
      expect(
        WindowsPrintJobMonitor.interpretActiveJobStatus(
          WindowsPrintJobMonitor.statusPrinting,
        ),
        WindowsPrintJobMonitor.statusSpooling |
            WindowsPrintJobMonitor.statusPrinting,
      );
    });

    test('interpretActiveJobStatus detects failure states', () {
      expect(
        WindowsPrintJobMonitor.interpretActiveJobStatus(
          WindowsPrintJobMonitor.statusPaperOut,
        ),
        WindowsPrintJobMonitor.statusPaperOut,
      );
      expect(
        WindowsPrintJobMonitor.interpretActiveJobStatus(
          WindowsPrintJobMonitor.statusOffline,
        ),
        WindowsPrintJobMonitor.statusOffline,
      );
      expect(
        WindowsPrintJobMonitor.interpretActiveJobStatus(
          WindowsPrintJobMonitor.statusError,
        ),
        WindowsPrintJobMonitor.statusError,
      );
    });

    test('messageForStatus describes common failures', () {
      expect(
        WindowsPrintJobMonitor.messageForStatus(
          WindowsPrintJobMonitor.statusPaperOut,
        ),
        contains('paper'),
      );
      expect(
        WindowsPrintJobMonitor.messageForStatus(
          WindowsPrintJobMonitor.statusOffline,
        ),
        contains('offline'),
      );
    });

    test('documentNameMatches links app job names to spooler titles', () {
      expect(
        WindowsPrintJobMonitor.documentNameMatches(
          'DeltaERP Barcode Labels',
          'DeltaERP Barcode Labels',
        ),
        isTrue,
      );
      expect(
        WindowsPrintJobMonitor.documentNameMatches(
          'DeltaERP Barcode Labels.pdf',
          'DeltaERP Barcode Labels',
        ),
        isTrue,
      );
      expect(
        WindowsPrintJobMonitor.documentNameMatches(
          'Other document',
          'DeltaERP Barcode Labels',
        ),
        isFalse,
      );
      expect(
        WindowsPrintJobMonitor.documentNameMatches(
          'barcode_123',
          'barcode_123_2of3',
        ),
        isFalse,
      );
    });

    test('resolveNextSpoolerJobId picks the newest unseen job id', () {
      expect(
        WindowsPrintJobMonitor.resolveNextSpoolerJobId(
          idsBefore: {10, 11},
          idsAfter: {10, 11},
        ),
        isNull,
      );
      expect(
        WindowsPrintJobMonitor.resolveNextSpoolerJobId(
          idsBefore: {10, 11},
          idsAfter: {10, 11, 12},
        ),
        12,
      );
      expect(
        WindowsPrintJobMonitor.resolveNextSpoolerJobId(
          idsBefore: {10},
          idsAfter: {10, 12, 11},
        ),
        12,
      );
    });

    test('findSubmittedJobId prefers matching document names', () {
      const jobs = [
        SpoolerJobSnapshot(jobId: 12, status: 0, document: 'barcode_1'),
        SpoolerJobSnapshot(jobId: 13, status: 0, document: 'barcode_1_2of10'),
      ];

      expect(
        WindowsPrintJobMonitor.findSubmittedJobId(
          idsBefore: {10, 11},
          jobs: jobs,
          documentName: 'barcode_1_2of10',
        ),
        13,
      );
    });

    test('isQueueIdle ignores completed jobs still listed without active flags',
        () {
      expect(
        WindowsPrintJobMonitor.isQueueIdle(const [
          SpoolerJobSnapshot(jobId: 1, status: 0, document: 'done'),
        ]),
        isTrue,
      );
      expect(
        WindowsPrintJobMonitor.isQueueIdle(const [
          SpoolerJobSnapshot(
            jobId: 2,
            status: WindowsPrintJobMonitor.statusPrinting,
            document: 'printing',
          ),
        ]),
        isFalse,
      );
    });
  });
}
