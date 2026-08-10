import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/isar_provider.dart';
import 'local_sync_adapter.dart';
import 'sync_adapter.dart';

/// The app-wide [SyncAdapter]. Currently the local stub; swap the concrete
/// type here when a real backend adapter lands.
final syncAdapterProvider = Provider<SyncAdapter>((ref) {
  final isar = ref.watch(isarProvider);
  return LocalSyncAdapter(isar);
});
