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
| 2026-08-10 | KEINE DB-Encryption; Verlass auf Android FBE + App-Sandbox | Isar bietet keine eingebaute Encryption; Field-Encryption würde Queries/Sortierung brechen (Kern der App). Threat-Model für lokale Single-User-App durch OS + App-scoped storage abgedeckt. App-Lock (Biometrie/PIN) optional als späteres Ticket |
| 2026-08-10 | `isar_community` 3.3.2 (nicht 4.x — existiert nicht) | Original-Repo unmaintained, Community-Fork aktiv; neueste stable ist 3.3.2 |
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
| 2026-08-11 | Parser choice per PDF via confidence ranking (canParse 0.0–1.0), user may override top pick | No bank lock-in; heuristics can be wrong |
| 2026-08-11 | Parser that throws or times out in canParse is skipped, not fatal | One broken plug-in must not block whole import |
| 2026-08-11 | `file_selector` (not `file_picker`) as file picker | Official Flutter package; Android-only scope needs only single-file pick; smaller native surface |
| 2026-08-11 | `syncfusion_flutter_pdf` für PDF-Text-Extraktion | Ticket-Wahl; Lizenz = Syncfusion Community License (nicht OSS), für private Single-User-App akzeptiert |
| 2026-08-11 | Keine Fixture-PDFs; Parser-Verifikation über Saldo-Abstimmung an echten Auszügen (env-gated Harness) | Ein mit dem `pdf`-Paket erzeugtes PDF reproduziert ING's Textlayer-Eigenheiten nicht (gepolsterte Wörter, geschluckte Klammern, gesplittete TextLines) — es würde einen Pfad prüfen, den der echte Extraktor nie nimmt. Layout-Logik hängt stattdessen an synthetischen Wort-Koordinaten. Realdaten bleiben außerhalb von git |
| 2026-08-11 | ING-Spaltengrenzen aus der Kopfzeile jeder Seite ableiten, nicht hart kodieren | Layout-Änderung der Bank degradiert zu einer Warnung statt zu stillem Fehl-Parsing |
| 2026-08-11 | Zeilengrammatik ohne Whitelist der Buchungsarten (Datum+Betrag = neue Zeile, nacktes Datum = Valuta) | Die Liste der ING-Buchungsarten ist offen; eine Whitelist würde unbekannte Typen unbemerkt verschlucken |
| 2026-08-11 | Dedupe bleibt komplett in Ticket 009, 008 importiert nur | 008-ACs verlangten 009-Artefakte, während 009 auf 008 blockte — Zyklus aufgelöst durch Schnitt "008 imports, 009 warns" |
| 2026-08-12 | "Nicht gesetzt" ist überall `null`, kein Empty-String-Sentinel. Ersetzt die 010-Entscheidung für `parentUuid = ''` | User-Wahl bei Ticket 011: `Transaction.categoryUuid` braucht dasselbe Konzept, und zwei Schreibweisen für dieselbe Bedeutung in einem Schema kosten mehr als der bis dahin ungetestete nullable Index. `Category.parentUuid` wurde nachgezogen |
| 2026-08-12 | Kategorie-Pflicht sitzt im Formular, nicht im Feld | Manuelle Erfassung verlangt eine Kategorie, PDF-Import erlaubt unkategorisierte Zeilen — dieselbe Spalte mit zwei Regeln je Eingabeweg |
| 2026-08-12 | `dedupeHash` wird bei *jedem* Save neu berechnet, nicht nur wenn leer | Sonst beschreibt der Hash nach einer Betrags-, Datums- oder Empfänger-Korrektur die alte Buchung, und die Duplikatprüfung vergleicht gegen etwas, das nicht mehr existiert |
| 2026-08-12 | `ImportedSource.delete` löscht echt, kein Soft-Delete wie sonst überall | Die Zeile existiert, damit ein Re-Import warnt. Eine archivierte Zeile, die weiter warnt, wäre sinnlos — Löschen *ist* hier die Fachfunktion |
| 2026-08-12 | Intra-Batch-Duplikate markieren **beide** Kopien | Die zweite ist nicht automatisch die falsche; der User entscheidet, welche bleibt |
| 2026-08-12 | Geteilte Import-Artefakte in eigener `Import`-Domain, formatspezifischer Code bleibt | `ImportedSource` und Doc-Hash brauchen PDF *und* Foto; der ING-Parser braucht nur PDF. Umziehen von funktionierendem 008-Code ohne funktionalen Gewinn vermieden |
| 2026-08-12 | Querschnitts-Services als Interface + `Local`-Implementierung (`SyncAdapter`, `DuplicateChecker`) | Erlaubt Widget-Tests ohne Isar, das in der Fake-Async-Zone von `testWidgets` nie fertig wird |
| 2026-08-13 | Line-Items sitzen als Sektion im `TransactionFormScreen` (Edit-Modus), kein eigener Detail-Screen | Das Formular besitzt die persistierte uuid, die eine Position braucht; ein Detail-Screen hätte nur einen Navigations-Hop und einen Umbau der Listen-Tests gekostet. Wird geprüft, wenn 016 den Kassenbon-Scan-Einstieg braucht |
| 2026-08-13 | `quantity × unitPrice ≠ amount` ist eine Warnung im Sheet, keine Repo-Ablehnung | Rabatt- und Pfandzeilen brechen das Produkt absichtlich. Folgt der Dedupe-Warnung, die auch im Formular sitzt statt im Repo |
| 2026-08-13 | Neue Collection ohne Bump von `kDbSchemaVersion` | Rein additiv — Isar legt die Collection beim Öffnen an. Ein Bump hätte in Dev die DB genukt und Testdaten gekostet, ohne Gegenwert |
| 2026-08-13 | Kategorie-Resolver liegt in `Drilldown`, nicht im von Ticket 012 genannten `Category`-Pfad | Die Funktionen nehmen ein `LineItem`; `Category` hängt nur an Infra plus der schmalen Transaction-Kante. Der Ticket-Pfad hätte `Category → Drilldown` neu aufgezogen, für eine Regel, deren Gegenstand die Position ist. Analytics (020, 022) hängt ohnehin an beiden Domains |
| 2026-08-13 | `reconcile()` wird von den UI-Pfaden gerufen, nicht per Hook in `TransactionRepository.save` | Ein Hook dort hätte `Transaction → Drilldown` gedreht, für eine Regel, die den Positionen gehört. Vier Aufrufstellen (Sheet-Save, Section-Delete, Section-Reorder, Buchungsformular) statt einer zentralen — Risiko: ein künftiger Schreibpfad auf `amountCents` vergisst den Aufruf. PDF-Import ist unkritisch, frische Buchungen haben keine Positionen |
| 2026-08-13 | Restposten-Schutz per `save()`-Guard + Test, nicht per Compiler | Dart hat kein package-private; Privatheit ist library-weit. Die Alternativen (Reconciler in dieselbe Datei wie das Repository, oder Sentinel-Token im Aufruf) kosten mehr Lesbarkeit als der Schutz wert ist |
| 2026-08-13 | Restposten-Zeile ist von Drag und Swipe ausgenommen, statt sie beim Versuch abzulehnen | Eine Zeile, die wegwischt und zurückkommt, liest sich als Bug. Reorder schreibt nur die regulären Zeilen, der Reconciler pinnt die verwaltete danach wieder nach unten |
| 2026-08-13 | `TaggingLearnService.learnFrom` wird von den UI-Pfaden gerufen, nicht per Observer in `TransactionRepository.save` | Gleiche Begründung wie beim Restposten-Reconcile: ein Hook im Repository hätte `Transaction → Tagging` gedreht. Drei Aufrufstellen (Formular, Inline-Quickpick, Import-Persist) — vergisst eine künftige Stelle den Aufruf, geht Lernen verloren, aber nichts wird inkonsistent |
| 2026-08-13 | `TaggingRule.delete` löscht echt, kein Soft-Delete | Eine archivierte Regel, die weiter vorschlägt, wäre sinnlos — dieselbe Logik wie bei `ImportedSource` |
| 2026-08-13 | `Transaction.categoryAutoSuggested` schon in 013 eingeführt, obwohl erst 014 es auf `true` setzt | Der Learn-Hook muss es lesen, sonst verstärkt sich ein akzeptierter Vorschlag selbst. Feld ist additiv, Altdaten lesen `false` — kein Schema-Bump |
| 2026-08-13 | Regel-Verwaltungs-UI aus 013 in ein eigenes Ticket 025 geschnitten | Es gibt noch keine Settings-Fläche; sie als Nebenprodukt eines Storage-Tickets zu bauen hätte sie versehentlich entworfen. 024 braucht dieselbe Fläche — wer zuerst landet, baut sie |
| 2026-08-13 | Parent-Soft-Delete kaskadiert nicht auf Line-Items | Positionen sind nur über die Buchung erreichbar, also genügt Unerreichbarkeit; ein Cascade würde die Wiederherstellung einer Buchung unvollständig machen |
| 2026-08-17 | OCR- und Parser-Contract entstehen in 016, die Implementierung erst in 017/018 (Stub statt Flow-Schnitt) | Der Controller *ist* das Artefakt von 016. Die Alternative — 016 endet nach dem Hash-Check — hätte die State-Machine zweimal umgebaut, und die Handoff-Contracts standen ohnehin schon im Ticket |
| 2026-08-17 | Scan-Einstieg als Button in `LineItemsSection`, kein Detail-Screen | Beantwortet den Prüfpunkt aus der 016-Klausel von #50: der Flow ist komplett modal und braucht keine eigene Screen-Fläche. Ein Detail-Screen hätte die von 015/019 gerade fertiggestellten Listen-Tests umgebaut |
| 2026-08-17 | Kein Provenance-Feld für "Positionen aus Scans", der geplante Zähler ist gestrichen | Ein rein informativer Zähler rechtfertigt kein Schema-Feld. Ehrlich wäre er nur pro Zeile (`LineItem.importedSourceUuid`) — das gehört nach 018, wo die Zeilen entstehen, und trägt dort echten Nutzen (Badge, Sammel-Löschen) |
| 2026-08-17 | Doc-Hash über die Rohbytes, Downscale erst danach | Sonst verschiebt ein Update der Image-Lib die Dokument-Identität, und die Re-Scan-Warnung aus 009 greift für dasselbe Foto nicht mehr |
| 2026-08-17 | Foto-Bytes außerhalb des Riverpod-States; Provider `autoDispose` plus `listenManual` für die Flow-Dauer | Bytes gehören nicht in einen vergleichbaren State. `autoDispose` erzwingt das Verwerfen beim Verlassen, die manuelle Subscription hält den Controller genau so lange am Leben wie den Flow. `state.holdsImage` spiegelt die Referenz, damit die Regel testbar ist |
| 2026-08-17 | Keine Android-Permission für den Scan | Photo Picker (API 33+) und `ACTION_IMAGE_CAPTURE` brauchen keine; ein deklariertes `CAMERA` würde die Runtime-Abfrage erst erzeugen. Grenze: `image_picker` hält für Kamera-Captures eine plugin-eigene Temp-Datei, die unser Code nie sieht |
| 2026-08-17 | Restposten-Reconcile schon im Confirm von 016, nicht erst in 018 | 016 schreibt bereits Positionen, und ein Schreibpfad ohne Reconcile hätte die Summen-Invariante aus 019 gebrochen. 018 erbt den Aufruf statt ihn nachzurüsten |
