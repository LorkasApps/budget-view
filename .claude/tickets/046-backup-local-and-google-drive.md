# Backup: local file and Google Drive

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | None |
| **Status** | Draft |

## Description
Everything this app knows lives in one Isar database inside the app sandbox. Uninstall the app, lose the phone, or wipe it,
and the data is gone: statements would have to be re-imported, categories rebuilt, tagging rules relearned, and every
line-item typed by hand — the receipts themselves are never persisted, by decision.

Wanted: a backup, written locally and to Google Drive.

## What makes this bigger than an export button

**It would be the app's first network access.** Nothing goes online today: the sync layer is a local stub with a change
queue, OCR runs on-device, no parser fetches anything, and the manifest declares no internet permission. Google Drive means
OAuth, a Google account on the device, `googleapis`, and a permission whose absence has so far been a feature.

**The database is deliberately unencrypted.** `decisions.md` accepted that because Android's file-based encryption plus the
app sandbox cover a local single-user app. A backup file breaks that reasoning by design: it leaves the sandbox. A plaintext
copy of every booking, counterparty and receipt position in a Drive folder is a different threat model from the one that was
signed off.

**Backup is not the sync stub.** The Supabase adapter and the change queue exist for continuous replication. A backup is a
point-in-time copy for disaster recovery. They can share a serialisation format, but confusing the two would produce a
half-sync that neither restores cleanly nor syncs reliably.

**Restore is the hard half.** Writing a file is an afternoon; reading one back into a schema that has moved on is the part
that decides whether the feature is worth anything. `kDbSchemaVersion` is at 4 and rises with every field.

## Open questions for refinement
- **What is in the backup?** A copy of the Isar file — exact, opaque, and only restorable into a compatible schema — or an
  export of the entities (JSON) that survives a schema change but needs an importer per entity and can drift from the model?
- **Restore semantics:** replace everything, or merge into existing data? Merging needs identity rules per entity; the uuids
  exist, which makes it possible and slow. Replacing is honest and destructive
- **What about a backup from an older schema version?** Refuse with a readable message, or migrate on import — which would
  mean writing the migration steps that `openAppIsar` currently only promises for v1.0
- **Encryption:** does an exported file get a passphrase? Without one, the honest answer in the UI is that the file is
  readable by anyone who has it. With one, a forgotten passphrase means a useless backup
- **Local target:** a user-chosen location through the system dialog (`file_selector` can offer a save location), or a fixed
  app-visible folder? The first survives an uninstall, the second does not — which defeats the purpose
- **Drive scope:** the app folder (`drive.appdata`, invisible to the user, cannot be handed to another device easily) or a
  normal file in My Drive (visible, shareable, and one wrong tap from being shared)?
- **When does it run?** A button, or scheduled? Scheduling means background work, a WorkManager dependency and a battery
  story — and it is the only variant that helps someone who loses their phone without having thought about backups
- **How many copies are kept**, and who deletes the old ones?
- Scope check: local export, Drive upload and restore are plausibly three tickets. Precedent for splitting exists (013 → 025,
  009 → 024, 033 → 044)

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Backing up the receipts and statements themselves; they are never persisted, so there is nothing to copy
- Cross-device live sync — that is the Supabase adapter's job, not this ticket's
- Any provider other than Google Drive for now

## Affected Tests
- Serialisation and restore are pure logic and belong in unit tests, including the refusal path for an incompatible version
- The Drive side needs its network client behind an interface, like `SyncAdapter` and `DuplicateChecker`, so nothing in the
  suite talks to Google
- The one thing tests cannot cover is the OAuth consent flow, which lands in a device checklist

## Fixtures Needed
Ask during refinement. A backup file of a known state is the obvious candidate, and it would be the first fixture in the repo
that encodes the whole schema — worth a deliberate decision, since it goes stale with every field added.

## Token Usage
_Filled after Done._
