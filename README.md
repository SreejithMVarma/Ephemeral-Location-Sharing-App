# Ephemeral Radar - MVP Edition

**Real-time location sharing for friends. Ephemeral. No accounts. No tracking.**

This is the **Minimum Viable Product (MVP)** — a fully functional, stripped-down version focused on core features:
- ✅ Create/join sessions with a passkey
- ✅ Real-time location sharing via WebSocket
- ✅ Radar view to see other users
- ✅ Basic compass direction

**Build Status**: ✅ Ready to test  
**Version**: 0.1.0  
**Last Updated**: May 2024

---

## 📖 Documentation

### For Quick Start (5 minutes)
👉 [**QUICKSTART.md**](./QUICKSTART.md) - Get it running NOW

### For Complete Setup & Reference
👉 [**MVP_SETUP.md**](./MVP_SETUP.md) - Full guide with:
- Step-by-step setup for backend & frontend
- All API endpoints
- WebSocket protocol details
- Testing instructions
- Troubleshooting tips

---

## 🏗 Architecture

```
Ephemeral Radar MVP

Backend (FastAPI)
  ├── HTTP REST API
  │   ├── POST /api/v1/sessions (create)
  │   ├── GET /api/v1/sessions/verify (join)
  │   └── POST /api/v1/sessions/{id}/join
  ├── WebSocket Server
  │   ├── Connect: WS /ws/{session_id}?token={user_id}
  │   ├── Broadcast: LOCATION_UPDATE messages
  │   └── Cleanup: USER_CONNECTED / USER_DISCONNECTED
  └── Redis Backend
      ├── Session storage (Hashes)
      ├── Geo-spatial indexes (for locations)
      └── User profiles (Hashes)

Frontend (Flutter)
  ├── Session Setup Screen (create/join)
  ├── Location Service (sends position every 5s)
  ├── WebSocket Client (listens for updates)
  ├── Radar View (displays user locations)
  └── Compass View (shows direction to user)
```

---

## 🚀 Prerequisites

