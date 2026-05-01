# Architecture Documentation

## System Overview

Ephemeral Radar is a real-time location-sharing app built on Flutter (mobile) and FastAPI (backend) with Redis for session state.

### Core Principles

1. **Ephemeral**: No persistent user database. All data deleted after session termination or 12-hour TTL.
2. **Privacy-First**: Zero location data in logs, FCM payloads contain only message type/session ID.
3. **Real-Time**: WebSocket-based broadcasting with sub-200ms location update latency.
4. **Scalable**: Stateless FastAPI backends behind load balancer, Redis as single source of truth.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile Clients (Flutter)                  │
│  ┌──────────────── Session 1 ─────────────────┐             │
│  │  Alice (Radar)  Bob (Radar)  Charlie (Radar) │             │
│  └──────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────┘
                          │ HTTPS REST + WSS
                          │
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway / Nginx                        │
│  (TLS termination, rate limiting, WS upgrade header proxy)   │
└─────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
    ┌───────┐         ┌───────┐        ┌────────┐
    │Backend│         │Backend│        │Backend │
    │ Pod 1 │         │ Pod 2 │        │ Pod 3  │
    └───────┘         ───────┘        └────────┘
        │                 │                 │
        ├─────────────────┼─────────────────┤
        │                 │                 │
        └──────────────┬──┴──┬──────────────┘
                       │     │
                   ┌───────────┐
                   │   Redis   │
                   │   Master  │
                   └───────────┘
```

## Component Details

### Backend (FastAPI)

**Directory Structure**
```
apps/backend/
├── src/
│   ├── main.py                 # App initialization, middleware, routers
│   ├── core/
│   │   ├── config.py           # Pydantic BaseSettings
│   │   ├── security.py         # JWT token creation/validation
│   │   ├── logging.py          # JSON structured logging with PII sanitization
│   │   ├── rate_limit.py       # Redis-backed rate limiting
│   │   └── exceptions.py       # Domain exception types
│   ├── api/v1/
│   │   └── routes/
│   │       ├── sessions.py     # Session CRUD endpoints
│   │       ├── auth.py         # Token endpoints
│   │       └── compliance.py   # Privacy policy endpoint
│   ├── services/
│   │   ├── websocket_service.py  # WebSocket room management
│   │   ├── broadcaster.py        # Message distribution
│   │   └── notifications.py      # FCM integration
│   ├── repositories/
│   │   ├── session_repository.py # Session data layer with cascade cleanup
│   │   └── redis_repository.py   # Base Redis operations
│   ├── models/
│   │   └── session.py            # Pydantic request/response models
│   └── infrastructure/
│       ├── redis_client.py       # Redis async client & connection pool
│       ├── middleware.py         # Request context, cache, rate limiting
│       └── metrics.py            # Prometheus metrics
├── tests/
│   ├── api/
│   │   └── test_session_lifecycle.py
│   ├── services/
│   │   └── test_notifications.py
│   └── core/
│       └── test_logging.py
├── Dockerfile                  # Multi-stage build
├── docker-compose.prod.yml     # Prod stack with Redis
└── pyproject.toml
```

**Key Flows**

1. **Create Session**
   - POST /sessions → generate UUIDv4 + passkey → HSET in Redis with 12h TTL → return deep link
   
2. **Join Session**
   - POST /join → verify passkey → SADD user to members set → set user profile → emit USER_CONNECTED broadcast

3. **Location Update**
   - WS LOCATION_UPDATE → validate privacy mode → GEOADD to Redis → check proximity (GEORADIUSBYMEMBER) → enqueue FCM if threshold crossed → broadcast to room with privacy filter applied
   
4. **Session Termination (Admin)**
   - DELETE /sessions/{id} → verify admin token → delete all session:* keys (cascade pipeline) → broadcast SESSION_ENDED → emit metrics decrement

5. **TTL Expiry Cascade**
   - Redis keyspace notification triggers on session:{id} expiry → on_expired_key hook → delete_session_cascade cleanup

### Mobile (Flutter)

**Directory Structure**
```
apps/mobile/
├── lib/
│   ├── main.dart                        # App initialization, Firebase setup
│   ├── core/
│   │   ├── app_config.dart              # Compile-time config injection
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   └── app_tokens.dart
│   │   ├── widgets/
│   │   │   ├── radar_button.dart
│   │   │   ├── radar_card.dart
│   │   │   └── ... (design system components)
│   │   ├── feature_flags/
│   │   │   └── remote_config_service.dart
│   │   ├── error_handling/
│   │   │   ├── error_messages.dart
│   │   │   └── retry.dart
│   │   └── telemetry/
│   │       └── telemetry_service.dart
│   └── features/
│       ├── session/
│       │   ├── presentation/
│       │   │   ├── entry_screen.dart
│       │   │   ├── join_screen.dart
│       │   │   ├── waiting_room_screen.dart
│       │   │   ├── privacy_sheet.dart
│       │   │   └── blurred_radar_blocker.dart
│       │   ├── application/
│       │   │   ├── privacy_providers.dart
│       │   │   └── rejoin_service.dart
│       │   ├── domain/
│       │   │   ├── deep_link_payload.dart
│       │   │   └── session.dart
│       │   └── infrastructure/
│       │       ├── notification_service.dart
│       │       ├── permission_service.dart
│       │       ├── network_providers.dart   # Dio, WS, appLifecycleObserver, remoteConfig
│       │       └── api_client.dart
│       ├── radar/
│       │   ├── presentation/
│       │   │   └── radar_view.dart
│       │   ├── application/
│       │   │   └── radar_providers.dart
│       │   └── domain/
│       │       └── radar_blip.dart
│       ├── compass/
│       │   ├── presentation/
│       │   │   └── compass_view.dart
│       │   ├── domain/
│       │   │   └── bearing_utils.dart
│       │   └── infrastructure/
│       │       └── location_service.dart
│       └── chat/
│           └── presentation/
│               └── chat_overlay.dart
├── test/
│   ├── features/                        # Feature-specific tests
│   ├── widget_test.dart                 # Integration tests
│   └── ... (unit tests)
├── pubspec.yaml
└── android/
    ├── app/src/main/AndroidManifest.xml  # Permissions, notification channels
    └── google-services.json
