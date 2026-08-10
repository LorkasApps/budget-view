import 'package:isar_community/isar.dart';

part 'app_meta.g.dart';

/// Singleton row (always [id] == 0) holding app-wide persistence metadata.
@collection
class AppMeta {
  Id id = 0;

  late int schemaVersion;

  late String installId;

  late DateTime createdAt;
}
