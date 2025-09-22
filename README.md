Projektübersicht: FamilyCal – Ein geteilter Familienkalender

1. Zielsetzung

FamilyCal ist ein gemeinsamer, haushaltsorientierter Kalender, der die Schwächen des Google-Familienkalenders adressiert. Fokus liegt auf:

Intuitive, moderne UI (ShadCN/Tailwind-inspirierte Designs)

Multi-Plattform (Android, iOS, Web als PWA)

Offline-first mit Firebase Firestore Sync

Frei definierbare Rollen & Farben

Wiederholungen, Ausnahmen, Erinnerungen, Geburtstagsübersicht und Kategorien



---

2. Tech Stack

Frontend: Flutter (Material 3 + ShadCN/Tailwind-inspiriertes UI)

Backend: Firebase (Auth, Firestore, Functions, FCM)

Hosting: Firebase Hosting (für Web-PWA)

CI/CD: GitHub Actions + Firebase CLI



---

## Projektstatus & Setup

- **Phase 0:** Abgeschlossen – Vision und Leitplanken in [`docs/phase0.md`](docs/phase0.md).
- **Phase 1 & 2:** Grundgerüst und MVP-Basis umgesetzt – siehe [`docs/phase1_phase2.md`](docs/phase1_phase2.md).
- **Phase 3 & 4:** Kalenderkern, Event-Editor, Push-Benachrichtigungen sowie Firebase-Functions und Security-Rules fertiggestellt – siehe [`docs/phase3_phase4.md`](docs/phase3_phase4.md).
codex/implement-features-from-familycal-readme-j006u0
- **Phase 5 & 6:** QA/Release-Automatisierung, Verfügbarkeiten & Aufgabenboard implementiert – siehe [`docs/phase5_phase6.md`](docs/phase5_phase6.md).
=======
main

### Lokales Setup (Phase 1)
1. Flutter SDK installieren (mind. 3.16).
2. Abhängigkeiten installieren: `cd frontend && flutter pub get`.
3. Firebase konfigurieren gemäß [`firebase/setup.md`](firebase/setup.md) und generierte Optionen in `lib/services/firebase/firebase_options.dart` ersetzen.
4. App starten: `flutter run -d chrome` oder gewünschtes Gerät.

### Nächste Schritte (Phase 5+)
codex/implement-features-from-familycal-readme-j006u0
- Release-Checkliste befolgen (`docs/release_checklist.md`), Builds signieren und Store-Listing vorbereiten.
- Erweiterte Analytics, Monitoring sowie Nutzer-Feedback-Schleifen.
- Roadmap 1.1.0 (ICS Verbesserungen), 1.2.0 (Task Insights) & 2.0.0 (Externe Kalender) prüfen.
=======
- Stabilisierung, automatisierte Tests und Store-Release-Vorbereitung.
- Erweiterte Analytics, Monitoring sowie Nutzer-Feedback-Schleifen.
main

---

3. Funktionen

Kernfeatures

Haushaltsverwaltung (1 Admin, beliebig viele Mitglieder)

Rollen: Namen und Farben frei wählbar; Admin ist unveränderlich, alle anderen Rollen individuell benennbar (z. B. „Mama“, „Papa“, „Kind“).

Mehrere Kalender pro Haushalt

Events mit Wiederholung (RRULE) und Ausnahmen

Sichtbarkeit: privat, Haushalt, öffentlich

Erinnerungen via Push (FCM)

Offline-Modus + Konfliktmerge

Verfügbarkeiten für „Wann können wir?“

ICS Import/Export

Geburtstagstab: automatisch generierte jährliche Events mit Altersberechnung

Kategorien: Geschäftlich, Privat, Essen, Feier, Konzert, Urlaub, Besuch (erweiterbar)

Aufgabenboard mit Status, Fälligkeiten und Haushaltszuweisung


Event-Rechte

Alle Mitglieder können Termine für andere anlegen (z. B. Arzttermin für Kind → Push an Eltern).

Alle Termine können von allen bearbeitet werden (keine Owner-Bindung).

Neue Mitglieder nur durch Admin einladbar.


Zusatzfeatures (v2+)

Aufgabenlisten im Kalender

Integration mit externen Kalenderdiensten

Erweiterte Statistiken („meiste Termine“, „freie Slots“)



---

4. Datenmodell (Firestore)

users/{uid}: Stammdaten, Zeitzone, Haushaltszugehörigkeit

households/{hid}: Metadaten zum Haushalt

memberships/{hid}_{uid}:

Rolle: frei benennbar, Farbe (HEX)

isAdmin: bool (nur 1 Admin pro Haushalt)