```

**Firebase Integration**

- **Firebase Core**: Initialization in runZonedGuarded with error capture in main.dart
- **Firebase Messaging**: Post-join registration + token refresh binding
- **Firebase Crashlytics**: Uncaught exception capture + custom keys (hashed session ID)
- **Firebase Analytics**: Event logging (session_joined, privacy_mode_changed)
- **Firebase Remote Config**: Feature flag fetches on app resume, fallback values in code

**State Management (Riverpod)**

- AppConfig provider: injected from main.dart overrides
- NetworkProviders: dio, websocket, notification, remote config, appLifecycleObserver
- FeatureFlags: remote config with fallback defaults
- Notifiers: Privacy mode, location stream, radar blips, compass bearing

### Redis Schema

```
session:{id}
  ├── session_id (string)
  ├── session_name (string)
  ├── admin_id (string)
  ├── chat_enabled (string/bool)
  ├── region (string)
  └── passkey (string) [TTL: 12h]

session:{id}:members
  └── SET of user_ids [TTL: 12h]

session:{id}:locations
  └── GEOHASH sorted set user_id → (lng, lat) [TTL: 12h]

session:{id}:chat:global
  └── list of JSON message objects [TTL: 12h, max 200 items]

session:{id}:chat:dm:{u1}:{u2}
  └── list of JSON DM objects [TTL: 12h, max 200 items]

session:{id}:path:{user_id}
  └── stream with entries: lat, lng, ts [TTL: 12h]

user:{id}
  ├── display_name (string)
  ├── avatar (string/URL)
  ├── privacy_mode (string)
  ├── current_session (string)
  ├── fcm_token (string)
  └── (no TTL — cleaned up on session leave)

user:{id}:blocklist:{session_id}
  └── set timestamp (for duration-based unblock)

ratelimit:{type}:{key}
  └── integer counter [TTL: 60s or 1s per limit]
