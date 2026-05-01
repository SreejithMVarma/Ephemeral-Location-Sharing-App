# Environment Reference

## Global Keys

| Key | Type | Required | Example | Description |
| --- | --- | --- | --- | --- |
| API_BASE_URL | string(url) | yes | https://api.radarapp.io | Backend HTTP base URL for mobile clients |
| FCM_SENDER_ID | string | yes | 1234567890 | Firebase sender id used by mobile push registration |
| DEEP_LINK_SCHEME | string | yes | radarapp | URI scheme for deep links |
| REGION_WS_URLS | json map | yes | {"us-east":"wss://api.radarapp.io/ws"} | Region to WebSocket endpoint mapping |
| CORS_ALLOWED_ORIGINS | json list | yes | ["https://radarapp.io"] | FastAPI CORS allow-list |
| REDIS_URL | string(url) | yes | redis://localhost:6379/0 | Backend Redis connection URI |
| APP_ENV | string | yes | development | Runtime environment name |

## Validation Rules

- Backend fails startup when required keys are missing.
- Mobile fails fast at app start when required `--dart-define` keys are missing.
- `API_BASE_URL` must use `https://` for staging and production builds.

## Mobile Development Profiles

- `apps/mobile/env/dev.json`: Android emulator profile, uses `10.0.2.2` for host access.
- `apps/mobile/env/dev.phone.json`: USB-connected Android device profile, uses `127.0.0.1` with `adb reverse tcp:8000 tcp:8000`.
