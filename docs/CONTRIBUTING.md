# Contributing Guide

## Workflow

### 1. Branches & Commits

**Branch Strategy**
- `main` → production (requires 2 approvals, all checks pass)
- `staging` → staging environment (auto-deploy on merge)
- `feature/*` → feature branches (open PR to staging)

**Commit Convention**

Using Conventional Commits, enforced by Husky hook:

```
feat: add location broadcast for radar view
fix: handle expired token on WS reconnect
test: add e2e session lifecycle test
docs: update api reference
chore: update dependencies
```

Required format: `type(scope): message`

Types: feat, fix, test, docs, chore, refactor, perf, security

### 2. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# Make changes
git add .
git commit -m "feat: your feature message"
git push origin feature/your-feature-name
```

### 3. Open a Pull Request

- Target: `staging` branch (not main)
- Must include test coverage for new code
- Must pass all CI checks (flutter analyze, pytest, integration tests)
- Requires 1 approval from backend maintainer or 1 from mobile maintainer

### 4. Code Review Checklist

**For All Changes:**
- [ ] Code is idiomatic (follows Flutter/Python style guides)
- [ ] No secrets or PII in code
- [ ] Tests added for new logic
- [ ] Documentation updated if needed
- [ ] Commit message is descriptive

**Backend (FastAPI):**
- [ ] No hardcoded values (use config.py)
- [ ] Proper error handling with domain exceptions
- [ ] Logs are structured JSON, no GPS coordinates
- [ ] Rate limits applied to public endpoints
- [ ] Database operations are atomic (pipelines)

**Mobile (Flutter):**
- [ ] No hardcoded URLs or strings (use AppConfig)
- [ ] Riverpod providers properly typed
- [ ] Tests use ProviderContainer mocks
- [ ] No sync file I/O on main thread
- [ ] Accessibility (44px tap targets, semantic labels)

### 5. Merge & Deploy

- `feature/* → staging` → auto-deploys to staging
- `staging → main` → requires 2 approvals → auto-deploys to production

## Development Environment

### Mobile Setup

```bash
cd apps/mobile

# Code generation (Riverpod, GoRouter)
flutter pub run build_runner build

# Run in debug mode
flutter run --flavor development

# Profile mode (performance testing)
flutter run --profile

# Release mode (final testing)
flutter run --release
```

### Backend Setup

```bash
cd apps/backend

# Type checking
mypy src/ --strict

# Linting
ruff check src/

# Format code
ruff format src/

# Run all checks
make check  # if Makefile exists, else run individually
```

## Testing Requirements

### Mobile

```bash
cd apps/mobile

# Unit & widget tests
flutter test

# Code generation before testing
flutter pub run build_runner build

# Coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# Open coverage/html/index.html
```

### Backend

```bash
cd apps/backend
$env:PYTHONPATH = "src"

# Run all tests
python -m pytest tests/ -v

# Run specific test
python -m pytest tests/api/test_session_lifecycle.py::test_create_session -v

# With coverage
python -m pytest tests/ --cov=src --cov-report=html
```

## Common Tasks

### Add a New API Endpoint

1. Create request/response model in `src/models/`
2. Create route handler in `src/api/v1/routes/`
3. Add to router in `main.py`
4. Write integration tests in `tests/api/`
5. Document in `docs/api.md`

Example:
```python
# src/models/example.py
from pydantic import BaseModel

class ExampleRequest(BaseModel):
    name: str

class ExampleResponse(BaseModel):
    id: str
    name: str

# src/api/v1/routes/example.py
@router.post("/example", response_model=ExampleResponse)
async def create_example(req: ExampleRequest) -> ExampleResponse:
    return ExampleResponse(id=str(uuid4()), name=req.name)
```

### Add a New Flutter Screen

1. Create domain model in `features/{name}/domain/`
2. Create Riverpod notifier in `features/{name}/application/`
3. Create UI widget in `features/{name}/presentation/`
4. Add route in `core/navigation/app_router.dart`
5. Write widget tests in `test/features/{name}/`

### Update Environment Variables

1. Edit `.env.development` (local)
2. Edit `.env.staging` (CI secret)
3. Edit `.env.production` (production secret manager)
4. Update `.env.example` as reference
5. Update `docs/env-reference.md`

## Code Style

### Dart

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Max 80 characters per line (comments/docs), 120 for code
- Use const constructors
- Use null-aware operators (`?.`, `??`)
- Use sealed classes for variants
- Riverpod: prefer AsyncNotifier over FutureProvider for mutable state

### Python

- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) / [Black](https://black.readthedocs.io/)
- Max 100 characters per line
- Use type hints everywhere
- Async/await for I/O
- Structured logging with contextvars
- No logging of PII or GPS coordinates

## Performance Expectations

### Mobile

- **Radar render**: < 4ms frame time with 10 blips
- **Compass lerp**: smooth 60fps animation
- **Location updates**: debounce to 10m or 5s minimum
- **Battery**: < 15% drain per 30 minutes of tracking

### Backend

- **Session create**: < 500ms
- **Location broadcast round-trip**: < 200ms p95
- **Verify endpoint**: < 50ms
- **Memory per session**: < 10KB

## Security Guidelines

- **Secrets**: Never commit to git, use environment variables
- **Authentication**: Enforce RS256 JWT on all protected endpoints
- **Validation**: Always validate input with Pydantic (backend) Models
- **Logging**: Strip GPS/tokens via sanitizer regex
- **Rate limiting**: Applied to all public endpoints
- **CORS**: Allowlist origin in config, never wildcard
- **Dependencies**: Run `pip audit` monthly, update on security patches

## Release Process

### Mobile Release

```bash
cd apps/mobile

# Version bump (manually or via fastlane)
# Update version in pubspec.yaml

# iOS
bundle exec fastlane ios release           # → App Store

# Android
bundle exec fastlane android release       # → Play Store
```

### Backend Release

```bash
# Tag and push
git tag v0.1.0
git push origin v0.1.0

# GitHub Actions triggers on tag
# → Build Docker image → Push to registry → Deploy to production
```

## Troubleshooting

### Tests Failing in CI but Passing Locally

- **Mobile**: Ensure `pub get` runs before `flutter test` (build_runner)
- **Backend**: Check `PYTHONPATH` is set, Redis accessible
- **Flaky tests**: Add logging, increase timeout for network tests

### Build Hangs

- Kill any background processes: `pkill -f flutter` or `pkill -f python`
- Clear caches: `flutter clean`, `poetry cache clear --all`

### Git Hook Issues

```bash
# If pre-commit hook fails
git commit --no-verify  # Only for debugging, then fix the issue

# Re-install hooks
husky install

# List active hooks
husky list
```

## Questions?

Open a GitHub Issue or Discussion, or contact the team at [discord/slack link](https://example.com).

---

**Last Updated**: April 2, 2026
