# Phase 1 & 2 – Deliverables Überblick

## Phase 1 – Entwicklungs-Setup & Infrastruktur
- Flutter-Workspace `frontend/` mit Material 3 und ShadCN-inspiriertem Theme angelegt.
- Firebase-Placeholder-Konfiguration (`lib/services/firebase/firebase_options.dart`) vorbereitet.
- Analyseregeln (`analysis_options.yaml`) und `pubspec.yaml` mit Firebase-, Firestore- und Messaging-Abhängigkeiten erstellt.
- Firestore-Regeln, `firebase.json` und `.firebaserc` konfiguriert.
- Dokumentation zur Firebase-Einrichtung unter `firebase/setup.md` erstellt.

## Phase 2 – Authentifizierung & Haushaltsverwaltung (MVP-Basis)
- Authentifizierungs-UI (`AuthPage`) mit Registrierung/Anmeldung via Firebase Auth implementiert.
- Haushaltsauswahl und -erstellung (`HouseholdGate`, `HouseholdSelectPage`) inkl. Rollenfarbe (Admin) umgesetzt.
- Feature-Struktur für Kalender, Agenda, Geburtstags-Tab und Einstellungen angelegt.
- Datenmodelle für Nutzer, Haushalte, Mitgliedschaften, Kalender, Events, Geburtstage und Wiederholungen erstellt.
- Firestore-Repositories für Nutzer, Haushalte, Kalender und Events sowie Notification/Functions-Services bereitgestellt.
- Grundlegende Kalenderansichten (Monat, Agenda, Geburtstage) implementiert und mit Firestore-Streams verdrahtet.
- Theme, Date/Time-Utilities und Timezone-Helfer hinzugefügt.
