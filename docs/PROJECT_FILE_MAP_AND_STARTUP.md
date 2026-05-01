# Project File Map and Full Startup Guide

This document gives a practical, current-state map of what each maintained file is doing, plus commands to run the full project (backend + Redis + mobile).

## Scope and Exclusions

This map covers source/config/docs and important platform files.

Excluded from detailed mapping:
- Generated/cached folders like `.venv/`, `.git/`, `.dart_tool/`, `apps/mobile/build/`, `.gradle/`, `.kotlin/`, `__pycache__/`, `.pytest_cache/`.
- Binary assets where behavior is defined by the containing config rather than file contents (icons/images are still listed by purpose groups).

## 1) Workspace Root Files

- `.editorconfig`: Shared editor formatting conventions across repo.
- `.env.development`: Local development environment variable values.
- `.env.example`: Template of required env keys.
- `.env.production`: Production env variable values/template.
- `.env.staging`: Staging env variable values/template.
- `.gitattributes`: Git normalization and attribute rules.
- `.gitignore`: Ignore rules for generated/local-only files.
- `.pre-commit-config.yaml`: Pre-commit checks configuration.
- `.secrets.baseline`: Baseline used by secret scanning tooling.
- `CODEOWNERS`: Default code owners for review routing.
- `commitlint.config.cjs`: Conventional commit linting rules.
- `Ephemeral Location Sharing App PRD.pdf`: Product requirements document.
- `ephemeral_radar_engineering_roadmap.html`: Engineering roadmap and milestones.
- `melos.yaml`: Monorepo package discovery + bootstrap script (`flutter pub get`).
- `mockups.html`: UI mockups/reference.
- `package.json`: Root scripts (`mobile:dev`, `mobile:prod`) + husky/commitlint dev deps.
- `README.md`: Main quick start for backend/mobile/tests/troubleshooting.
- `redis-dev-server.py`: Local Redis helper script (for local dev workflows).
- `ui improvement plan.html`: UI enhancement planning doc.

## 2) GitHub and Hooks

- `.github/CODEOWNERS`: GitHub-specific owner overrides.
- `.github/labeler.yml`: Rules for auto-labeling PRs.
- `.github/workflows/backend-ci.yml`: Backend CI pipeline.
- `.github/workflows/deploy.yml`: Deployment workflow.
- `.github/workflows/mobile-ci.yml`: Mobile CI pipeline.
- `.github/workflows/mobile-release.yml`: Mobile release automation.
- `.github/workflows/pr-labeler.yml`: PR label automation workflow.
- `.github/workflows/stale.yml`: Stale issue/PR handling workflow.
- `.husky/commit-msg`: Commit message hook to enforce commitlint.

## 3) Backend Application (`apps/backend`)

### Top-level and Infra

- `apps/backend/.env`: Backend runtime env file read by `pydantic-settings`.
- `apps/backend/docker-compose.observability.yml`: Observability stack composition for local monitoring.
- `apps/backend/docker-compose.prod.yml`: Production-like compose stack (API + Redis + monitoring).
- `apps/backend/Dockerfile`: Container build for FastAPI service.
- `apps/backend/pyproject.toml`: Poetry project metadata, dependencies, dev tools.
- `apps/backend/README.md`: Minimal backend run instruction.
- `apps/backend/infra/nginx/nginx.conf`: Nginx proxy rules (including websocket handling expectations).
- `apps/backend/infra/observability/prometheus.yml`: Prometheus scrape configuration.
- `apps/backend/infra/observability/grafana/dashboards/radar-overview.json`: Grafana dashboard definition.
- `apps/backend/infra/observability/grafana/provisioning/dashboards/dashboards.yml`: Grafana dashboard provisioning.
- `apps/backend/infra/observability/grafana/provisioning/datasources/prometheus.yml`: Grafana datasource provisioning.

### Backend Source (`apps/backend/src`)

