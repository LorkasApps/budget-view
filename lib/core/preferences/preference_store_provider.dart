import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preference_store.dart';

/// Provides the app-wide [PreferenceStore].
///
/// Must be overridden in `ProviderScope` with a concrete store, same shape as
/// `isarProvider`. The default throws so missing wiring fails fast.
final preferenceStoreProvider = Provider<PreferenceStore>(
  (ref) => throw UnimplementedError(
    'preferenceStoreProvider must be overridden with a concrete store',
  ),
);