- **Python** 3.12+ ([install](https://www.python.org/downloads/))
- **Flutter** 3.10.4+ ([install](https://flutter.dev/docs/get-started/install))
- **Redis** (via Docker or local)
- **Git** (latest)

---

## ⚡ Quick Start (Choose One)

### Option 1: Docker Compose (Easiest)

```bash
docker-compose -f apps/backend/docker-compose.prod.yml up
```

Then in another terminal:
```bash
cd apps/mobile && flutter run --flavor development
```

### Option 2: Manual Setup (3 Terminals)

**Terminal 1: Redis**
```bash
docker run -p 6379:6379 redis:7
```

**Terminal 2: Backend**
```bash
cd apps/backend
python3 -m venv .venv
source .venv/bin/activate
pip install poetry
poetry install
export PYTHONPATH=./src
poetry run uvicorn src.main:app --reload --port 8000
```

**Terminal 3: Frontend**
```bash
cd apps/mobile
flutter pub get
flutter run --flavor development --dart-define-from-file=.env.development
```

---

## 🧪 Test the MVP

1. **On Device 1 (Alice)**
   - Tap **"Create a Radar"**
   - Enter session name: `Test`
   - Enter your name: `Alice`
   - Tap **"Generate QR"**

2. **On Device 2 (Bob)**
   - Tap **"Join a Radar"**
   - Scan the QR code shown by Alice (or manually enter Session ID + Passkey)
   - Tap **"Join"**

3. **Expected Result**
   - ✅ Both users visible on the Radar
   - ✅ Location updates in real-time
   - ✅ Can see each other moving

---

## 📚 What's Included

### Backend
- Session management (create, verify, join)
- WebSocket server with room-based broadcasting
- Redis for session & location storage
- Minimal logging (debugging only)
- **Removed**: Metrics, analytics, observability, rate limiting, privacy filtering

### Frontend
- Session setup screens
- Real-time WebSocket communication
- Location service integration
- Radar visualization
- **Removed**: Firebase, telemetry, analytics, complex state management

---

## 🔧 Configuration

### Backend (.env)

```env
API_BASE_URL=http://localhost:8000
REDIS_URL=redis://127.0.0.1:6379/0
DEEP_LINK_SCHEME=ephemeral-radar
CORS_ALLOWED_ORIGINS=["http://localhost:8000"]
REGION_WS_URLS={"us-east": "ws://localhost:8000"}
```

### Frontend (.env.development)

```env
API_BASE_URL=http://localhost:8000
WS_BASE_URL=ws://localhost:8000
BUILD_FLAVOR=development
```

---

## 🛠 Common Commands

```bash
# Backend
cd apps/backend
poetry run uvicorn src.main:app --reload --port 8000

# Frontend
cd apps/mobile
flutter run --flavor development --dart-define-from-file=.env.development

# Tests (Backend)
cd apps/backend
poetry run pytest tests/ -v

# Tests (Frontend)
cd apps/mobile
flutter test

# Redis check
redis-cli ping  # Should return: PONG
```

---

## ❌ What's NOT Included (MVP Simplification)

- 🚫 User accounts / authentication
- 🚫 Chat messaging
- 🚫 User profiles / avatars
- 🚫 Privacy modes
- 🚫 Animations / UI polish
- 🚫 Push notifications
- 🚫 Analytics / telemetry
- 🚫 Rate limiting
- 🚫 Metrics / observability
- 🚫 Advanced error recovery

These can be added in future versions.

---

## 📋 API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/sessions` | Create new session |
| GET | `/api/v1/sessions/verify?s={id}&p={passkey}` | Verify & get WebSocket URL |
| POST | `/api/v1/sessions/{id}/join` | Join existing session |
| WS | `/ws/{session_id}?token={user_id}` | Real-time location stream |
| GET | `/api/v1/health` | Health check |

See [MVP_SETUP.md](./MVP_SETUP.md) for full details.

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Check Redis
redis-cli ping  # Should say: PONG

# Check port
lsof -i :8000  # Kill if needed
```

### Frontend can't connect
- Verify backend is running: `curl http://localhost:8000/api/v1/health`
- Check environment variables in `.env.development`
- Clear Flutter cache: `flutter clean && flutter pub get`

### Location not updating
- Grant location permission on device
- Check device location services are enabled
- Verify WebSocket connection in browser DevTools

See [MVP_SETUP.md#troubleshooting](./MVP_SETUP.md#troubleshooting) for more.

---

## 📖 Full Documentation

For detailed instructions, see:
- [QUICKSTART.md](./QUICKSTART.md) - Get running in 5 min
- [MVP_SETUP.md](./MVP_SETUP.md) - Complete setup & reference

---

## 🎯 Next Steps

After MVP is working, consider:
1. Add user profiles & avatars
2. Implement chat messaging
3. Add session history
4. Optimize performance
5. Improve UI/UX
6. Add comprehensive tests
7. Set up CI/CD

---

## 📝 License

Copyright © 2024 Ephemeral Radar. All rights reserved.

---

**Status**: ✅ MVP Ready  
**Last Updated**: May 1, 2024  
**Questions?** See [MVP_SETUP.md#troubleshooting](./MVP_SETUP.md#troubleshooting)

```bash
# Clean build artifacts
flutter clean
flutter pub get
flutter pub upgrade

# Rebuild
flutter run
```

### WebSocket 101 Upgrade Fails

Ensure backend is running with WebSocket enabled:

```bash
# Check logs for "Uvicorn running on"
# Verify wscat works:
wscat -c ws://localhost:8000/ws/test?token=...
```

## Next Steps

- **Explore the roadmap**: [ephemeral_radar_engineering_roadmap.html](../ephemeral_radar_engineering_roadmap.html)
- **Read architecture**: [docs/ARCHITECTURE.md](ARCHITECTURE.md)
- **API reference**: [docs/api.md](api.md)
- **Contributing**: [docs/CONTRIBUTING.md](CONTRIBUTING.md)

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/ephemeral-radar/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/ephemeral-radar/discussions)
- **Contact**: [privacy@radarapp.io](mailto:privacy@radarapp.io)

---

**Status**: In Active Development  
**Last Updated**: April 2, 2026  
**License**: MIT