- `apps/backend/src/__init__.py`: Package marker.
- `apps/backend/src/main.py`: FastAPI app wiring. Configures logging/Sentry, Redis lifecycle, middleware, CORS, API routers, metrics endpoint, websocket endpoint.

#### API Routes
- `apps/backend/src/api/__init__.py`: Package marker.
- `apps/backend/src/api/v1/routes/auth.py`: Auth endpoints. Issues JWT token from `{session_id, passkey, user_id}` and serves JWKS.
- `apps/backend/src/api/v1/routes/compliance.py`: Privacy policy endpoint payload for compliance.
- `apps/backend/src/api/v1/routes/health.py`: Health endpoint with Redis connectivity + timestamp.
- `apps/backend/src/api/v1/routes/sessions.py`: Session lifecycle endpoints (create, verify, member list, join, update device token, leave, delete), passkey checks, rate limits, token-scoped admin checks, event broadcasting.

#### Core
- `apps/backend/src/core/__init__.py`: Package marker.
- `apps/backend/src/core/config.py`: Required env schema and load-time validation (`Settings`).
- `apps/backend/src/core/exceptions.py`: Domain exception hierarchy (`DomainError`, `NotFoundError`, `UnauthorizedError`).
- `apps/backend/src/core/logging.py`: Structured JSON logging + request/session context + sensitive value redaction.
- `apps/backend/src/core/observability.py`: Optional Sentry initialization and request payload redaction hook.
- `apps/backend/src/core/rate_limit.py`: Redis-backed generic rate limiter with remaining/reset metadata.
- `apps/backend/src/core/security.py`: RS256 JWT create/decode, JWKS, bearer extraction, session-scope validation, token revocation blacklist.

#### Infrastructure
- `apps/backend/src/infrastructure/__init__.py`: Package marker.
- `apps/backend/src/infrastructure/metrics.py`: Prometheus metrics, HTTP middleware instrumentation, `/metrics` endpoint.
- `apps/backend/src/infrastructure/middleware.py`: Request ID context, abusive IP blocklisting escalation, request payload-size guard.
- `apps/backend/src/infrastructure/redis_client.py`: Redis client init/close, health check, expiry listener callback pipeline, fakeredis fallback.

#### Models
- `apps/backend/src/models/__init__.py`: Package marker.
- `apps/backend/src/models/auth.py`: Auth request/response Pydantic models.
- `apps/backend/src/models/session.py`: Session request/response/member models.
- `apps/backend/src/models/ws.py`: WebSocket envelope schema + message type enum.

#### Repositories
- `apps/backend/src/repositories/__init__.py`: Package marker.
- `apps/backend/src/repositories/redis_repository.py`: Base Redis operations (`hgetall`, `hset+expire`, delete, health).
- `apps/backend/src/repositories/session_repository.py`: Session data model in Redis (session/member/profile/location/chat/path keys), TTL management, geo queries, cascade deletion, expiry cleanup.

#### Services
- `apps/backend/src/services/__init__.py`: Package marker.
- `apps/backend/src/services/broadcaster.py`: Event broadcast logging hook abstraction.
- `apps/backend/src/services/connection_manager.py`: In-memory websocket room connection tracking with lock.
- `apps/backend/src/services/notifications.py`: Push payload contract enforcement (`type` + `session_id` only), multicast stub.
- `apps/backend/src/services/websocket_service.py`: WebSocket session handling: auth gate, ping/pong heartbeat, per-user rate limiting, privacy filtering, location processing + room broadcast, disconnect cleanup.

### Backend Tests (`apps/backend/tests`)

