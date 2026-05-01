# Production Launch Checklist

## Pre-Launch Verification (Step 35)

Use this checklist to verify all systems are ready before production traffic.

---

## 1. Security Verification

- [ ] **MobSF Scan** on APK/IPA
  - Command: `mobsf -f app-release.apk`
  - Requirement: **0 critical findings**, 0 high findings
  - Screenshot: Attach MobSF report to PR

- [ ] **OWASP ZAP API Scan** on staging backend
  - Command: `zaproxy -cmd -quickurl http://staging.radarapp.io -quickout report.html`
  - Requirement: **0 high-severity findings**
  - Screenshot: Attach ZAP report

- [ ] **Git History Audit** — no secrets committed
  - Command: `trufflehog git file:///path/to/repo`
  - Requirement: **0 secrets found**

- [ ] **Dependencies Audit**
  - Backend: `pip audit` → 0 HIGH/CRITICAL
  - Mobile: `flutter pub deps --json | grep vulnerable` → 0 matches

- [ ] **Rate Limiting Verified in Staging**
  - **Create Session**: 6th request within 1 min → 429 response
  - **Verify Endpoint**: 21st request within 1 min → 429 response
  - **WS Location Update**: > 1/s per user → dropped/rate limited

- [ ] **Data Minimization Audit**
  - Run grep for coordinate patterns in logs:
    ```bash
    grep -r "lat\|lng\|coord" apps/backend/src/ tests/ | grep -v ".pyc"
    # Should find 0 hardcoded coordinates in logging calls
    ```

---

## 2. Performance Verification

### Load Testing

- [ ] **Locust Load Test** — 100 concurrent WebSocket connections
  - Command: `locust -f apps/backend/tests/load/locustfile.py --host=wss://staging.radarapp.io -u 100 -r 10 -t 300`
  - Targets:
    - **Error rate**: < 2% (max 2 errors per 100 requests)
    - **Location broadcast round-trip latency**: < 200ms p95
  - Duration: 5 minutes continuous
  - Screenshot: Attach Locust report

### Mobile Performance

- [ ] **Flutter DevTools Timeline** — Radar rendering with 10 blips
  - **Frame time**: < 4ms build time
  - **No jank frames**: 60fps sustained
  - Screenshot: DevTools timeline showing p50/p95/p99

- [ ] **Battery Test** — 30-minute radar session
  - Device: Android (Pixel) or iOS (iPhone 15)
  - **Battery drain**: < 15% over 30 minutes
  - Conditions: Screen on, location accuracy = medium, WS active
  - Screenshot: Battery percentage before/after

### Backend Performance

- [ ] **Session create latency**: < 500ms (measured in load test)
  - Verified via load test results

- [ ] **Redis memory**: < 1GB with 500 concurrent sessions
  - Verified via load test monitoring

---

## 3. Compatibility & Device Testing

### Android

- [ ] **MinSDK 24** (Android 7.0) compiles and runs
- [ ] **Foreground service** notification appears within 1s of join
- [ ] **Background location** updates continue when screen off
- [ ] **Device**: Tested on Android 14+ (Pixel 8 or equivalent)

### iOS

- [ ] **MinOS 14.0** target set in Xcode
- [ ] **Location permissions** prompt visible, two-step flow works (WhenInUse → Always)
- [ ] **Background modes** enabled: Location Updates
- [ ] **Background location** updates visible in CLLocationManager logs
- [ ] **Device**: Tested on iOS 17+ (iPhone 15 or equivalent)

---

## 4. Store Submission

### Google Play Console

- [ ] **Store listing complete**
  - [ ] Screenshots: 5+ (showing radar, compass, QR, privacy controls)
  - [ ] Description: Updated with privacy-first messaging
  - [ ] Release notes: Version 1.0.0 with feature summary

- [ ] **Content rating** — completed questionnaire
  - [ ] Data collection: Location only during active sessions
  - [ ] Data sharing: No third-party sharing
  - [ ] Rating: PEGI 3 or equivalent

- [ ] **Data Safety** form completed
  - [ ] Location data: Collected during session only, deleted on termination
  - [ ] Authentication: No user accounts
  - [ ] Data security: Encrypted in transit (HTTPS/WSS)

### App Store Connect

- [ ] **App information** complete
  - [ ] Description: Privacy-focused, ephemeral sessions
  - [ ] Screenshots: 5+ (English minimum, translated variants for other regions)
  - [ ] Keywords: location, sharing, privacy, radar, compass

- [ ] **App Privacy** policy
  - [ ] Privacy policy URL: https://radarapp.io/privacy → live and accurate
  - [ ] Privacy label: No persistent identifiers, location data cleared on session end

- [ ] **App Store Review** guidelines compliance
  - [ ] Background location use approved for tracking app
  - [ ] Foreground session notification prominent
  - [ ] No location data in FCM payloads

---

## 5. Backend & Infrastructure

- [ ] **Kubernetes / Docker Compose** health check
  - [ ] Readiness probe on `/health` returns 200
  - [ ] Liveness probe returns success
  - [ ] Pod scaling: 3 replicas deployed with rolling update

