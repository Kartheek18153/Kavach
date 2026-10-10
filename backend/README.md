# CyberSafe backend

Live scam-call scoring sessions for the CyberSafe Flutter app.

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
flutter run --dart-define=CYBERSAFE_API=http://10.0.2.2:8080
# Real phone on same Wi-Fi (use your PC LAN IP)
flutter run --dart-define=CYBERSAFE_API=http://192.168.1.10:8080
```

## API

- `GET /health` — `{ok, service, sessions}` (+ `simSwap` provider status)
- `POST /api/session/start` — `{"mode":"scam"|"normal"}` → `{sessionId, risk, level, ...}`
- `POST /api/score` — `{"sessionId":"...","text":"..."}` → `{points, flagged, risk, level, scamType, reasons, reasonsTelugu, alerted}`. Omit `sessionId` for a stateless single-line score.
- `POST /api/session/end` — `{"sessionId":"..."}` → final summary (+ `elapsedSec`).
- `POST /api/sim-swap/check` — `{"phoneNumber":"+919876543210","lookbackHours":72}` → `{status, riskSignal, simSwapDetected, maskedPhone, detail, evidence}` (CAMARA SimSwap port; our camelCase maps to upstream `{phoneNumber, maxAge}`)
- `POST /api/sim-swap/retrieve-date` — `{"phoneNumber":"..."}` → `{status, lastSwapAt, ...}`
- Simulator (volatile demo data): `GET /api/simulator/subscribers`, `POST /api/simulator/subscribers`, `POST /api/simulator/swaps`, `POST /api/simulator/reset`

Levels are `safe` (0-30), `caution` (31-60), `danger` (61+) — same bands as the app.

## SIM-swap telco check (GSMA Open Gateway / CAMARA)

Port of the `Kartheek18153/cyberSafe` FastAPI implementation into this
Shelf backend (`lib/sim_swap/`): mock → simulation → live bearer →
live `client_credentials` (+ single-poll CIBA, unverified). Outcomes are
honest by construction: `recent_sim_change` / `no_recent_change` /
`check_unavailable` / `unsupported_operation` — a failure never becomes
`simSwapDetected=false`, and only masked phones are logged/returned.

```sh
# Mock (default): numbers ending 0000 simulate a swap, all offline.
# Simulation (stateful demo, volatile): OG_AUTH_FLOW=simulation
# Live bearer (portal token, session-only, never committed):
$env:OG_AUTH_FLOW="bearer"
$env:OG_SIM_SWAP_BEARER_TOKEN="<portal-token>"
$env:OG_API_BASE_URL="https://open-gateway-sandbox.gsma.com/sim-swap/v1"
$env:OG_SIM_SWAP_API_VERSION="v1"
# Live OAuth: OG_AUTH_FLOW=client_credentials + OG_CLIENT_ID /
# OG_CLIENT_SECRET / OG_API_BASE_URL / OG_TOKEN_URL / OG_SIM_SWAP_SCOPE
```
