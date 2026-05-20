Full Map Implementation - Summary
================================

This document summarizes the full-map realtime tracking implementation added to the project.

Key components
- Backend: viewport subscription service, Redis pub/sub broadcaster, grid-based subscription partitioning, rate limiting, metrics
- Mobile: Mapbox-based `FullMapView`, `MapWsAdapter` to send viewport subscribes and render clustered markers, symbol interpolation for smooth motion

Environment variables
- `MAPBOX_TOKEN` — Mapbox access token (mobile). Pass to Flutter builds via `--dart-define=MAPBOX_TOKEN=<token>`.
- Redis is required and must be accessible by the backend. Ensure `notify-keyspace-events` is enabled if Redis key expiry cascade is required (existing code attempts to set it).

Backend deployment notes
- Redis pub/sub is used for distributing location events between backend instances. Ensure Redis pub/sub channels are reachable.
- For heavy traffic, consider migrating pub/sub to Redis Streams or Kafka for durable ordering and backpressure.
- Add the following Prometheus metrics for monitoring: `location_updates_per_second`, `ws_broadcast_latency_seconds`, `viewport_subscriptions_total` (future), `active_connections_total`.

Mobile deployment notes
- Add `MAPBOX_TOKEN` to CI/dev build step:
  - Example: `flutter run --dart-define=MAPBOX_TOKEN=pk.xyz` or in CI pipeline `--dart-define` flags.
- Mapbox SDK used: `mapbox_gl` plugin. If you prefer `flutter_map`, adapt `MapWsAdapter` accordingly.

Security & privacy
- Server enforces per-user privacy modes as before. Full-map visibility is only given when users enable the full map privacy mode.
- Mapbox token is a public client token for map tiles; do not commit tokens to source.

Next steps
- Replace simple grid clustering with `supercluster` client implementation for better UX.
- Add server-side cluster summaries for extremely dense areas.
- Add more thorough integration tests and load tests to exercise rate limits and broadcast path.
