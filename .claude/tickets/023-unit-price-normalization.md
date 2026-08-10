# Weight-based unit-price normalization for price trends

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | 015, 018, 022 |
| **Status** | Draft |
| **Target Release** | Post-V1 (nicht Teil des V1-MVP) |

## Description
Variable-Gewicht-Items (Steak, Käse, Obst nach Gewicht) haben pro Kauf einen anderen Gesamtpreis — das liegt am Gewicht, nicht am eigentlichen Preisniveau. Preistrend in Ticket 022 zeigt daher auf Gesamtpreis-Ebene ein volatiles Bild, obwohl der **Preis pro kg** (bzw. pro l, pro Stk) stabil sein kann. Dieses Ticket erweitert Line-Items um eine **Mengeneinheit** und lässt den Preistrend auf den normalisierten Einheitspreis (€/kg, €/l, €/Stk) rechnen.

## Motivation
- Kaufe ich 320 g Rinderfilet für 13,44 € → 42,00 €/kg
- Kaufe ich 450 g Rinderfilet für 18,90 € → 42,00 €/kg
- Ohne Normalisierung: Chart zeigt 13,44 → 18,90 (irreführend)
- Mit Normalisierung: Chart zeigt 42,00 → 42,00 (echter Trend)

## Scope
- `LineItem` bekommt ein neues Feld `unit` (enum: `g`, `kg`, `ml`, `l`, `stk`, `pack`; default `stk`).
- OCR-Heuristik (Ticket 018) erweitert um Gewichts-Pattern-Erkennung (`320g`, `1,5 kg`, `0,5 l`, `500 ml`).
- User kann `unit` + `quantity` beim Editieren jederzeit anpassen.
- Price-Trend-Service (Ticket 022) rechnet intern in eine **Referenz-Einheit** (kg für Masse, l für Volumen, stk für Stückgut) um.
- Chart-Y-Achsen-Label zeigt die Einheit dynamisch (`€/kg`, `€/l`, `€/Stk`).
- Innerhalb eines Item-Groups (normalisierte Description) müssen Einheiten kompatibel sein; sind sie es nicht (z.B. mal g, mal stk erfasst) → Warnung + User entscheidet.

## Rough Acceptance Criteria (verfeinert bei Refinement)
- [ ] `LineItem.unit` Enum hinzugefügt (Migration nötig — ab V1.0-Release relevant)
- [ ] OCR-Parser erkennt Gewichts- + Volumen-Muster, füllt `quantity` + `unit`
- [ ] Line-Item-Edit-Sheet: Unit-Picker sichtbar wenn `quantity != null`
- [ ] Price-Trend-Service normalisiert pro Item-Group auf Referenz-Einheit
- [ ] Chart-Label passt sich Einheit an
- [ ] Mixed-Unit-Group: Warnung + User-Wahl der Referenz-Einheit oder Split-View
- [ ] Bestehende Line-Items ohne Unit werden per Default auf `stk` gesetzt (bestandsschützend)
- [ ] Rückwärtskompatibel zu Ticket 022 (fällt zurück auf Gesamtpreis wenn `unit` fehlt / inkompatibel)

## Open Refinement Questions (bei späterer Refinement-Runde klären)
- Welche Einheiten sind Pflicht im MVP der V2? Nur `g`/`kg` oder auch Volumen + Pack?
- Wie erkennt OCR `Stk` implizit (kein Gewicht) vs. `pack` (z.B. „6er Pack")?
- Wenn User in einer Item-Group Einheit wechselt (früher g, jetzt kg) → auto-migrate oder als separate Group behandeln?
- Fallback für sehr alte Daten ohne Unit im Chart mitanzeigen (grau markiert) oder ausblenden?

## Notes
- Voraussetzung: reale Nutzung von Ticket 022 muss zeigen, dass Volatilität durch Gewicht ein Problem ist. Falls sich das nicht bestätigt → dieses Ticket verwerfen.
- Zusammen mit dem in 022 skizzierten **Item-Merge-Tool** ist das der komplette Analytics-Reifegrad-Sprung V1 → V2.

## Token Usage
_Filled after Done._