- `apps/backend/tests/conftest.py`: Async fakeredis fixture and test Redis injection.
- `apps/backend/tests/api/test_auth_token_system.py`: Token expiry/tamper checks + blacklist enforcement.
- `apps/backend/tests/api/test_session_lifecycle.py`: End-to-end API session lifecycle + rate-limit behavior checks.
- `apps/backend/tests/api/test_websocket_server.py`: Missing-token WS rejection + member cleanup on disconnect.
- `apps/backend/tests/core/test_logging.py`: Redaction tests for coordinates/tokens/passkeys.
- `apps/backend/tests/load/locustfile.py`: Locust load test skeleton for location update pacing.
- `apps/backend/tests/repositories/test_session_repository.py`: Redis repository TTL/atomic/geo boundary behavior.
- `apps/backend/tests/services/test_notifications.py`: Notification payload contract + multicast count behavior.

## 4) Mobile Application (`apps/mobile`)

### Mobile Project Config

- `apps/mobile/.flutter-plugins-dependencies`: Generated Flutter plugin dependency map.
- `apps/mobile/.gitignore`: Mobile module ignore rules.
- `apps/mobile/.metadata`: Flutter project metadata.
- `apps/mobile/analysis_options.yaml`: Dart/Flutter lint and analysis rules.
- `apps/mobile/mobile.iml`: IDE module descriptor.
- `apps/mobile/pubspec.lock`: Exact dependency lockfile.
- `apps/mobile/pubspec.yaml`: Mobile dependencies, SDK constraints, build/dependency settings.
- `apps/mobile/README.md`: Mobile quick run/build commands.
- `apps/mobile/ui_smoke_1.png`: UI smoke artifact/snapshot.

### Android

- `apps/mobile/android/.gitignore`: Android-specific ignores.
- `apps/mobile/android/build.gradle.kts`: Root Android Gradle configuration.
- `apps/mobile/android/gradle.properties`: Gradle property flags.
- `apps/mobile/android/gradlew`: Gradle wrapper (Unix).
- `apps/mobile/android/gradlew.bat`: Gradle wrapper (Windows).
- `apps/mobile/android/local.properties`: Local SDK path/config (machine-specific).
- `apps/mobile/android/mobile_android.iml`: IDE Android module descriptor.
- `apps/mobile/android/settings.gradle.kts`: Android Gradle module includes.
- `apps/mobile/android/app/build.gradle.kts`: Android app module config, packaging, signing/build setup.
- `apps/mobile/android/app/src/debug/AndroidManifest.xml`: Debug manifest overlay.
- `apps/mobile/android/app/src/main/AndroidManifest.xml`: Main Android app manifest (permissions/components).
- `apps/mobile/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`: Generated plugin registration stub.
- `apps/mobile/android/app/src/main/kotlin/io/radarapp/mobile/MainActivity.kt`: Android entry activity.
- `apps/mobile/android/app/src/main/res/drawable/launch_background.xml`: Launch background drawable.
- `apps/mobile/android/app/src/main/res/drawable-v21/launch_background.xml`: API 21+ launch background variant.
- `apps/mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`: Launcher icon (hdpi).
- `apps/mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`: Launcher icon (mdpi).
- `apps/mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`: Launcher icon (xhdpi).
- `apps/mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`: Launcher icon (xxhdpi).
- `apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`: Launcher icon (xxxhdpi).
- `apps/mobile/android/app/src/main/res/values/styles.xml`: Android style resources.
- `apps/mobile/android/app/src/main/res/values-night/styles.xml`: Night mode style resources.
- `apps/mobile/android/app/src/profile/AndroidManifest.xml`: Profile manifest overlay.
- `apps/mobile/android/gradle/wrapper/gradle-wrapper.jar`: Gradle wrapper binary.
- `apps/mobile/android/gradle/wrapper/gradle-wrapper.properties`: Wrapper version/source config.

### iOS

