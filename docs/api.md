# API Documentation

## Overview

Ephemeral Radar backend exposes a REST API with WebSocket support for real-time location sharing. All endpoints are versioned under `/api/v1/`.

**Base URL**: `https://api.radarapp.io/api/v1`  
**WebSocket URL**: `wss://api.radarapp.io/ws`

### OpenAPI / Swagger

Interactive API documentation is available at:
- **Swagger UI**: `https://api.radarapp.io/docs`
- **ReDoc**: `https://api.radarapp.io/redoc`
- **OpenAPI JSON**: `https://api.radarapp.io/openapi.json`

---

## Authentication

### Bearer Token (JWT)

Protected endpoints require a Bearer token (JWT, RS256-signed):

```
Authorization: Bearer <token>
```

Token is obtained via `POST /api/v1/auth/token` and is valid for **24 hours**.

### JWKS Endpoint

Public key set for token validation:

```
GET /api/v1/auth/jwks
```

Returns JWKS-formatted public keys for verifying JWT signatures.

---

## Rate Limiting

All endpoints are rate-limited per IP address to prevent abuse:

- **Session Creation**: 5 requests per 60 seconds
- **Session Verification**: 20 requests per 60 seconds
- **WebSocket Location Updates**: > 1 update per second is rate-limited per user

Rate limit headers are included in responses:

```
X-RateLimit-Remaining: 4  # Remaining requests in window
X-RateLimit-Reset: 45     # Seconds until window resets
Retry-After: 45            # On 429, retry after this period
```

---

## API Reference

### Authentication Endpoints

#### Issue Token

**POST** `/auth/token`

Obtain a JWT token to authenticate session operations.

**Request Body**:
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "passkey": "ABC12345",
  "user_id": "alice_123"
}
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors**:
- `404 Not Found`: Session not found or invalid passkey

---

#### Get JWKS

**GET** `/auth/jwks`

Retrieve public key set for validating JWT tokens.

**Response** (200 OK):
```json
{
  "keys": [
    {
      "kty": "RSA",
      "use": "sig",
      "kid": "2024-04",
      "n": "...",
      "e": "AQAB"
    }
  ]
}
```

---

### Session Management Endpoints

#### Create Session

**POST** `/sessions`

Create a new ephemeral location-sharing session.

**Request Body**:
```json
{
  "session_name": "Weekend Hike",
  "admin_id": "user_001",
  "chat_enabled": true,
  "region": "us-east"
}
```

**Parameters**:
- `session_name` (string, required): Display name for the session (max 100 chars)
- `admin_id` (string, required): Unique ID of the session creator
- `chat_enabled` (boolean, required): Whether chat feature is enabled
- `region` (string, required): Region for WebSocket routing (e.g., "us-east", "eu-west", "ap-south")

**Response** (200 OK):
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "passkey": "ABC12345",
  "deep_link_url": "radarapp://join?s=550e8400-e29b-41d4-a716-446655440000&p=ABC12345&r=us-east"
}
```

**Rate Limit**: 5 per 60 seconds per IP

**Errors**:
- `429 Too Many Requests`: Rate limit exceeded
- `400 Bad Request`: Invalid request body

---

#### Verify Session

**GET** `/sessions/verify`

Validate a session exists before joining and get connection details.

**Query Parameters**:
- `s` (string, required): Session ID
- `p` (string, required): Passkey for the session

**Response** (200 OK):
```json
{
  "session_name": "Weekend Hike",
  "host_name": "user_001",
  "active_members": 3,
  "websocket_url": "wss://api.radarapp.io/ws"
}
```

**Rate Limit**: 20 per 60 seconds per IP

**Errors**:
- `404 Not Found`: Session not found or invalid passkey
- `429 Too Many Requests`: Rate limit exceeded

---

#### Join Session

**POST** `/sessions/{session_id}/join`

Register a user as a participant in an active session.

**Path Parameters**:
- `session_id` (string, required): The session UUID

**Request Body**:
```json
{
  "user_id": "alice_123",
  "display_name": "Alice",
  "avatar_url": "https://example.com/avatars/alice.jpg",
  "privacy_mode": "direction_distance",
  "fcm_token": "esBygWuR5SY:APA91bH..."
}
```

**Parameters**:
- `user_id` (string, required): Unique identifier for the user (max 100 chars)
- `display_name` (string, required): Name to display on other users' radars (max 50 chars)
- `avatar_url` (string, optional): URL to user's avatar image
- `privacy_mode` (string, required): Privacy level ("point", "direction_distance", "full")
- `fcm_token` (string, optional): Firebase Cloud Messaging token for push notifications

**Response** (200 OK):
```json
{
  "status": "joined"
}
```

**Errors**:
- `404 Not Found`: Session not found
- `400 Bad Request`: Invalid request body

---

#### Update Device Token

**POST** `/sessions/{session_id}/device-token`

Update a user's FCM token for push notification delivery.

**Path Parameters**:
- `session_id` (string, required): The session UUID

**Request Body**:
```json
{
  "user_id": "alice_123",
  "fcm_token": "esBygWuR5SY:APA91bH..."
}
```

**Response** (200 OK):
```json
{
  "status": "updated"
}
```

**Errors**:
- `404 Not Found`: Session not found

---

#### Leave Session

**POST** `/sessions/{session_id}/leave`

Unregister a user from an active session.

**Path Parameters**:
- `session_id` (string, required): The session UUID

**Request Body**:
```json
{
  "user_id": "alice_123"
}
```

**Authorization**: Optional Bearer token (recommended to blacklist it after logout)

**Response** (200 OK):
```json
{
  "status": "left"
}
```

**Errors**:
- `404 Not Found`: Session not found

---

#### Delete Session

**DELETE** `/sessions/{session_id}`

Terminate a session and disconnect all participants. Only the admin can delete.

**Path Parameters**:
- `session_id` (string, required): The session UUID

**Authorization**: **Required** Bearer token (must be admin)

**Response** (200 OK):
```json
{
  "status": "deleted",
  "members_notified": 3
}
```

**Errors**:
- `403 Forbidden`: Not the session admin
- `404 Not Found`: Session not found

---

### Health Endpoint

#### Health Check

**GET** `/health`

Check backend and Redis connectivity.

**Response** (200 OK):
```json
{
  "status": "ok",
  "version": "0.1.0",
  "redis_connected": true,
  "timestamp": "2024-04-02T15:30:45.123456+00:00"
}
```

**Response** (503 Service Unavailable - if Redis down):
```json
{
  "status": "degraded",
  "version": "0.1.0",
  "redis_connected": false,
  "timestamp": "2024-04-02T15:30:45.123456+00:00"
}
```

---

## WebSocket API

### Connection

**URL**: `wss://api.radarapp.io/ws/{session_id}?token=<jwt>`

