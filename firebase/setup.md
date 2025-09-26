# Firebase Schritt-für-Schritt-Anleitung

## Schnellstart für familycal-prod

1. **Voraussetzungen installieren**: Flutter ≥ 3.16, Node.js 20 LTS, Firebase CLI (`npm install -g firebase-tools`), FlutterFire CLI (`dart pub global activate flutterfire_cli`).
2. **CLI verbinden**:
	```powershell
	firebase login
	firebase use --add familycal-prod
	```
	Alias `prod` wählen. Optional einen zweiten Alias für ein Entwicklungsprojekt anlegen.
3. **Apps registrieren**: In der Firebase-Konsole Android (`app.familycal`), iOS (`app.familycal`) und Web anlegen sowie `google-services.json`/`GoogleService-Info.plist` herunterladen.
4. **Konfigurationsdateien platzieren**: `google-services.json` nach `frontend/android/app/`, `GoogleService-Info.plist` nach `frontend/ios/Runner/` kopieren.
5. **Flutter mit Firebase verbinden**:
	```powershell
	cd frontend
	flutterfire configure --project=familycal-prod --platforms=android,ios,macos,web --out=lib/services/firebase/firebase_options.dart
	cd ..
	```
6. **Cloud Functions vorbereiten**:
	```powershell
	cd firebase/functions
	npm install
	npm run build
	cd ..
	```
7. **Regeln & Funktionen deployen**:
	```powershell
	firebase deploy --only firestore:rules
	firebase deploy --only functions
	```
8. **Optional**: Emulator Suite starten (`firebase emulators:start --only firestore,functions,auth`).

Die folgenden Abschnitte enthalten weiterführende Details und optionale Schritte.

Diese Anleitung richtet sich an Projektbeteiligte, die die Firebase-Infrastruktur für FamilyCal von Grund auf einrichten möchten. Alle Schritte werden in der Reihenfolge ausgeführt, in der sie benötigt werden. Optional markierte Schritte können nach dem MVP erfolgen.

## Voraussetzungen
- Google Cloud/Firebase-Konto mit Berechtigung, Projekte anzulegen.
- Firebase CLI (`npm install -g firebase-tools`).
- Flutter SDK inkl. `dart`, `flutterfire_cli` (per `dart pub global activate flutterfire_cli`).
- Node.js ≥ 20 für Cloud Functions.