- `apps/mobile/ios/.gitignore`: iOS ignore rules.
- `apps/mobile/ios/Flutter/AppFrameworkInfo.plist`: iOS Flutter framework metadata.
- `apps/mobile/ios/Flutter/Debug.xcconfig`: iOS debug build settings.
- `apps/mobile/ios/Flutter/flutter_export_environment.sh`: Exported Flutter build env script.
- `apps/mobile/ios/Flutter/Generated.xcconfig`: Generated iOS Flutter config.
- `apps/mobile/ios/Flutter/Release.xcconfig`: iOS release build settings.
- `apps/mobile/ios/Runner/AppDelegate.swift`: iOS app delegate.
- `apps/mobile/ios/Runner/Info.plist`: iOS app metadata and permissions keys.
- `apps/mobile/ios/Runner/Runner-Bridging-Header.h`: ObjC/Swift bridging header.
- `apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`: App icon set manifest.
- `apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-*.png`: iOS icon assets for required sizes.
- `apps/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`: Launch image set manifest.
- `apps/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage*.png`: Launch image variants.
- `apps/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`: Launch image notes.
- `apps/mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard`: Launch screen layout.
- `apps/mobile/ios/Runner/Base.lproj/Main.storyboard`: Main iOS storyboard.
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj`: Xcode project build graph.
- `apps/mobile/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`: Workspace metadata.
- `apps/mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`: IDE checks config.
- `apps/mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`: Workspace settings.
- `apps/mobile/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`: Shared run/build scheme.
- `apps/mobile/ios/Runner.xcworkspace/contents.xcworkspacedata`: Workspace metadata.
- `apps/mobile/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`: IDE checks config.
- `apps/mobile/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`: Workspace settings.
- `apps/mobile/ios/RunnerTests/RunnerTests.swift`: Basic iOS unit test scaffold.

### Environment and Release

- `apps/mobile/env/dev.json`: Dart define values for development runs.
- `apps/mobile/env/prod.json`: Dart define values for production runs.
- `apps/mobile/fastlane/Appfile`: Fastlane app identifiers and metadata.
- `apps/mobile/fastlane/Fastfile`: Mobile release lane automation.

### Flutter App Source (`apps/mobile/lib`)

- `apps/mobile/lib/main.dart`: App entrypoint. Initializes Firebase/telemetry, injects runtime config provider, clears cached local session data on startup, wires router/theme.

#### Core
- `apps/mobile/lib/core/app_config.dart`: Validates and parses required compile-time config (`API_BASE_URL`, `FCM_SENDER_ID`, `DEEP_LINK_SCHEME`, `REGION_WS_URLS`).
- `apps/mobile/lib/core/animations/app_animations.dart`: Shared animation constants/helpers.
- `apps/mobile/lib/core/error_handling/error_messages.dart`: Human-readable error text mapping.
- `apps/mobile/lib/core/error_handling/retry.dart`: Retry policy/helper utilities.
- `apps/mobile/lib/core/feature_flags/remote_config_service.dart`: Remote config reads/fallback behavior.
- `apps/mobile/lib/core/navigation/app_router.dart`: Route graph and auth/entry redirects.
- `apps/mobile/lib/core/telemetry/telemetry_service.dart`: Crash/analytics/telemetry integration helpers.
- `apps/mobile/lib/core/theme/app_theme.dart`: App theme construction.
- `apps/mobile/lib/core/theme/app_tokens.dart`: Design tokens (colors, spacing, radii, etc.).
- `apps/mobile/lib/core/widgets/radar_bottom_sheet.dart`: Shared bottom sheet UI component.
- `apps/mobile/lib/core/widgets/radar_button.dart`: Shared button component.
- `apps/mobile/lib/core/widgets/radar_card.dart`: Shared card component.
- `apps/mobile/lib/core/widgets/radar_snackbar.dart`: Shared snackbar component.
- `apps/mobile/lib/core/widgets/radar_text_field.dart`: Shared text-field component.

#### Features - Auth
- `apps/mobile/lib/features/auth/application/auth_state.dart`: Authentication/session-ready state provider logic.

#### Features - Chat
- `apps/mobile/lib/features/chat/application/chat_providers.dart`: Chat state/providers.
- `apps/mobile/lib/features/chat/presentation/chat_overlay.dart`: Chat UI overlay layer.

#### Features - Compass
- `apps/mobile/lib/features/compass/application/compass_providers.dart`: Compass feature state/providers.
- `apps/mobile/lib/features/compass/domain/bearing_utils.dart`: Bearing/angle math utilities.
- `apps/mobile/lib/features/compass/infrastructure/compass_service.dart`: Device compass/sensor integration.
- `apps/mobile/lib/features/compass/presentation/compass_view.dart`: Compass screen UI.

#### Features - Radar
- `apps/mobile/lib/features/radar/application/radar_providers.dart`: Radar state/providers.
- `apps/mobile/lib/features/radar/domain/radar_blip.dart`: Radar domain model for participant blips.
- `apps/mobile/lib/features/radar/presentation/radar_canvas.dart`: Custom radar drawing/painting.
- `apps/mobile/lib/features/radar/presentation/radar_view.dart`: Radar screen container/presentation.

#### Features - Session
- `apps/mobile/lib/features/session/application/deep_link_providers.dart`: Deep-link parsing/state providers.
- `apps/mobile/lib/features/session/application/location_providers.dart`: Location update providers.
- `apps/mobile/lib/features/session/application/privacy_providers.dart`: Privacy mode state providers.
- `apps/mobile/lib/features/session/application/rejoin_service.dart`: Session rejoin recovery logic.
- `apps/mobile/lib/features/session/domain/deep_link_payload.dart`: Parsed deep-link model.
- `apps/mobile/lib/features/session/domain/location_mode.dart`: Location sharing mode enum/model.
- `apps/mobile/lib/features/session/domain/radar_message.dart`: Session/radar message model.
- `apps/mobile/lib/features/session/domain/session_cache.dart`: Cached session data model.
- `apps/mobile/lib/features/session/infrastructure/api_client.dart`: Abstract + Dio-backed JSON API client wrapper.
- `apps/mobile/lib/features/session/infrastructure/deep_link_service.dart`: App/deep-link intake service.
- `apps/mobile/lib/features/session/infrastructure/foreground_tracking_service.dart`: Foreground location tracking orchestration.
- `apps/mobile/lib/features/session/infrastructure/local_storage_service.dart`: Secure/persistent local cache access.
- `apps/mobile/lib/features/session/infrastructure/location_service.dart`: Geolocation service abstraction.
- `apps/mobile/lib/features/session/infrastructure/network_providers.dart`: Networking providers (dio/ws/lifecycle/remote config dependencies).
- `apps/mobile/lib/features/session/infrastructure/notification_service.dart`: Local/remote notification handling.
- `apps/mobile/lib/features/session/infrastructure/permission_service.dart`: Runtime permission checks/requests.
- `apps/mobile/lib/features/session/presentation/blurred_radar_blocker.dart`: Privacy overlay when radar should be obscured.
- `apps/mobile/lib/features/session/presentation/entry_screen.dart`: Entry/start screen.
- `apps/mobile/lib/features/session/presentation/join_screen.dart`: Join flow UI.
- `apps/mobile/lib/features/session/presentation/privacy_sheet.dart`: Privacy mode selector UI.
- `apps/mobile/lib/features/session/presentation/session_setup_screen.dart`: Session creation/setup UI.
- `apps/mobile/lib/features/session/presentation/waiting_room_screen.dart`: Waiting room/share-link UI.

### Mobile Tests

- `apps/mobile/test/widget_test.dart`: Base widget smoke test.
- `apps/mobile/test/features/compass/bearing_utils_test.dart`: Bearing utility tests.
- `apps/mobile/test/features/session/deep_link_payload_test.dart`: Deep-link payload parsing tests.

### IDE Metadata (Mobile)

- `apps/mobile/.idea/modules.xml`: JetBrains module map.
- `apps/mobile/.idea/workspace.xml`: User/workspace IDE state.
- `apps/mobile/.idea/libraries/Dart_SDK.xml`: IDE Dart SDK reference.
- `apps/mobile/.idea/libraries/KotlinJavaRuntime.xml`: IDE Kotlin runtime ref.
- `apps/mobile/.idea/runConfigurations/main_dart.xml`: IDE run configuration.

## 5) Other Repository Docs and Scripts

- `docs/api.md`: Public API reference with endpoint contracts and examples.
- `docs/ARCHITECTURE.md`: Architecture, data model, and operational flows.
- `docs/CONTRIBUTING.md`: Contribution process, style, test expectations.
- `docs/env-reference.md`: Environment key definitions and validation rules.
- `docs/FINAL_VALIDATION.md`: Final validation checklist/report doc.
- `docs/LAUNCH_CHECKLIST.md`: Launch readiness checklist.
- `infra/README.md`: Currently empty placeholder.
- `packages/shared/README.md`: Shared package placeholder/readme.
- `scripts/validate_env.ps1`: Validates that target env file contains all keys from `.env.example`.

## 6) Full Project Startup (Windows / PowerShell)

Run from repository root unless stated.

### Prerequisites

- Flutter SDK available in PATH.
- Python 3.12+.
- Docker Desktop running (if using containerized Redis).
- Optional: Poetry (for backend dependency management).

### A) One-Time Setup

```powershell
# Root hooks and mobile workspace bootstrap
npm install

