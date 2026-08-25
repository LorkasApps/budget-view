import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../import/data/imported_source.dart';
import '../../../transaction/data/transaction.dart';
import '../domain/receipt_document_source.dart';
import '../domain/receipt_scan_flow_controller.dart';
import '../domain/receipt_scan_providers.dart';
import 'scan_review_screen.dart';
import 'scan_source_sheet.dart';

/// Drives one or more receipt scans for [transaction] through modal steps.
///
/// Holds a manual subscription for the whole flow: the controller is
/// `autoDispose`, and without a listener it would be torn down — together with
/// the photo bytes — between two awaits.
Future<void> startReceiptScan(
  BuildContext context,
  WidgetRef ref,
  Transaction transaction,
) async {
  // The progress dialog is opened from the listener rather than around an await:
  // rendering starts inside the controller call, after the file picker is gone.
  var progressOpen = false;
  final subscription = ref.listenManual(receiptScanFlowProvider, (
    previous,
    next,
  ) {
    final rendering = next.phase == ReceiptScanPhase.rendering;
    if (rendering && !progressOpen && context.mounted) {
      progressOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PageProgressDialog(),
      ).then((_) => progressOpen = false);
    } else if (!rendering && progressOpen && context.mounted) {
      progressOpen = false;
      Navigator.of(context).pop();
    }
  });
  try {
    while (true) {
      final source = await showScanSourceSheet(context);
      if (source == null) return;

      final controller = ref.read(receiptScanFlowProvider.notifier);
      final imageSource = source.asScanSource;
      await (imageSource == null
          ? controller.startPdfScan(transaction: transaction)
          : controller.startScan(
              transaction: transaction,
              source: imageSource,
            ));

      if (ref.read(receiptScanFlowProvider).phase ==
          ReceiptScanPhase.duplicateWarning) {
        if (!context.mounted) return;
        final matches = ref.read(receiptScanFlowProvider).documentMatches;
        if (!await _confirmRescan(context, matches)) {
          controller.cancel();
          return;
        }
        await controller.proceedAfterWarning();
      }

      if (ref.read(receiptScanFlowProvider).phase ==
          ReceiptScanPhase.manyPagesWarning) {
        if (!context.mounted) return;
        final pages = ref.read(receiptScanFlowProvider).pageCount;
        if (!await _confirmPageCount(context, pages)) {
          controller.cancel();
          return;
        }
        await controller.proceedAfterPageWarning();
      }

      if (!context.mounted) return;
      var state = ref.read(receiptScanFlowProvider);
      if (state.phase == ReceiptScanPhase.failed) {
        _showError(context, state.errorMessage);
        return;
      }
      if (state.phase != ReceiptScanPhase.awaitingConfirm) return;

      final reviewed = await pushScanReview(
        context,
        transaction: transaction,
        candidates: state.candidates,
        expectedSumCents: state.expectedSumCents,
        unreadRows: state.unreadRows,
        // Debug builds only: the recognised layout is the one thing no test can
        // produce, since ML Kit has no test-VM binding (ticket 055).
        onDumpRecognition: kDebugMode ? controller.dumpRecognition : null,
      );
      if (reviewed == null) {
        controller.cancel();
        return;
      }
      await controller.confirm(edited: reviewed);

      if (!context.mounted) return;
      state = ref.read(receiptScanFlowProvider);
      if (state.phase == ReceiptScanPhase.failed) {
        _showError(context, state.errorMessage);
        return;
      }
      if (!await _askScanAnother(context, state.lineItemsPersisted)) return;
      if (!context.mounted) return;
    }
  } finally {
    subscription.close();
  }
}

/// Mirrors the PDF import's re-import warning (ticket 009).
Future<bool> _confirmRescan(
  BuildContext context,
  List<ImportedSource> matches,
) async {
  final previous = matches.first;
  final when = DateFormat('dd.MM.yyyy').format(previous.importedAt);
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Bon schon gescannt'),
      content: Text(
        'Dieses Foto wurde am $when schon ausgewertet '
        '(${previous.lineItemsProduced} Positionen). Erneut auswerten?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Fortfahren'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}

/// A scan with more pages than a receipt has is worth a question — reading it
/// means rendering and recognising every page.
Future<bool> _confirmPageCount(BuildContext context, int pages) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Langes Dokument'),
      content: Text('Dieses PDF hat $pages Seiten. Alle lesen?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Alle lesen'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}

/// Says which page is being read. Several seconds of silence reads as a frozen
/// app, and a scanned document takes about a second per page.
class _PageProgressDialog extends ConsumerWidget {
  const _PageProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptScanFlowProvider);
    final page = state.pagesRead + 1;
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              state.pageCount <= 1
                  ? 'Beleg wird gelesen…'
                  : 'Seite $page von ${state.pageCount} wird gelesen…',
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _askScanAnother(BuildContext context, int persisted) async {
  final another = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Scan übernommen'),
      content: Text('$persisted Positionen hinzugefügt.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Fertig'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Weiteren Bon scannen'),
        ),
      ],
    ),
  );
  return another ?? false;
}

void _showError(BuildContext context, String? message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Scan fehlgeschlagen')),
  );
}
