# Phase 0 – Projektgrundlagen & Planung

Diese Phase fasst die Anforderungen aus der Projektvision zusammen und bildet die Arbeitsgrundlage für die folgenden Umsetzungsschritte.

## Produktvision
- **Zielgruppe:** Familien und Haushalte, die Termine gemeinsam koordinieren möchten.
- **Kernnutzen:** Moderner, schneller Kalender mit frei definierbaren Rollen, intuitiver Oberfläche und zuverlässiger Offline-Synchronisation.
- **Plattformen:** Android, iOS und Web (PWA) mit einem gemeinsamen Flutter-Code-Base.

## Leitplanken & Prinzipien
1. **Design**
   - Material 3 Komponenten mit ShadCN/Tailwind-inspirierten Layouts.
   - Farbcodierte Rollen- und Kategorien-Badges, große Touch-Zonen, Screenreader-Kompatibilität.
2. **Architektur**
   - Feature-orientierte Ordnerstruktur (`auth`, `household`, `calendar`, `settings`).
   - Trennung zwischen Präsentation, Services, Modellen und Hilfsfunktionen.
   - Firebase als Managed Backend (Auth, Firestore, Functions, Messaging, Hosting).
3. **Produktinkremente**
   - Iterativer Ausbau: MVP → 1.1.0 → 1.2.0 → 2.0.0 laut README-Roadmap.

## Funktionsumfang MVP (1.0.0)
- Authentifizierung und Haushaltsverwaltung mit genau einem Admin.
- Rollenverwaltung inklusive Farbauswahl.
- Mehrere Kalender pro Haushalt, Events mit Kategorien, Wiederholungen, Ausnahmen und Erinnerungen.
- Geburtstagsübersicht, Verfügbarkeiten und ICS-Import/-Export (Grundfunktionalität vorbereiten).
- Push-Benachrichtigungen via FCM, Offline-Modus mit Konfliktlösung.

## Anforderungen an das Datenmodell
- `users`, `households`, `memberships`, `calendars`, `events`, `birthdays`, `availabilities`, `invites`, `deviceTokens` gemäß README.
- Sicherheitsregeln erzwingen Admin-Einladungen und Schreibrechte für Haushaltsmitglieder.

## Deliverables Phase 0
- Gemeinsames Verständnis dokumentiert (dieses Dokument).
- Definitions of Done für die folgenden Phasen:
  - **Phase 1:** Technisches Grundgerüst, Build- und Infrastruktur-Setup.
  - **Phase 2:** MVP-Basisfunktionen für Auth, Haushalte, Kalender inklusive Datenmodelle und Services.
