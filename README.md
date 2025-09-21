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

invites/{token}: Einladungen für neue Mitglieder (nur Admin)

deviceTokens/{uid}/{tokenId}: Push-Token



---

5. Backend-Logik (Firebase Functions)

scheduleEventReminders: Erstellt Reminder-Jobs pro Teilnehmer

reminderWorker: Läuft jede Minute, versendet Push-Notifikationen

importICS: ICS-Dateien parsen und in Events konvertieren

birthdayUpdater: erstellt jährliche Geburtstags-Events, aktualisiert Alter

cleanup: Alte/canceled Events bereinigen


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
      views/ (Month, Week, Day, Agenda, BirthdayTab)
      controllers/ (Firestore Streams, RRULE Parser)
      widgets/ (EventCard, EventEditor, CategoryChips, ColorPicker)
  services/
    firestore_service.dart
    functions_service.dart
    notifications_service.dart
  models/
    user.dart
    household.dart
    calendar.dart
    event.dart
    role.dart
    birthday.dart
    recurrence.dart
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