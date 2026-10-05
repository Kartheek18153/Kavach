# Kavach — Scam Call Shield

Telugu-first live scam-call protection (Flutter + Dart Shelf backend).
Listens with you on speaker, scores fraud patterns live, warns on danger.

## Features
- Home / Live / Family / Report flow with EN/TE/HI
- Live danger meter (Safe 0-30 / Caution 31-60 / Danger 61+), waveform, transcript
- Rule engine: authority/threat/secrecy/urgency/sensitive/remote/money + hard-trigger + safe-word -20
- Stateful backend sessions with offline local fallback
- Family: guardian name/phone/safe-word (persisted), SMS alert via `sms:` intent
- Report: tap to dial 1930, open cybercrime.gov.in, copy summary, call history (last 20)
- Privacy: no recording, transcript cleared on hang-up

## Run app
```sh
flutter pub get
flutter run
# Android emulator -> local backend:
flutter run --dart-define=KAVACH_API=http://10.0.2.2:8080
# Real device (same Wi-Fi, use PC LAN IP):
flutter run --dart-define=KAVACH_API=http://192.168.1.10:8080
```

## Run backend
```sh
cd backend
dart pub get
dart run bin/server.dart
```

## API
- `GET /health`
- `POST /api/session/start` `{"mode":"scam"|"normal"}`
- `POST /api/score` `{"sessionId":"...","text":"...","safeWord":"..."}`
- `POST /api/session/end` `{"sessionId":"..."}`

## Tests
```sh
flutter test
cd backend && dart test
```
