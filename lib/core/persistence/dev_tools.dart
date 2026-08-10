import 'package:isar_community/isar.dart';

/// Debug-only persistence helpers. Never call from production code paths.
class DevTools {
  const DevTools._();

  /// Closes the given Isar instance and deletes its storage from disk.
  ///
  /// Used for the dev nuke+rebuild policy on a schema-version bump. The caller
  /// must re-open Isar (via `openAppIsar`) and refresh `isarProvider` afterwards.
  static Future<void> wipeDatabase(Isar isar) async {
    await isar.close(deleteFromDisk: true);
  }
}
