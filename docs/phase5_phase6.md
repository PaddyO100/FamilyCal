# Phase 5 & 6 – Qualitätssicherung, Release & Post-MVP

## Phase 5 – QA, Automatisierung & Releasevorbereitung
- CI-Pipeline via GitHub Actions ergänzt (`.github/workflows/flutter_ci.yml`) für `flutter analyze` und `flutter test`.
- Widget- und Util-Tests geschaffen (z. B. Recurrence- und Availability-Logik), um Kernfunktionen automatisch zu prüfen.
- Release-Checkliste in `docs/release_checklist.md` dokumentiert und im Firebase-Setup um QA-/Staging-Schritte erweitert.
- Zusätzliche Telemetrie-Hooks in den Repositories vorbereitet (strukturierte Logging-Ausgaben in Firestore/Functions).
- Beta-Channel-Dokumentation und Store-Vorbereitung in README aufgenommen.

## Phase 6 – Erweiterungen nach MVP (1.1.0 → 2.0.0)
- Verfügbarkeiten als eigenes Feature ausgeliefert (Modelle, Repository, UI-Ansicht + Editor, Functions-Aggregation).
- Aufgabenboard mit Haushalts-Tasks inklusive Firestore-Anbindung, Fälligkeitsdaten und Statusumschaltung implementiert.
- Availability-Summaries und Reminder-Funktionen über Cloud Functions automatisiert.
- Roadmap für Versionen 1.1.0, 1.2.0 und 2.0.0 in README ergänzt (ICS-Verbesserungen, Aufgaben-Insights, externe Integrationen).
- Tests und Regeln für neue Collections (`tasks`, `availabilitySummaries`) erweitert.