```

### Security Model

**Authentication** (JWT RS256)
- Issued on `/auth/token` with {user_id, session_id} in claims
- Token exp: 24 hours (matching session TTL)
- Signed with private key, verified with public key (JWKS endpoint)

**Privacy Filtering**
- Server applies privacy_mode before broadcast: direction_only (no lat/lng), direction_distance (distance only), full_map (all data)
- Applied on sender side in database write, not on mobile (mobile cannot bypass device-side filter)

**Rate Limiting**
- Per-IP on public endpoints (create, verify)
- Per-user on WS (1/s location updates)
- Uses Redis INCR with expiry for atomic counters

**Data Minimization**
- No persistent user profiles (cleaned up on session leave)
- Logs stripped of GPS coordinates via regex sanitizer
- FCM payloads contain zero PII (only message type + session_id)

## Deployment Architecture

**Kubernetes / Docker Compose**

```
Frontend Ingress (TLS)
    ↓
  Nginx (reverse proxy, WS upgrade, rate limit)
    ↓
FastAPI Pods (stateless)
    ↓
Redis (single instance or cluster)
    ↓
Prometheus (metrics scrape)
    ↓
Grafana (dashboards)
```

**Observability**

- **Logging**: JSON structured logs shipped to Cloud Logging / Datadog
- **Metrics**: Prometheus scrape on /metrics, Grafana dashboards
- **Tracing**: Request ID propagated across mobile/backend
- **Errors**: Sentry for backend exceptions, Crashlytics for mobile

## Performance Characteristics


---

## Development Setup

### Prerequisites

#### Backend

- Python 3.12+
- Redis 7.0+
- Docker & Docker Compose
- OpenSSL (for JWT key generation)

#### Mobile

- Flutter 3.19+
- Dart 3.3+
- Android SDK 24+ or iOS 14.0+
- Xcode 15+ (macOS) or Android Studio (cross-platform)

#### Infrastructure

- kubectl / Docker Compose CLI
- Terraform (if using cloud provisioning)
- gcloud / az CLI (cloud provider)

### Backend Setup

#### 1. Clone and Install Dependencies

```bash
git clone https://github.com/ephemeral-radar/backend.git
cd apps/backend

python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

#### 2. Configure Environment

```bash
cp .env.example .env

# Edit .env with your values:
# - REDIS_URL=redis://localhost:6379
# - JWT_SECRET_KEY=<generate with `openssl rand -hex 32`>
# - FIREBASE_KEY_JSON=<path to Firebase service account JSON>
# - CORS_ALLOWED_ORIGINS=["http://localhost:8080","https://radarapp.io"]
```

#### 3. Generate JWT Keys

```bash
# Generate RSA keypair (2048-bit)
openssl genrsa -out private_key.pem 2048
openssl rsa -in private_key.pem -pubout -out public_key.pem

# Add paths to .env:
# JWT_PRIVATE_KEY_PATH=private_key.pem
# JWT_PUBLIC_KEY_PATH=public_key.pem
```

#### 4. Start Redis

```bash
# Option A: Docker
docker run -d \
  -p 6379:6379 \
  --name redis \
  redis:7-alpine \
  redis-server --in-memory-db

# Option B: Docker Compose
docker-compose -f docker-compose.dev.yml up redis

# Verify connectivity:
redis-cli ping  # Should return PONG
```

#### 5. Run Tests

```bash
pytest apps/backend/tests -v --cov

# Expected: All tests pass, coverage > 85%
```

#### 6. Start Backend

```bash
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Interactive docs: http://localhost:8000/docs
# ReDoc: http://localhost:8000/redoc
```

### Mobile Setup

#### 1. Clone and Install Dependencies

```bash
cd apps/mobile
flutter pub get

# Verify Flutter environment:
flutter doctor -v
# Expected: All green checks (except optionally iOS Xcode if on non-macOS)
```

#### 2. Configure Firebase

```bash
# Android: Place google-services.json in android/app/
# iOS: Place GoogleService-Info.plist in ios/Runner/

# Obtain from Firebase Console (https://console.firebase.google.com)
# Project Settings → Service Accounts → Google Services file
```

#### 3. Configure App URLs

Create `lib/core/app_config.dart`:

```dart
abstract class AppConfig {
  static const String apiBaseUrl = 'https://localhost:8000/api/v1';
  static const String wsUrl = 'ws://localhost:8000/ws';
  static const String deepLinkScheme = 'radarapp';
}
```

#### 4. Run on Emulator/Device

```bash
# List available devices:
flutter devices

# Run development:
flutter run -d <device_id>

# Run with Dart DevTools:
flutter run --dart-define-from-file=.env.dev

# Expected: App opens with Home screen, no errors in console
```

