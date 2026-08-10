# Architectural Decisions

| Date | Decision | Reason |
|------|----------|--------|
| 2026-08-10 | Flutter as app framework | User choice |
| 2026-08-10 | Isar as local persistence (local-first) | User choice |
| 2026-08-10 | Supabase as future sync layer (prep only) | User choice, cloud-sync deferred |
| 2026-08-10 | Google ML Kit for OCR | User choice, on-device |
| 2026-08-10 | Linear regression for forecast | User choice, simple + explainable |
| 2026-08-10 | Plug-in system for PDF parsers | Generic import, no bank lock-in |
| 2026-08-10 | Fractal categorization (line-item overrides parent) | User requirement, Kassenbon-drilldown |
| 2026-08-10 | Duplicate detection via hash (amount+date+description) | User requirement, PDF↔manual + PDF↔PDF |
| 2026-08-10 | Riverpod as state management | Compile-safe, DI included, fits Isar reactive patterns |
| 2026-08-10 | Android-only target (no iOS/Web/Desktop) | User scope reduction |
| 2026-08-10 | Feature-first folder layout | Fits domain-driven ticket structure |
| 2026-08-10 | flutter_lints (default) as linter | Sanft, ausreichend, kann später verschärft werden |
| 2026-08-10 | Package = `de.lorkaps_apps.budget_view`, App name = `BudgetView` | User choice |
| 2026-08-10 | Isar-DB verschlüsselt (Bankdaten) | Data-at-rest protection, key in Android Keystore |
| 2026-08-10 | `isar_community` 4.x statt originalem `isar` | Original-Repo unmaintained, Community-Fork aktiv |
| 2026-08-10 | Dev: nuke+rebuild bei Schema-Änderung. Prod: manuelle Migration ab v1.0 | Frühphase-Overhead klein, sauber ab Release |
| 2026-08-10 | Sync-Stub = Interface + lokale Change-Queue (Op-Log) | Validiert Design ohne Cloud-Anbindung |
| 2026-08-10 | Change-Queue-Eintrag: {op, entity_type, entity_id, payload_json, ts} | Fein-granular, standard local-first |
| 2026-08-10 | Entity-IDs = UUID v4 (client-generiert) | Kollisionsfrei über Geräte, Isar auto-inc bleibt interner Storage-Index |
| 2026-08-10 | Repository-Layer hook: jede Mutation ruft adapter.enqueue() | Zentrale Sync-Anbindung, keine App-weite Interceptor-Magie |
| 2026-08-10 | Geldbeträge = int64 Cents | Vermeidet Floating-Point-Fehler in Finance-Domain |
| 2026-08-10 | Currency = EUR only für MVP (kein Feld) | Reduziert Komplexität, Multi-Currency später als eigenes Ticket |
| 2026-08-10 | Soft-Delete für Account (archived Flag) | Historie bleibt erhalten, sync-freundlich |
| 2026-08-10 | Kategorie-Baum: freie Roots, Sign des Betrags = Richtung | Vermeidet Kategorie-Duplikate für Rückzahlungs-Cases (Pfand, Nebenkosten) |
| 2026-08-10 | Category Delete blockiert wenn Kinder oder Transaktionen vorhanden | Erzwingt explizites Umziehen, kein Datenverlust |
| 2026-08-10 | Category Name unique per Parent (nicht global) | Wiederverwendung von "Einkauf" / "Rückerstattung" unter versch. Parents |
| 2026-08-10 | Transaktion: Soft-Delete (deleted Flag) | Historie bleibt, sync-freundlich |
| 2026-08-10 | Dedupe-Hash: SHA-256 über amountCents + bookingDate (Datum) + normalisierter counterparty | User-Wahl; Kollisionen bei leerem counterparty werden als UI-Warnung dargestellt, User entscheidet |
| 2026-08-10 | Roh-Dokumente (PDFs + Kassenbon-Fotos) werden NICHT persistiert | Nur einmal ausgewertet, Bytes verworfen; nur Extrakt (Transaktionen / Line-Items) + Metadata bleiben |
| 2026-08-10 | ImportedSource-Entity: contentHash SHA-256 + Metadata pro Import | Re-Import-Warnung ("diese Datei schon am ... importiert") — Deckt PDF- + Foto-Imports |