Connect to a session's real-time location broadcast feed.

**Protocol**: WebSocket (RFC 6455)

**Query Parameters**:
- `session_id` (required): The session UUID
- `token` (required): Valid JWT from `/auth/token`

**Upgrade Headers**:
```
Connection: Upgrade
Upgrade: websocket
Sec-WebSocket-Version: 13
Sec-WebSocket-Key: <random>
```

### Message Format

All WebSocket messages follow this envelope:

**Incoming (from server)**:
```json
{
  "type": "LOCATION_UPDATE",
  "payload": {
    "user_id": "alice_123",
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 15.0,
    "timestamp": 1680000000000
  },
  "sender_id": "alice_123",
  "timestamp": "2024-04-02T15:30:45.123456Z"
}
```

**Outgoing (to server)**:
```json
{
  "type": "LOCATION_UPDATE",
  "payload": {
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 15.0
  }
}
```

### Message Types

#### LOCATION_UPDATE

Real-time GPS position broadcast. Send updates from client; receive from other users.

**Server → Client**:
```json
{
  "type": "LOCATION_UPDATE",
  "payload": {
    "user_id": "alice_123",
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 15.0,
    "timestamp": 1680000000000
  }
}
```

**Client → Server**:
```json
{
  "type": "LOCATION_UPDATE",
  "payload": {
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 15.0
  }
}
```

**Rate Limit**: > 1 update per second is dropped per user

---

#### USER_CONNECTED

A new user joined the session.

**Server → Client**:
```json
{
  "type": "USER_CONNECTED",
  "payload": {
    "user_id": "bob_456",
    "display_name": "Bob",
    "privacy_mode": "direction_distance"
  }
}
```

---

#### USER_DISCONNECTED

A user left the session.

**Server → Client**:
```json
{
  "type": "USER_DISCONNECTED",
  "payload": {
    "user_id": "alice_123"
  }
}
```

---

#### PRIVACY_UPDATE

A user changed their privacy mode.

**Server → Client**:
```json
{
  "type": "PRIVACY_UPDATE",
  "payload": {
    "user_id": "alice_123",
    "privacy_mode": "direction_distance"
  }
}
```

---

#### CHAT_MESSAGE

(If chat enabled) A message in the session chat.

**Server → Client**:
```json
{
  "type": "CHAT_MESSAGE",
  "payload": {
    "user_id": "alice_123",
    "content": "Look to the left!",
    "message_type": "global",
    "timestamp": 1680000000000
  }
}
```

---

#### SESSION_ENDED

The admin terminated the session.

**Server → Client**:
```json
{
  "type": "SESSION_ENDED",
  "payload": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "reason": "admin_terminated"
  }
}
```

---

#### PULSE_PING

Periodic keep-alive to detect stale connections.

**Server → Client**:
```json
{
  "type": "PULSE_PING",
  "payload": {}
}
```

**Expected Client → Server Response**:
```json
{
  "type": "PULSE_PONG",
  "payload": {}
}
```

---

## Error Handling

### Error Response Format

