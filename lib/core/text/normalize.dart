/// Lower-cases, trims and collapses runs of whitespace.
///
/// Lives in core because two features must normalise identically: duplicate
/// detection hashes the result, and tagging rules match on it. If they ever
/// diverge, a rule learned from one spelling stops matching the other.
String normalizeForMatching(String value) =>
    value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
