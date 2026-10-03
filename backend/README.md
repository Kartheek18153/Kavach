# Kavach backend

Live scam-call scoring sessions + family alerts for the Kavach Flutter app.

## Run

```sh
cd backend
dart pub get
dart run bin/server.dart
# or: PORT=8081 dart run bin/server.dart
```

With real Telegram family alerts:

```sh
TELEGRAM_BOT_TOKEN=<botfather-token> dart run bin/server.dart
```

## API

- `GET /health` — `{ok, service, sessions, telegram}`
- `POST /api/session/start` — `{"mode":"scam"|"normal"}` → `{sessionId, risk, level, ...}`
- `POST /api/score` — `{"sessionId":"...","text":"..."}` → `{points, flagged, risk, level, scamType, reasons, reasonsTelugu, alerted}`. Omit `sessionId` for a stateless single-line score.
- `POST /api/session/end` — `{"sessionId":"..."}` → final summary (+ `elapsedSec`).
- `POST /api/alert` — `{"chatId":"...","message":"..."}` → `{sent, via}`. Without a bot token the alert is logged and `via` is `"log"`.

Levels are `safe` (0-30), `caution` (31-60), `danger` (61+) — same bands as the app.
