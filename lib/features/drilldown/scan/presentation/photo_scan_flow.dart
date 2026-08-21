import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../import/data/imported_source.dart';
import '../../../transaction/data/transaction.dart';
import '../domain/photo_scan_flow_controller.dart';
import '../domain/photo_scan_providers.dart';
import 'scan_review_screen.dart';
import 'scan_source_sheet.dart';

/// Drives one or more receipt scans for [transaction] through modal steps.
///
/// Holds a manual subscription for the whole flow: the controller is
/// `autoDispose`, and without a listener it would be torn down — together with
/// the photo bytes — between two awaits.
Future<void> startPhotoScan(
  BuildContext context,
  WidgetRef ref,
  Transaction transaction,
) async {
  final subscription = ref.listenManual(photoScanFlowProvider, (_, _) {});
  try {
    while (true) {
      final source = await showScanSourceSheet(context);
      if (source == null) return;

      final controller = ref.read(photoScanFlowProvider.notifier);
      await controller.startScan(transaction: transaction, source: source);

      if (ref.read(photoScanFlowProvider).phase ==
          PhotoScanPhase.duplicateWarning) {
        if (!context.mounted) return;
        final matches = ref.read(photoScanFlowProvider).documentMatches;
        if (!await _confirmRescan(context, matches)) {
          controller.cancel();
          return;
        }
        await controller.proceedAfterWarning();
      }

      if (!context.mounted) return;
      var state = ref.read(photoScanFlowProvider);
      if (state.phase == PhotoScanPhase.failed) {
        _showError(context, state.errorMessage);
        return;
      }
      if (state.phase != PhotoScanPhase.awaitingConfirm) return;

      final reviewed = await pushScanReview(
        context,
        transaction: transaction,
        candidates: state.candidates,
        printedTotalCents: state.printedTotalCents,
      );
      if (reviewed == null) {
        controller.cancel();
        return;
      }
      await controller.confirm(edited: reviewed);

      if (!context.mounted) return;
      state = ref.read(photoScanFlowProvider);
      if (state.phase == PhotoScanPhase.failed) {
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
