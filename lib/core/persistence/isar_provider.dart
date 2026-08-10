import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

/// Provides the app-wide [Isar] instance.
///
/// Must be overridden in `ProviderScope` with a concrete instance produced by
/// `openAppIsar()`. The default throws so missing wiring fails fast.
final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError(
    'isarProvider must be overridden with an open Isar instance',
  ),
);
