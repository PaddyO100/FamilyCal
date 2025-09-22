# Phase 3 & 4 – Kalenderkern, Events & Backend-Sicherheit

## Phase 3 – Kalenderkern & Events
- Wochen- und Tagesansichten ergänzen, inklusive Timeline mit Drag-Scroll.
- Ereignis-Erstellung über modalen Editor mit Kategorien, Teilnehmern, Erinnerungen und Wiederholungen.
- Rollen- und Mitgliederverwaltung direkt im Client erweiterbar, inklusive Einladungs-Token-Flow.
- Kalenderübergreifende Terminwahl und Filterung nach Kategorien.
- ICS-Import (via Cloud Function) und Export-Link in den Einstellungen integrieren.

## Phase 4 – Backend-Funktionen & Sicherheit
- Firebase Functions Projekt scaffolded mit Reminder-Scheduler, Pub/Sub-Worker, ICS-Import, Geburtstags-Updater und Cleanup-Job.
- Device-Token-Registrierung für FCM implementiert und in Firestore abgelegt.
- Firestore Security Rules gehärtet (Rollen, Admin-Checks, Einladungen, Terminberechtigungen).
- Setup-Dokumentation inkl. Funktionen-Deployment, Emulator-Konfiguration und Rollenverwaltung aktualisiert.
- Notifikations-Service verbindet Event-Erstellung mit Reminder-Funktion (Cloud Function Trigger).
