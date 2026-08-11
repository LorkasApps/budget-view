import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/account/data/account.dart';
import '../../features/category/data/category.dart';
import '../../features/transaction/data/transaction.dart';
import '../sync/change_queue_entry.dart';
import 'app_meta.dart';
import 'schema_version.dart';

const _uuid = Uuid();

/// All Isar collection schemas that make up the app database.
/// Extend this list as feature tickets add collections.
const List<CollectionSchema<dynamic>> appIsarSchemas = [
  AppMetaSchema,
  ChangeQueueEntrySchema,
  AccountSchema,
  TransactionSchema,
  CategorySchema,
];

/// Opens the app's Isar instance and reconciles [AppMeta] / schema version.
///
/// [directory] overrides the storage location — tests pass a temp dir. In the
/// app it defaults to `getApplicationDocumentsDirectory()`.
Future<Isar> openAppIsar({String? directory}) async {
  final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
  final isar = await Isar.open(appIsarSchemas, directory: dir);
  await _reconcileMeta(isar);
  return isar;
}

Future<void> _reconcileMeta(Isar isar) async {
  final existing = await isar.appMetas.get(0);

  if (existing == null) {
    await isar.writeTxn(() async {
      await isar.appMetas.put(
        AppMeta()
          ..id = 0
          ..schemaVersion = kDbSchemaVersion
          ..installId = _uuid.v4()
          ..createdAt = DateTime.now(),
      );
    });
    return;
  }

  if (existing.schemaVersion != kDbSchemaVersion) {
    // Dev policy: a breaking bump is handled by DevTools.wipeDatabase (nuke+rebuild).
    // Prod policy (v1.0+): run migration steps keyed on existing.schemaVersion here,
    // then persist the new version below.
    await isar.writeTxn(() async {
      await isar.appMetas.put(existing..schemaVersion = kDbSchemaVersion);
    });
  }
}
