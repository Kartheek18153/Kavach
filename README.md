# CyberSafe — Scam Call Shield

Telugu-first live scam-call protection (Flutter + Dart Shelf backend).
Listens with you on speaker, scores fraud patterns live, warns on danger.

## Features
- Home / Live / Family / Report flow with EN/TE/HI
- Live danger meter (Safe 0-30 / Caution 31-60 / Danger 61+), waveform, transcript
- Rule engine: Tier-1 tactic engine (ported from KAVACH_IQOO, Apache-2.0) —
  5 tactic families, 180 trilingual markers (EN/Hinglish/Devanagari),
  40 negative guards, decay + diversity rule; danger needs 3+ families.
- Corpus-tested: 10 scam scripts reach Danger, 8 legit calls stay silent.
- Stateful backend sessions with offline local fallback
- Family: guardian name/phone/safe-word (persisted), SMS alert via `sms:` intent
- Report: tap to dial 1930, open cybercrime.gov.in, copy summary, call history (last 20)
- Privacy: no recording, transcript cleared on hang-up
- QR & UPI engine: known-suspect blocklist, impersonation/typosquat/random-handle checks, reverse-collect (PAY/RECEIVE toggle), mandate-hijack floor, tamper guards (ported rule-for-rule from Btech-Crafts/hackathon2026, bands stay Safe 0-30 / Caution 31-60 / Danger 61+)

## Run app
```sh
flutter pub get
flutter run
# Android emulator -> local backend:
flutter run --dart-define=CYBERSAFE_API=http://10.0.2.2:8080
# Real device (same Wi-Fi, use PC LAN IP):
flutter run --dart-define=CYBERSAFE_API=http://192.168.1.10:8080
# Optional AI second opinion (Agnes 2.5 Flash, opt-in in Settings):
flutter run --dart-define=CYBERSAFE_API=http://10.0.2.2:8080 --dart-define=AGNES_API_KEY=sk-...
```
The Agnes key is compile-time only (`--dart-define`) and is never
committed to git. Without it (or with the Settings toggle off) the AI
cards stay hidden and everything works offline on the rule engine.

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
- `POST /api/sim-swap/check` `{"phoneNumber":"+919876543210","lookbackHours":72}` (telco SIM-swap signal)
- `POST /api/sim-swap/retrieve-date` `{"phoneNumber":"..."}`

## Tests
```sh
flutter test
cd backend && dart test
```