All HTTP error responses follow this format:

```json
{
  "error": "Radar not found",
  "code": "NOT_FOUND",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### HTTP Status Codes

| Code | Description | Example |
|------|-------------|---------|
| 200 | Success | Session created, location updated |
| 400 | Bad Request | Invalid request body, missing required fields |
| 401 | Unauthorized | Invalid or expired JWT token |
| 403 | Forbidden | User not admin, cannot delete session |
| 404 | Not Found | Session ID doesn't exist, invalid passkey |
| 429 | Too Many Requests | Rate limit exceeded (see `Retry-After` header) |
| 500 | Internal Server Error | Redis unavailable, unexpected server error |
| 503 | Service Unavailable | Backend shutting down, Redis connection lost |

### Common Error Codes

| Code | Message | HTTP Code | Action |
|------|---------|-----------|--------|
| `NOT_FOUND` | Radar not found | 404 | Verify session ID and passkey |
| `UNAUTHORIZED` | Unauthorized | 401 | Re-authenticate and obtain new token |
| `FORBIDDEN` | Forbidden | 403 | Ensure you have required permissions |
| `RATE_LIMITED` | Rate limit exceeded | 429 | Wait `Retry-After` seconds and retry |
| `INVALID_REQUEST` | Invalid request | 400 | Check request body format |
| `SERVER_ERROR` | Server error | 500 | Retry with exponential backoff |

### Rate Limit Error Response

When rate-limited (429), response includes retry guidance:

```json
{
  "error": "Rate limit exceeded",
  "code": "RATE_LIMITED",
  "request_id": "abc123",
  "retry_after": 45
}
```

**Headers**:
```
Retry-After: 45
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1712100000
```

---

## Data Privacy & Compliance

### No Personal Data Logging

- **Never logged**: GPS coordinates (lat/lng)
- **Never logged**: User IDs in location payloads
- **Logged**: API endpoint, HTTP method, response code, request ID

### Ephemeral Data Deletion

All session data is automatically deleted:
- **On session termination**: Member list, locations, chat history
- **After 12-hour TTL**: All session keys expire and are cleaned up
- **On logout**: User's JWT is blacklisted for its remaining lifetime

### Token Security

- **Algorithm**: RS256 (RSA 2048-bit public key)
- **Issuer**: `https://radarapp.io`
- **Validity**: 24 hours
- **No sensitive data** in token payload (only user ID, session ID, role)

### Third-Party Data Sharing

- **None**: All location data stays within Ephemeral Radar
- **FCM tokens**: Sent only to Google FCM for push notifications
- **Analytics**: Only aggregate metrics (active sessions, peak users)

---

## Examples

### Complete Join Flow

1. **Create session**:
   ```bash
   curl -X POST https://api.radarapp.io/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{"session_name":"Hike","admin_id":"alice","chat_enabled":true,"region":"us-east"}'
   ```
   Response: `{"session_id":"...", "passkey":"ABC12345", "deep_link_url":"radarapp://join?..."}`

2. **Verify session** (before join):
   ```bash
   curl "https://api.radarapp.io/api/v1/sessions/verify?s=<session_id>&p=ABC12345"
   ```
   Response: `{"session_name":"Hike", "host_name":"alice", "active_members":0, "websocket_url":"wss://api.radarapp.io/ws"}`

3. **Issue token**:
   ```bash
   curl -X POST https://api.radarapp.io/api/v1/auth/token \
     -H "Content-Type: application/json" \
     -d '{"session_id":"...","passkey":"ABC12345","user_id":"bob"}'
   ```
   Response: `{"access_token":"eyJhbGciOiJSUzI1NiI..."}`

4. **Join session**:
   ```bash
   curl -X POST https://api.radarapp.io/api/v1/sessions/<session_id>/join \
     -H "Content-Type: application/json" \
     -d '{"user_id":"bob","display_name":"Bob","privacy_mode":"direction_distance"}'
   ```
   Response: `{"status":"joined"}`

5. **Connect WebSocket**:
   ```javascript
   const ws = new WebSocket(
     `wss://api.radarapp.io/ws/<session_id>?token=<access_token>`
   );
   
   ws.onmessage = (event) => {
     const msg = JSON.parse(event.data);
     if (msg.type === "LOCATION_UPDATE") {
       updateRadar(msg.payload);
     }
   };
   ```

6. **Send location update**:
   ```javascript
   ws.send(JSON.stringify({
     type: "LOCATION_UPDATE",
     payload: {
       lat: 37.7749,
       lng: -122.4194,
       accuracy: 15.0
     }
   }));
   ```

---

## Support & Documentation

- **Interactive Docs**: https://api.radarapp.io/docs
- **ReDoc**: https://api.radarapp.io/redoc
- **OpenAPI JSON**: https://api.radarapp.io/openapi.json
- **GitHub Issues**: https://github.com/radarapp/backend/issues
- **Contact**: support@radarapp.io
