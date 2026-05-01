# Render Deployment Guide

## 🚀 Quick Setup: Backend + Redis on Render

### Prerequisites
- Render account (render.com)
- GitHub repository pushed (done ✓)
- Firebase project (for FCM_SENDER_ID)

### Step 1: Create Render Redis Database

1. Go to [render.com/dashboard](https://render.com/dashboard)
2. Click **"New +"** → **"Redis"**
3. Fill in:
   - **Name**: `ephemeral-location-sharing-redis`
   - **Region**: Choose closest to your users (e.g., `Oregon`)
4. Click **"Create Redis"**
5. **Copy the connection string** - you'll need this in Step 3

Example connection string:
```
redis://default:abc123xyz789==@oregon-redis-12345.c.composedb.com:18472
```

### Step 2: Create Render Web Service

1. Click **"New +"** → **"Web Service"**
2. **Connect your GitHub account**
3. Select repository: `Ephemeral-Location-Sharing-App`
4. Fill in configuration:

| Field | Value |
|-------|-------|
| **Name** | `ephemeral-location-sharing-app` |
| **Environment** | `Python 3` |
| **Region** | Same as Redis (e.g., `Oregon`) |
| **Branch** | `main` |
| **Build Command** | `pip install poetry && poetry install && cd apps/backend` |
| **Start Command** | `cd apps/backend && poetry run uvicorn src.main:app --host 0.0.0.0 --port 8000` |

5. Click **"Create Web Service"**

### Step 3: Add Environment Variables

In Render Dashboard → Your Web Service → **Settings** → **Environment**

Add these variables (replace YOUR_* with actual values):

```
API_BASE_URL=https://ephemeral-location-sharing-app.onrender.com
REGION_WS_URLS={"us-east":"wss://ephemeral-location-sharing-app.onrender.com/ws"}
CORS_ALLOWED_ORIGINS=["https://ephemeral-location-sharing-app.onrender.com"]
REDIS_URL=redis://default:PASSWORD@oregon-redis-12345.c.composedb.com:18472
REDIS_MAX_CONNECTIONS=100
REDIS_ENABLE_KEYSPACE_LISTENER=true
APP_ENV=production
FCM_SENDER_ID=1234567890
DEEP_LINK_SCHEME=radarapp
```

**For `REDIS_URL`:** Use the connection string from Step 1

**For `FCM_SENDER_ID`:** Get from Firebase Console → Project Settings → Cloud Messaging

### Step 4: Deploy

1. Click **"Manual Deploy"** or push to `main` branch to trigger auto-deploy
2. Wait for deployment to complete (green checkmark)
3. Your backend is now live at: `https://ephemeral-location-sharing-app.onrender.com`

---

## 📱 Mobile Configuration

### For Production Build
Use this file: **`apps/mobile/env/prod.json`**

Contains:
```json
{
  "API_BASE_URL": "https://ephemeral-location-sharing-app.onrender.com",
  "FCM_SENDER_ID": "YOUR_PRODUCTION_FCM_SENDER_ID",
  "DEEP_LINK_SCHEME": "radarapp",
  "REGION_WS_URLS": "{\"us-east\":\"wss://ephemeral-location-sharing-app.onrender.com/ws\"}"
}
```

Build command:
```bash
cd apps/mobile
flutter build apk --dart-define-from-file=env/prod.json --release
flutter build ios --dart-define-from-file=env/prod.json --release
```

### For Development (Local)

**Android Emulator:**
```bash
cd apps/mobile
flutter run --dart-define-from-file=env/dev.json
```

**USB Device:**
```bash
cd apps/mobile
# First setup adb reverse
adb reverse tcp:8000 tcp:8000
flutter run --dart-define-from-file=env/dev.phone.json
```

---

## 📋 Configuration Files Reference

| File | Use Case | Notes |
|------|----------|-------|
| `.env.example` | Template reference | All possible variables |
| `.env.development` | Local dev with Redis Docker | For `docker run` Redis |
| `.env.production` | Render production | Copy values to Render Dashboard |
| `.env.staging` | Render staging environment | For testing before production |
| `apps/mobile/env/dev.json` | Android emulator dev | Uses `10.0.2.2` for host |
| `apps/mobile/env/dev.phone.json` | Physical USB Android device | Uses `127.0.0.1` with adb |
| `apps/mobile/env/prod.json` | Production mobile build | Render URLs with `wss://` |

---

## 🔐 Environment Variables Explained

| Variable | Value | Description |
|----------|-------|-------------|
| `API_BASE_URL` | `https://your-render-url.onrender.com` | Mobile HTTP requests go here |
| `REGION_WS_URLS` | `{"us-east":"wss://..."}` | WebSocket for real-time updates |
| `CORS_ALLOWED_ORIGINS` | `["https://..."]` | Allowed request origins |
| `REDIS_URL` | `redis://default:PASSWORD@host:port` | Session storage & caching |
| `APP_ENV` | `production` | Runtime environment |
| `FCM_SENDER_ID` | Firebase ID | For push notifications |
| `DEEP_LINK_SCHEME` | `radarapp` | Mobile deep linking |

---

## ✅ Testing Your Deployment

### Test Backend Health
```bash
curl https://ephemeral-location-sharing-app.onrender.com/health
```

Should return `200 OK` with service status.

### Test WebSocket Connection
```bash
# Using websocat
websocat wss://ephemeral-location-sharing-app.onrender.com/ws
```

### Monitor Logs
In Render Dashboard → Your Service → **Logs**
- Check for startup errors
- Monitor request activity

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| **Deployment failed** | Check Render Logs → Look for missing env vars or build errors |
| **"Connection refused"** | Verify Redis instance is running and `REDIS_URL` is correct |
| **Mobile can't reach API** | Ensure `API_BASE_URL` is accessible and `CORS_ALLOWED_ORIGINS` includes your domain |
| **WebSocket connection fails** | Check `REGION_WS_URLS` format and verify service is running |
| **Port already in use** | Render automatically selects a port, ensure Start Command uses `0.0.0.0:8000` |

---

## 📚 Additional Resources

- [Render Documentation](https://render.com/docs)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Redis on Render](https://render.com/docs/redis)
- Project README: [README.md](../README.md)
- Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)
