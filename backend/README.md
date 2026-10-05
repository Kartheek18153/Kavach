# Kavach backend

Live scam-call scoring sessions for the Kavach Flutter app.

## Run

```sh
cd backend
dart pub get
dart run bin/server.dart
# or: PORT=8081 dart run bin/server.dart
```

Sessions older than 30 min are pruned every 5 min (cap 500).

## Point the app at it

```sh
# Android emulator -> host PC
flutter run --dart-define=KAVACH_API=http://10.0.2.2:8080
# Real phone on same Wi-Fi (use your PC LAN IP)
flutter run --dart-define=KAVACH_API=http://192.168.1.10:8080
```

## API

- `GET /health` — `{ok, service, sessions}`
- `POST /api/session/start` — `{"mode":"scam"|"normal"}` → `{sessionId, risk, level, ...}`
- `POST /api/score` — `{"sessionId":"...","text":"..."}` → `{points, flagged, risk, level, scamType, reasons, reasonsTelugu, alerted}`. Omit `sessionId` for a stateless single-line score.
- `POST /api/session/end` — `{"sessionId":"..."}` → final summary (+ `elapsedSec`).

Levels are `safe` (0-30), `caution` (31-60), `danger` (61+) — same bands as the app.
