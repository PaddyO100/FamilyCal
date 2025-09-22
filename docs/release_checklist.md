# Release-Checkliste – FamilyCal 1.0.0+

Diese Checkliste begleitet Phase 5 und dient als Vorlage für jeden Release-Kandidaten.

## Vorbereitung
- [ ] GitHub-Projektboard aktualisieren (alle Blocker geklärt, Bugs priorisiert).
- [ ] Firebase Emulator Suite starten (`firebase emulators:start`) und kritische Flows gegen Staging-Daten testen.
- [ ] `flutter analyze` und `flutter test` lokal sowie in CI erfolgreich.
- [ ] Release-Notes im Format `docs/releases/<version>.md` verfassen.
- [ ] Version in `pubspec.yaml` anheben und Changelog ergänzen.

## QA & Beta
- [ ] Interner QA-Build (Android/iOS) via `flutter build apk/ipa` erzeugen und im Team verteilen.
- [ ] Web-PWA auf Staging-Hosting deployen (`firebase hosting:channel:deploy staging`).
- [ ] Smoke-Tests in unterschiedlichen Zeitzonen (Recurrence, Erinnerungen, Geburtstage, Verfügbarkeiten, Tasks).
- [ ] Crashlytics- und Analytics-Dashboards prüfen.

## Rollout
- [ ] Release-Tag setzen (`git tag vX.Y.Z` + `git push origin --tags`).
- [ ] Mobile Stores einreichen (Google Play Console, App Store Connect).
- [ ] PWA über `firebase hosting:channel:deploy live` veröffentlichen.
- [ ] Monitoring aktivieren und Feedback-Kanäle beobachten.

## Post-Release
- [ ] Known-Issues-Liste aktualisieren.
- [ ] Roadmap für Folgeversion (1.1.0, 1.2.0, 2.0.0) validieren.
- [ ] Retrospektive organisieren.
