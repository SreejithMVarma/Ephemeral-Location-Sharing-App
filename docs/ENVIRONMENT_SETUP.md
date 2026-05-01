# ✅ Environment Files Setup Complete

## 📌 Which Files to Use for Render Deployment

### 🚀 **Backend - Render Production**
**File**: `.env.production`

Copy these values to **Render Dashboard → Your Service → Settings → Environment**:

```
API_BASE_URL=https://ephemeral-location-sharing-app.onrender.com
REGION_WS_URLS={"us-east":"wss://ephemeral-location-sharing-app.onrender.com/ws"}
CORS_ALLOWED_ORIGINS=["https://ephemeral-location-sharing-app.onrender.com"]
REDIS_URL=redis://default:YOUR_PASSWORD@your-redis-host.c.composedb.com:18472
REDIS_MAX_CONNECTIONS=100
REDIS_ENABLE_KEYSPACE_LISTENER=true
APP_ENV=production
FCM_SENDER_ID=YOUR_PRODUCTION_FCM_SENDER_ID
DEEP_LINK_SCHEME=radarapp
```

### 🧪 **Backend - Render Staging**
**File**: `.env.staging`

Copy values to Render Staging Service Environment variables.

### 💻 **Backend - Local Development**
**File**: `.env.development`

Use locally with:
```bash
export $(cat .env.development | xargs)
cd apps/backend
poetry run uvicorn src.main:app --reload
```

---

## 📱 **Mobile App Configuration**

### 🚀 **Production (Play Store / TestFlight)**
**File**: `apps/mobile/env/prod.json`

Build with:
```bash
flutter build apk --dart-define-from-file=env/prod.json --release
flutter build ios --dart-define-from-file=env/prod.json --release
```

### 🧪 **Development - Android Emulator**
**File**: `apps/mobile/env/dev.json`

Run with:
```bash
flutter run --dart-define-from-file=env/dev.json
```

### 🧪 **Development - Physical Android Device (USB)**
**File**: `apps/mobile/env/dev.phone.json`

Run with:
```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define-from-file=env/dev.phone.json
```

---

## 🔧 **Render Redis Setup**

### Get Your Redis Connection String

1. Go to Render Dashboard → Your Redis Instance
2. Click **"Connect"**
3. Copy the **"Internal URL"** or **"External URL"**
4. Format: `redis://default:PASSWORD@HOST:PORT`

**Example:**
```
redis://default:abc123xyz789@oregon-redis-12345.c.composedb.com:18472
```

Replace in `.env.production`:
```
REDIS_URL=redis://default:abc123xyz789@oregon-redis-12345.c.composedb.com:18472
```

---

## ⚙️ **All Environment Variables Explained**

| Variable | Production Value | Local Dev Value | Description |
|----------|------------------|-----------------|-------------|
| `API_BASE_URL` | `https://app.onrender.com` | `http://localhost:8000` | Backend API endpoint |
| `REGION_WS_URLS` | `wss://` (secure WebSocket) | `ws://` (plain WebSocket) | Real-time connection |
| `CORS_ALLOWED_ORIGINS` | Your Render domain | `localhost:*` | Allowed request sources |
| `REDIS_URL` | Render Redis URL | `redis://127.0.0.1:6379/0` | Session/cache storage |
| `APP_ENV` | `production` | `development` | Runtime mode |
| `FCM_SENDER_ID` | Firebase ID | Dummy ID | Push notifications |
| `DEEP_LINK_SCHEME` | `radarapp` | `radarapp-dev` | Mobile deep linking |

---

## 📋 **Files Summary**

### Root Directory (Backend Configuration)
```
.env.example        ← Template reference (all possible variables)
.env.development    ← Local development (localhost:8000)
.env.staging        ← Render staging (copy to dashboard)
.env.production     ← Render production (copy to dashboard) ⭐ USE THIS
```

### Mobile Directory (Mobile App Configuration)
```
apps/mobile/env/dev.json          ← Android emulator development
apps/mobile/env/dev.phone.json    ← Physical USB Android device
apps/mobile/env/prod.json         ← Production build ⭐ USE THIS
```

### Documentation
```
docs/RENDER_DEPLOYMENT.md         ← Complete Render setup guide
docs/env-reference.md             ← Legacy env reference
docs/ARCHITECTURE.md              ← System architecture
```

---

## 🎯 **Next Steps**

### For Render Deployment:
1. ✅ Create Render Redis instance (get connection string)
2. ✅ Create Render Web Service for backend
3. ✅ Copy `.env.production` values to Render Dashboard
4. ✅ Deploy and test

### For Mobile Build:
1. ✅ Update FCM_SENDER_ID in `apps/mobile/env/prod.json`
2. ✅ Build with: `flutter build apk --dart-define-from-file=env/prod.json --release`
3. ✅ Submit to Play Store/TestFlight

---

## 🔐 **Security Notes**

⚠️ **Never commit actual passwords/secrets**
- `.env.development` is safe to commit (local values)
- `.env.production` and `.env.staging` should NOT have real passwords
- Always set real passwords in Render Dashboard directly
- Use environment variables, not hardcoded values

✅ **What's configured:**
- All files use placeholder values (YOUR_*, PASSWORD, etc.)
- Production URLs point to Render
- WebSocket uses secure `wss://` in production
- CORS properly restricted to your domain

---

**Created**: 2026-05-01  
**Environment Setup**: ✅ Complete  
**Ready for Render**: ✅ Yes  
**Mobile Ready**: ✅ Yes
