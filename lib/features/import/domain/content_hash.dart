import 'package:crypto/crypto.dart';

/// SHA-256 over the untouched document bytes, identifying a re-imported file.
///
/// Takes `List<int>` rather than `Uint8List` purely so this file needs no
/// typed-data import; every caller passes a `Uint8List`.
String computeContentHash(List<int> bytes) => sha256.convert(bytes).toString();