- [ ] **Redis** persistence verified
  - [ ] AOF enabled (`appendonly yes`)
  - [ ] Persistence test: restart Redis, data survives
  - [ ] Memory max set: 2GB with eviction policy `allkeys-lru`

- [ ] **Nginx** configuration verified
  - [ ] SSL/TLS certificate valid (not self-signed)
  - [ ] WebSocket proxy headers configured (`proxy_http_version 1.1`, Upgrade, Connection)
  - [ ] Rate limit headers present in responses

- [ ] **Database migrations** applied
  - [ ] No pending migrations
  - [ ] Rollback procedure documented and tested (all commands in runbook)

---

## 6. Monitoring & Alerting

- [ ] **Prometheus** metrics scraping
  - [ ] All targets healthy (Backend, Redis)
  - [ ] Active sessions gauge reporting
  - [ ] WebSocket broadcast latency histogram populated

- [ ] **Grafana** dashboards live
  - [ ] "Radar Overview" dashboard live and showing real data
  - [ ] Queries updating every 30 seconds
  - [ ] Alerts configured: CPU > 80%, memory > 85%, error rate > 0.5%

- [ ] **PagerDuty** escalation configured
  - [ ] Grafana alert notifications → PagerDuty
  - [ ] On-call rotation assigned
  - [ ] Escalation time: 30 minutes

- [ ] **Checkly** uptime monitor active
  - [ ] `GET /health` check running every 60 seconds
  - [ ] Downtime alerts → Slack + email
  - [ ] SLA target: 99.5% uptime

---

## 7. Documentation

- [ ] **README.md** updated
  - [ ] "Quick Start" can be followed in < 30 minutes
  - [ ] All env variables documented
  - [ ] Verified by independent team member

- [ ] **API documentation** live
  - [ ] OpenAPI docs at `/docs` (Swagger)
  - [ ] `/redoc` (ReDoc) also available
  - [ ] All endpoints documented with examples

- [ ] **Architecture documentation** current
  - [ ] System diagram matches actual deployment
  - [ ] Redis schema documented
  - [ ] Security model explained

- [ ] **Runbooks** written and reviewed
  - [ ] `session-stuck`: Procedure to force cleanup
  - [ ] `redis-memory-high`: Scale redis or implement eviction
  - [ ] `ws-connections-spiking`: Debug connection leaks
  - [ ] Each reviewed by on-call engineer

---

## 8. Data Privacy & GDPR

- [ ] **Privacy policy** endpoint live
  - [ ] `GET /api/v1/privacy` returns 200
  - [ ] Publicly accessible web version at radarapp.io/privacy
  - [ ] Contains: data collection, retention, deletion, contact

- [ ] **GDPR compliance** verified
  - [ ] No persistent user database
  - [ ] Session data deleted on termination
  - [ ] 12-hour TTL on all session keys (automatic cleanup)
  - [ ] User consent via location permission prompt

- [ ] **Log sanitization** verified
  - [ ] Automated grep for coordinates in logs: 0 matches
  - [ ] Automated grep for tokens: 0 matches
  - [ ] Log retention policy: 30 days max, auto-purge

---

## 9. Rollout Plan

- [ ] **Android rollout**
  - [ ] Initial: 10% staged rollout for 3 days
  - [ ] Monitoring: 0% crash rate during rollout
  - [ ] Approval: Team lead sign-off before 100% rollout

- [ ] **iOS rollout**
  - [ ] App Store does not support staged rollout natively
  - [ ] Deployment: 100% on day 1
  - [ ] Feature flags: New features behind Remote Config initially (disabled)

- [ ] **Feature flags**
  - [ ] `chat_enabled_global: false` initially
  - [ ] `max_session_size: 10` conservative starting limit
  - [ ] Monitor for 48h before enabling chat globally

- [ ] **Rollback procedure**
  - [ ] Backend: Previous Docker image tag deployed (< 5 min downtime)
  - [ ] Mobile: Halt rollout in Play Console, no iOS rollback needed (users can stay on older version)
  - [ ] Tested: Rollback procedure executed in staging, documented

---

## 10. Final Sign-Off

### Checklist Completion

- [ ] **All items above checked off**
- [ ] **No open critical/high issues** in issue tracker

### Team Sign-Off

- [ ] **Backend Lead**: ______________________ Date: _______
- [ ] **Mobile Lead**: ______________________ Date: _______
- [ ] **DevOps / Infrastructure**: ______________________ Date: _______
- [ ] **Security Review**: ______________________ Date: _______
- [ ] **Product Manager**: ______________________ Date: _______

### Launch Decision

- [ ] **All sign-offs received**
- [ ] **Production environment healthy** (24h+ observed)
- [ ] **Feature flags configured** (chat disabled during rollout)
- [ ] **On-call schedule confirmed** for launch week

**APPROVED FOR LAUNCH**: ______________________ Date: _______

---

## Post-Launch Monitoring (First 48 Hours)

- [ ] Crash rate < 0.1%
- [ ] Error rate < 0.2%
- [ ] WebSocket latency p95 < 200ms
- [ ] Zero security incidents
- [ ] At least 10 concurrent sessions sustained

If any metric fails → execute rollback immediately.

---

**Checklist created**: April 2, 2026  
**Version**: 1.0.0
