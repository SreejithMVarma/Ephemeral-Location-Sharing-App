# Quick Start (5 Minutes)

For the impatient: Get Ephemeral Radar MVP running in 5 minutes.

## Prerequisites Checklist

- [ ] Python 3.12+: `python3 --version`
- [ ] Flutter 3.10.4+: `flutter --version`
- [ ] Git: `git --version`
- [ ] Docker: `docker --version` (optional, for Redis)

## Terminal 1: Start Redis

```bash
# Using Docker (recommended)
docker run -d -p 6379:6379 redis:7

# Or local (if installed)
redis-server
```

## Terminal 2: Start Backend

```bash
cd "d:\work\projects\Ephemeral Location Sharing App\apps\backend"

# Setup (one-time)
python3 -m venv .venv
source .venv/bin/activate  # or .\.venv\Scripts\Activate.ps1 on Windows
pip install poetry
poetry install

# Create .env file with:
cat > .env << EOF
API_BASE_URL=http://localhost:8000
APP_ENV=development
DEEP_LINK_SCHEME=ephemeral-radar
REGION_WS_URLS={"us-east": "ws://localhost:8000"}
CORS_ALLOWED_ORIGINS=["http://localhost:8000"]
REDIS_URL=redis://127.0.0.1:6379/0
REDIS_MAX_CONNECTIONS=100
REDIS_ENABLE_KEYSPACE_LISTENER=true
FCM_SENDER_ID=dummy
SENTRY_DSN=
EOF

# Run
export PYTHONPATH=./src
poetry run uvicorn src.main:app --reload --port 8000
```

You should see:
```
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8000
```

## Terminal 3: Start Flutter

```bash
cd "d:\work\projects\Ephemeral Location Sharing App\apps\mobile"

# Setup (one-time)
flutter pub get

# Create .env.development with:
cat > .env.development << EOF
API_BASE_URL=http://localhost:8000
WS_BASE_URL=ws://localhost:8000
REGION_WS_URLS={"us-east":"ws://localhost:8000/ws"}
BUILD_FLAVOR=development
APP_VERSION=0.1.0
EOF

# Run
flutter run --flavor development --dart-define-from-file=.env.development
```

## Test the Flow

**On your device/emulator:**

1. Tap **Create a Radar**
2. Enter session name and your name
3. Tap **Generate QR**
4. Go back and join that same session (manually enter session ID + passkey)
5. Grant location permission
6. **You should see yourself on the radar!**

On a second device, repeat with the same session ID + passkey.

## Verify It Works

- Backend health check:
  ```bash
  curl http://localhost:8000/api/v1/health
  ```

- WebSocket connection in Chrome DevTools:
  1. Open DevTools → Network → WS
  2. Look for WebSocket connection to `ws://localhost:8000/ws/...`
  3. Status should be "101 Switching Protocols"

## Common Commands

```bash
# Check if Redis is running
redis-cli ping  # Should respond: PONG

# Clear Redis
redis-cli FLUSHALL

# View backend logs
tail -f .logs/backend.log

# Stop servers
# Ctrl+C in each terminal

# Restart all
# Run the 3 terminal commands again
```

## Next: Full Documentation

See [MVP_SETUP.md](./MVP_SETUP.md) for:
- Detailed setup steps
- API reference
- WebSocket protocol
- Troubleshooting guide
- Two-device testing

---

**Status**: ✅ MVP Ready to Test