#### 5. Run Tests

```bash
flutter test

# With coverage:
flutter test --coverage
```

### Docker Compose (Full Stack)

#### 1. Build Images

```bash
docker-compose -f docker-compose.dev.yml build
```

#### 2. Start Stack

```bash
docker-compose -f docker-compose.dev.yml up -d

# View logs:
docker-compose logs -f backend
```

#### 3. Verify Services

```bash
# Backend health:
curl http://localhost:8000/health

# Redis:
redis-cli -h localhost ping

# Grafana:
open http://localhost:3000  # user: admin, pass: admin
```

---

## Production Deployment

### Kubernetes Deployment

```bash
# Prerequisites:
# - GKE / AKS / EKS cluster
# - kubectl configured
# - Helm (optional)

# Deploy backend:
kubectl apply -f infra/k8s/backend/deployment.yaml
kubectl apply -f infra/k8s/backend/service.yaml
kubectl apply -f infra/k8s/backend/configmap.yaml

# Deploy Redis:
kubectl apply -f infra/k8s/redis/statefulset.yaml

# Verify rollout:
kubectl get pods -l app=backend
kubectl logs -l app=backend --tail=100

# Scale:
kubectl scale deployment backend --replicas=3
```

### Monitoring Setup

```bash
# Prometheus:
kubectl apply -f infra/k8s/monitoring/prometheus.yaml

# Grafana:
kubectl apply -f infra/k8s/monitoring/grafana.yaml

# Loki (logs):
kubectl apply -f infra/k8s/monitoring/loki.yaml

# Access Grafana:
kubectl port-forward svc/grafana 3000:80
open http://localhost:3000
```

---

## Development Workflow

### Code Organization

- Backend: Feature-driven structure under `src/api/v1/routes/`
- Mobile: Feature-driven structure under `lib/features/`
- Infrastructure: Shared infra code under `infra/`

### Commits & PRs

1. Create branch: `git checkout -b feat/description`
2. Commit atomically: `git commit -m "feat: description"`
3. Run tests locally: `pytest` / `flutter test`
4. Push: `git push origin feat/description`
5. Open PR with description + test results
6. Merge only after CI passes + code review

### Testing Convention

```
apps/
├── backend/tests/
│   ├── api/                    # Integration tests for endpoints
│   ├── services/               # Unit tests for business logic
│   ├── repositories/           # Unit tests for data access
│   └── core/                   # Unit tests for utilities
└── mobile/test/
    ├── features/               # Feature widget tests
    └── widget_test.dart        # Full app integration test
```

### Performance Testing

```bash
# Backend (Locust load test):
locust -f apps/backend/tests/load/locustfile.py \
  --host=http://localhost:8000 -u 100 -r 10 -t 300

# Mobile (DevTools timeline):
flutter run
# Open DevTools → Timeline tab → record frames while interacting
```

---

## Troubleshooting

### Backend Issues

| Issue | Solution |
|-------|----------|
| `redis.exceptions.ConnectionError` | Verify Redis running: `redis-cli ping` |
| `Module not found: src.*` | Set PYTHONPATH: `export PYTHONPATH=apps/backend` |
| JWT validation fails | Regenerate keys, ensure paths in .env are correct |
| Rate limit false positives | Check Redis TTL on keys: `redis-cli ttl ratelimit:*` |

### Mobile Issues

| Issue | Solution |
|-------|----------|
| Location permission denied | Check AndroidManifest.xml / Info.plist permissions |
| WebSocket connection timeout | Verify backend running + firewall allows WSS |
| Firebase initialization error | Ensure google-services.json present + valid |
| Blurred radar showing | Verify privacy_mode setting + backend privacy filter logic |

### Infrastructure Issues

| Issue | Solution |
|-------|----------|
| Pod not starting | Check logs: `kubectl logs <pod_name>` |
| Persistent volume not mounting | Verify PVC exists and storage class available |
| Ingress not routing | Check Ingress rules + DNS resolution |

---

## References

- **FastAPI Docs**: https://fastapi.tiangolo.com
- **Flutter Docs**: https://flutter.dev/docs
- **Redis Commands**: https://redis.io/commands
- **Kubernetes**: https://kubernetes.io/docs
- **JWT (RFC 7519)**: https://tools.ietf.org/html/rfc7519
