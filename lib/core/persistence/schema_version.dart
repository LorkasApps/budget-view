/// Current Isar schema version.
///
/// Bump whenever a collection schema changes in a breaking way.
/// Dev policy: a mismatch nukes + rebuilds the DB (see [DevTools.wipeDatabase]).
/// Prod policy (from v1.0): add explicit migration steps keyed on this value.
const int kDbSchemaVersion = 1;
