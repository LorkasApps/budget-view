# Isar setup + base schema

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | 001 |
| **Status** | Ready |

## Description
Add `isar_community` 4.x as local persistence layer. Encrypted DB (Bankdaten). Encryption key managed via Android Keystore. Expose Isar instance through a Riverpod provider. Establish schema-versioning strategy (dev: nuke+rebuild, prod: manual from v1.0).

## Acceptance Criteria
- [ ] `isar_community` (^4.x) added to `pubspec.yaml`
- [ ] `flutter_secure_storage` (or equivalent Keystore lib) added for encryption-key persistence
- [ ] On first launch, a random 32-byte encryption key is generated and stored in Android Keystore
- [ ] On subsequent launches, key is read from Keystore and passed to Isar open
- [ ] Isar instance opens encrypted at `getApplicationDocumentsDirectory()`
- [ ] Isar instance exposed via Riverpod provider (`isarProvider`)
- [ ] `kDbSchemaVersion` constant defined in `lib/core/persistence/schema_version.dart` — starts at `1`
- [ ] Migration policy documented inline: dev nukes DB when version bumps; prod migrations added starting v1.0 release
- [ ] Dev-mode debug reset helper (button or command) that deletes the DB file + clears the Keystore entry
- [ ] Smoke test: app boots, Isar opens, provider yields non-null instance, closes cleanly

## Affected Tests
- Unit test for encryption-key bootstrap (mock secure storage)
- Widget test verifies `isarProvider` overridable in tests

## Fixtures Needed
No (schema base only — actual entities defined in later tickets).

## Refinement Tokens (estimate)
- Input: ~6k tokens
- Output: ~1.5k tokens

## Token Usage
_Filled after Done._