# If melos is available globally (optional monorepo bootstrap)
melos bootstrap

# Backend dependencies (choose one approach)
cd apps/backend
poetry install
cd ../..

# Mobile dependencies
cd apps/mobile
flutter pub get
cd ../..
```

### B) Start Redis (Terminal 1)

Option 1 (recommended local):

```powershell
docker run --name radar-redis -p 6379:6379 redis:7 redis-server --appendonly yes --notify-keyspace-events KEA
```

Option 2 (if already created):

```powershell
docker start radar-redis
```

### C) Start Backend API (Terminal 2)

```powershell
cd apps/backend
$env:PYTHONPATH = "src"
poetry run uvicorn src.main:app --reload --port 8000
```

Alternative if using root virtualenv python directly:

```powershell
$env:PYTHONPATH = "apps/backend"
.\.venv\Scripts\python.exe -m uvicorn src.main:app --reload --port 8000
```

Backend endpoints after startup:
- Swagger: http://localhost:8000/docs
- Health: http://localhost:8000/api/v1/health
- Metrics: http://localhost:8000/metrics

### D) Start Mobile App (Terminal 3)

Recommended (uses checked-in dart-defines file):

```powershell
cd apps/mobile
flutter run --dart-define-from-file=env/dev.json
```

From root (same result via package script):

```powershell
npm run mobile:dev
```

### E) Quick Validation Commands

Backend tests:

```powershell
$env:PYTHONPATH = "apps/backend"
.\.venv\Scripts\python.exe -m pytest apps/backend/tests -v
```

Mobile checks:

```powershell
cd apps/mobile
flutter analyze
flutter test
```

### F) Optional Full Docker Compose Stack

```powershell
docker compose -f apps/backend/docker-compose.prod.yml up
```

Use this for production-like backend + observability wiring.

## 7) Standard Stop Commands

- Stop backend: `Ctrl+C` in backend terminal.
- Stop mobile run: `q` or `Ctrl+C` in flutter terminal.
- Stop Redis container:

```powershell
docker stop radar-redis
```

## 8) Notes for New Contributors

- Backend startup will fail fast when required env keys are missing (`apps/backend/src/core/config.py`).
- Mobile startup will fail fast when required dart-defines are missing (`apps/mobile/lib/core/app_config.dart`).
- Current mobile `main.dart` clears cached local session data on startup by design.
- Websocket endpoint is `/ws/{session_id}` and currently accepts `token` query parameter as sender identity in message flow.
