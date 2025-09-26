# FamilyCal

FamilyCal ist ein gemeinsamer Familienkalender für moderne Haushalte. Die App vereint Terminplanung, Aufgaben, Verfügbarkeiten und Geburtstage in einer aufgeräumten Oberfläche und synchronisiert Daten in Echtzeit über Firebase.

> **Mission:** Stressfreie Familienorganisation dank smarter Kalender- und Aufgabenautomatisierung auf allen Geräten.

---

## 🧭 Überblick

- **Plattformen:** Flutter-App für Android, iOS, Web (PWA), macOS und Windows.
- **Sync & Offline:** Firestore-Replikation, Konfliktauflösung, lokales Caching.
- **Automatisierung:** Cloud Functions für Erinnerungen, ICS-Import/-Export, Geburtstage und Aufgaben-Reminder.
- **Design:** Material 3 mit ShadCN-/Tailwind-inspirierter Ästhetik, rollenbasierte Farben, barrierearme Interaktionen.

---

## ✨ Highlights

- Mehrere Haushalte mit flexiblen Rollenfarben, Einladungen per Code & Admin-Werkzeugen.
- Kalender in Monats-, Wochen-, Tages- und Agenda-Ansicht inkl. Wiederholungen (RRULE), Ausnahmen, privaten/öffentlichen Terminen und Push-Erinnerungen.
- Aufgaben-Board mit Status, Fälligkeiten, Verantwortlichen, Beschreibung und Erinnerungsworkflow.
- Verfügbarkeitsplaner sammelt Slots der Mitglieder, aggregiert sie automatisch und zeigt freie Zeitfenster.
- Geburtstags-Tab samt automatischer Altersberechnung und täglichen Updates.
- ICS-Import/-Export, damit externe Kalender integriert oder exportiert werden können.
- Benachrichtigungen via Firebase Cloud Messaging inkl. gerätespezifischer Token-Verwaltung.

---

## ✅ Implementierte Funktionen

| Bereich | Features (Auszug) |
| --- | --- |
| **Authentifizierung** | E-Mail & Google Sign-In (`lib/main.dart`, `features/auth/`), automatisches Nutzerprofil, Logout über AppBar |
| **Haushalte** | Anlegen/Beitreten per Einladungscode, Rollenverwaltung, Adminrollen, Token-Handling (`household_repository.dart`, `features/household/presentation/`) |
| **Kalender** | Monats-/Wochen-/Tages-/Agenda-Views, Event-Editor mit Kategorien, RRULE, Ausnahmen, Erinnerungen, Sichtbarkeiten (`features/calendar/presentation/`) |
| **Verfügbarkeiten** | Editor & Auswertung, Firestore-Trigger aggregiert Tageszusammenfassung (`availability_editor_sheet.dart`, `firebase/functions/src/index.ts`) |
| **Aufgaben** | Task-Board mit Drag/Drop? (List), Editor-Bottom-Sheet, Statuswechsel & Löschbestätigung (`features/tasks/presentation/`, `TaskRepository`) |
| **Geburtstage** | Übersicht & Altersberechnung im UI (`birthday_tab.dart`) plus täglicher Worker `birthdayUpdater` |
| **Benachrichtigungen** | Gerätespezifische Token-Speicherung, Event- und Task-Reminder (`notifications_service.dart`, Cloud Functions) |
| **ICS & Integrationen** | `importIcs` & `exportIcs` Callables, ICS-Parsing & -Generierung (`firebase/functions/src/index.ts`) |
| **Security** | Durchdachte Firestore-Regeln (`firebase/firestore.rules`) mit Mitgliedschafts- und Rollen-Checks |

---

## 🧩 Architektur auf einen Blick

```
frontend/lib/
  main.dart
  features/
    auth/
    household/
    calendar/
      presentation/ agenda, month, week, day, availability, birthday
      controllers/
      widgets/
    tasks/
    settings/
  models/
  services/
    repositories/
      household_repository.dart
      calendar_repository.dart
      task_repository.dart
    firestore_service.dart
    functions_service.dart
    notifications_service.dart

firebase/
  firestore.rules
  functions/
    src/index.ts
    types/
```

- **State & Datenzugriff:** Repository-Layer kapselt Firestore/Functions-Aufrufe; UI erhält Streams für Echtzeitupdates.
- **Widgets:** Material 3, responsive Layouts, modulare Komponenten (`features/calendar/widgets/`).
- **Services:** Notifications-Handling, Functions-Clients, Utility-Layer (`frontend/lib/services/`).

---

## ☁️ Firebase Cloud Functions

Alle Funktionen leben in `firebase/functions/src/index.ts` und laufen auf Node.js 20:

- `scheduleEventReminders` – legt Erinnerungen in `scheduledReminders` an (callable).
- `reminderWorker` – verschickt minütlich Push-Nachrichten für fällige Termine (Pub/Sub cron).
- `importIcs` / `exportIcs` – bidirektionaler ICS-Sync für Kalender.
- `birthdayUpdater` – aktualisiert täglich kommende Geburtstage & Altersangaben.
- `aggregateAvailabilities` – aggregiert Verfügbarkeiten je Tag/Haushalt (Firestore Trigger).
- `taskReminderWorker` – erinnert Verantwortliche an überfällige Aufgaben.
- `cleanup` – entfernt veraltete Einladungen und alte Reminder-Dokumente.

---

## 🛠️ Technologie-Stack

- Flutter 3 (Material 3, Custom Widgets, intl, cloud_firestore, firebase_auth, firebase_messaging)
- Firebase Authentication, Cloud Firestore, Cloud Functions, Cloud Messaging, Firebase Hosting
- GitHub Actions, Firebase CLI, Dart/Flutter Analyzer, Codacy Quality Checks

---

## 🧪 Qualität & Sicherheit

- Firestore-Regeln decken Haushaltsrollen, Sichtbarkeiten und Mitgliedschaftsprüfung ab.
- Repository-Tests (`frontend/test/`) prüfen Termin- und Wiederholungslogik.
- Codacy & Analyzer Pipelines halten sich an Dart Style, Complexity und Security Checks.

---

## 📚 Weiterführende Dokumente

- Produktvision & Roadmap: `docs/phase0.md` bis `docs/phase6.md`
- Firebase-Konfiguration & Deploy-Guides: `firebase/setup.md`, `docs/release_checklist.md`
- Fehler- & Statusberichte: `docs/fault log`

---

FamilyCal entsteht als persönliches Herzensprojekt für stressfreien Familienalltag. Feedback, Issues oder Pull Requests sind willkommen!