calendars/{cid}: Kalender pro Haushalt

events/{eid}:

Kategorie: enum (geschäftlich, privat, essen, …)

Teilnehmer: beliebige Mitglieder

Änderungsrechte: alle Household-Member


birthdays/{uid}:

Name, Geburtsdatum, wiederkehrender Event mit Altersberechnung


availabilities/{uid}_{dateISO}: Tagesverfügbarkeiten

availabilitySummaries/{hid}_{dateISO}: Aggregierte Slots je Haushalt & Tag

tasks/{tid}: Aufgaben inkl. Status, Verantwortlichen und Due-Date

invites/{token}: Einladungen für neue Mitglieder (nur Admin)

deviceTokens/{uid}/{tokenId}: Push-Token



---

5. Backend-Logik (Firebase Functions)

scheduleEventReminders: Erstellt Reminder-Jobs pro Teilnehmer

reminderWorker: Läuft jede Minute, versendet Push-Notifikationen

importICS: ICS-Dateien parsen und in Events konvertieren

birthdayUpdater: erstellt jährliche Geburtstags-Events, aktualisiert Alter

cleanup: Alte/canceled Events bereinigen

aggregateAvailabilities: wertet Tagesverfügbarkeiten aus und speichert Zusammenfassungen

taskReminderWorker: tägliche Prüfung überfälliger Aufgaben und Push-Reminder


Sicherheit

Firestore Rules (Version 2):

Nur Admin darf Mitglieder einladen/entfernen

Rollen & Farben frei editierbar durch Admin

Alle Mitglieder dürfen Events anlegen & bearbeiten

Teilnehmer können Reminder/Status anpassen




---

6. Frontend-Struktur (Flutter)

lib/
  main.dart
  features/
    auth/
    household/
    calendar/
      views/ (Month, Week, Day, Agenda, BirthdayTab, Availability)
      controllers/ (Firestore Streams, RRULE Parser)
      widgets/ (EventCard, EventEditor, CategoryChips, ColorPicker)
    tasks/
      presentation/ (TaskBoard, TaskEditor)
  services/
    firestore_service.dart
    functions_service.dart
    notifications_service.dart
    repositories/ (events, households, memberships, calendars, availabilities, tasks)
  models/
    user.dart
    household.dart
    calendar.dart
    event.dart
    role.dart
    birthday.dart
    recurrence.dart
    availability.dart
    task.dart
  utils/
    tz.dart
    date_math.dart

UI Guidelines

ShadCN-inspiriert: klare Strukturen, Karten, Chips für Kategorien, Role-Badges in frei gewählten Farben

Geburtstagstab: eigener Tab in der Bottom-Navigation

Event-Editor: Kategorieauswahl via Chips, Teilnehmerauswahl mit Push-Benachrichtigungen

Rollenverwaltung: Admin kann Namen und Farben definieren


Screens

1. Auth: Login/Registrierung via Firebase Auth


2. Household Select: Haushalt erstellen/joinen (nur Admin fügt Mitglieder hinzu)


3. Kalender-Übersicht: Monats-, Wochen-, Tagesansicht, Geburtstags-Tab


4. Event-Editor: Titel, Ort, Zeit, Wiederholung, Teilnehmer, Kategorie


5. Einstellungen: Rollen & Farben, Push, ICS-Import/Export




---

7. Design-Prinzipien

Mobile-first

Clean UI: Kategorien-Chips, Rollen-Badges

Visuelles Feedback: Farben abhängig von Rollen/Kategorien

Accessibility: große Touch-Zonen, Screenreader-Support



---

8. CI/CD & Deployment

Entwicklung: GitHub Repo

CI: Lint + Tests + Build via GitHub Actions

Deploy: Firebase Hosting (Web), Play Store, App Store

Versionierung: Semantic Versioning (1.0.0 MVP)



---

9. Roadmap

MVP (1.0.0): Auth, Haushalt, Rollen mit Farben, Kalender, Events, Kategorien, Push

1.1.0: ICS Import/Export, Geburtstags-Tab mit Altersberechnung

1.2.0: Aufgabenlisten, Statistiken

2.0.0: Externe Integrationen (Google, Outlook), Widget-Integration



---

10. Zielbild

Eine extrem gut aussehende, intuitive Kalender-App für Paare und Familien, die:

Rollen frei benennen und farblich darstellen kann

Kategorien für Events bietet

Geburtstage automatisch verwaltet und Alter berechnet

schneller und schlanker als Google Calendar wirkt

visuell modern (ShadCN/Tailwind inspiriert, Material 3 optimiert)

zuverlässig synchronisiert und offline nutzbar bleibt