## 1. Firebase-Projekt anlegen
1. Öffne [https://console.firebase.google.com](https://console.firebase.google.com) und klicke auf "Projekt hinzufügen".
2. Vergib einen Projektnamen, z. B. `familycal-prod`. Optional: verknüpfe ein Google-Analytics-Konto.
3. Warte bis die Erstellung abgeschlossen ist.

> Für lokale Entwicklung empfiehlt sich ein zweites Projekt, z. B. `familycal-dev`.

## 2. Firebase CLI konfigurieren
```bash
firebase login
firebase use --add familycal-dev
```
Wiederhole `firebase use --add` für das Produktionsprojekt und wähle sprechende Aliase (`dev`, `prod`).

## 3. App-Registrierungen erstellen
Wechsle in der Firebase-Konsole zu **Build → Authentication** und klicke auf die Android-, iOS- und Web-Icons, um Apps anzulegen.

### Android-App
1. Paketname: `app.familycal` (für Debug `app.familycal.dev`).
2. Optional: App-Nickname vergeben.
3. SHA-1- und SHA-256-Fingerprints für Debug/Release hinterlegen (aus Android Studio oder `gradlew signingReport`).
4. `google-services.json` herunterladen und in `frontend/android/app/` ablegen.

### iOS-App
1. Bundle Identifier: `app.familycal` (Debug: `app.familycal.dev`).
2. Team-ID eintragen (Apple Developer Account).
3. `GoogleService-Info.plist` herunterladen und in `frontend/ios/Runner/` ablegen.

### Web-App (PWA)
1. App-Nickname, z. B. `FamilyCal Web`.
2. Firebase SDK-Snippet kopieren und in `.env` bzw. `lib/services/firebase/firebase_options.dart` verwenden (siehe Schritt 5).

## 4. Authentication aktivieren
1. Gehe zu **Build → Authentication → Sign-in-Methode**.
2. Aktiviere **E-Mail/Passwort**.
3. Optional (Phase 2+): Aktiviere **Google** oder weitere Provider.
4. Konfiguriere E-Mail-Vorlagen (Absenderadresse, Branding).

## 5. Firestore-Datenbank einrichten
1. Navigiere zu **Build → Firestore-Datenbank**.
2. Wähle **Produktion** als Sicherheitsstufe.
3. Setze den Standort auf `europe-west` (oder Region nach Bedarf, für geringere Latenz).
4. Erstelle die in der README beschriebenen Collections. Nutze z. B. das Firestore-UI oder importiere per Skript.
5. Hinterlege Security Rules (siehe `firebase/firestore.rules`).

## 6. Cloud Functions initialisieren
Im Ordner `firebase/functions` liegt ein vorkonfiguriertes TypeScript-Projekt mit folgenden Funktionen:

- `scheduleEventReminders` (Callable): legt Reminder-Dokumente in `scheduledReminders` an.
- `reminderWorker` (Pub/Sub, minütlich): sendet FCM-Notifications an registrierte Tokens.
- `importIcs` (Callable): importiert ICS-Feeds in einen Kalender.
- `birthdayUpdater` (täglich 02:00 Uhr): aktualisiert die Alters-/Terminangaben in `birthdays`.
- `aggregateAvailabilities` (Firestore Trigger): aggregiert Tagesverfügbarkeiten in `availabilitySummaries`.
- `taskReminderWorker` (täglich 07:00 Uhr): erinnert zugewiesene Mitglieder an überfällige Aufgaben.
- `cleanup` (täglich 03:30 Uhr): löscht abgelaufene Einladungen und erledigte Reminder.

> Hinweis: Für `watchHouseholdTasks` (Sortierung nach `isCompleted` + `dueDate`) sowie `aggregateAvailabilities` werden Firestore-Indizes benötigt. Die CLI meldet fehlende Indizes mit Direktlinks.

### Installation & lokale Entwicklung
```bash
cd firebase/functions
npm install
npm run build
firebase emulators:start --only functions,firestore,auth
```

### Deployment
```bash
firebase deploy --only functions
```

## 7. Cloud Messaging (FCM) konfigurieren
1. Gehe zu **Build → Cloud Messaging**.
2. Notiere den Server-Schlüssel und Sender-ID.
3. Hinterlege die Werte in den Firebase-Konfigurationen für Mobile/Web.
4. (Optional) Richte APNs-Schlüssel/Zertifikate für iOS-Push ein.

> Hinweis: Nach erfolgreicher Einrichtung kann die App unter **Einstellungen → Benachrichtigungen** FCM-Tokens registrieren. Die Functions lesen und schreiben dazu in `deviceTokens/{uid}/tokens/{tokenId}`.

## 8. Hosting für Web-PWA
```bash
firebase init hosting
```
- Public Directory: `build/web` (Flutter Web Output).
- Single Page App: `y`.
- GitHub Actions Deployment konfigurieren (`firebase init hosting:github`).

## 9. Storage (Optional für ICS-Dateien/Anhänge)
1. Aktiviere **Storage** in der Konsole.
2. Setze Regeln, die Uploads auf Mitglieder eines Haushalts beschränken.

## 10. Projekt lokal verbinden
Im Repo-Root:
```bash
firebase init
```
- Wähle Firestore, Functions, Hosting, Emulators (für lokale Entwicklung).
- Erstelle `firebase.json`, `.firebaserc` und Emulator-Konfigurationen.

## 11. Flutter mit Firebase verbinden
Wechsle in den `frontend/`-Ordner:
```bash
flutterfire configure --project=familycal-dev --out=lib/services/firebase/firebase_options.dart
```
- Wiederhole den Schritt für Produktion (Parameter `--project=familycal-prod --out=lib/services/firebase/firebase_options_prod.dart`).
- Binde `DefaultFirebaseOptions.currentPlatform` in `main.dart` ein.

## 12. Emulator Suite (Optional)
```bash
firebase emulators:start
```
Stelle sicher, dass Firestore, Auth und Functions lokal laufen. Trage die Emulator-Ports in den Flutter-Services ein, wenn `kDebugMode` aktiv ist.

## 13. Deployment Smoke-Test
1. Flutter Web Build erstellen: `flutter build web`.
2. Hosting-Preview deployen: `firebase hosting:channel:deploy staging --only hosting`.
3. Prüfe die App-Registrierungen für Android/iOS mit `flutter run` auf den entsprechenden Plattformen.

## 14. Secrets & CI/CD
- Speichere Firebase-CLI-Token als GitHub Action Secret `FIREBASE_TOKEN`.
- Hinterlege Apple/Play-Store-Credentials für spätere Deployments.
- Lege `.env`-Dateien für lokale Entwicklung an (`frontend/.env.example`).
- Aktiviere das Workflow-Deployment (`.github/workflows/flutter_ci.yml`) und verknüpfe es mit Firebase Hosting (Preview & Live).
- Befolge vor jedem Release die Schritte in [`docs/release_checklist.md`](../docs/release_checklist.md).
- Ergänze optionale Secrets für Functions (`ICS_IMPORT_URLS`, SMTP etc.), falls Reminder/Import automatisiert laufen sollen.

Nach Durchführung dieser Schritte ist Firebase vollständig vorbereitet, damit die Flutter-App mit Authentifizierung, Firestore, Functions, Messaging und den neuen Reminder-/ICS-Workflows interagieren kann.
