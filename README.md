# 🕐 BitHabit

> **A habit-tracking web app for small study groups.**  
> Record study sessions via webcam, auto-generate GIFs, and share progress in real-time chat.

🌐 **Live**: [habit.bit-habit.com](https://habit.bit-habit.com) · 5 active daily users  
📦 **Repo**: [github.com/bookseal/bithabit](https://github.com/bookseal/bithabit)

---

## Screenshots

### Login — Passwordless Email OTP
<img src="screenshots/01_login.png" width="320" alt="Login screen" />

Enter your email → receive a 6-digit code → sign in. No password needed.  
New users are auto-directed to a registration step where the email prefix becomes the default nickname.

### Login Page — Built-in About Section
<img src="screenshots/02_login_about.png" width="320" alt="Login with About section" />

Below the login form, the app renders an interactive **About BitHabit** section directly in the UI:

- **Feature grid** — 6 cards: Study Timer, GIF Export, Live Chat, 20-min Alert, Attendance, Email Auth
- **Tech stack chips** — Flutter Web, Dart, FastAPI, Python, SQLite, WebSocket, Gmail SMTP, gif.js
- **Data flow summary** — Login → Start → Stop → Share, each step explained in one line

This serves as both a portfolio showcase and user onboarding — visitors see what the app does before signing up.

### Chat Room — Real-time Messaging
<!-- To add: capture from a real browser with camera permission -->
The chat screen features:
- **"Start Session" button** — navigates to the webcam timer screen
- **Message list** — text and GIF messages with sender avatars, timestamps
- **WebSocket real-time** — new messages appear instantly for all connected users
- **Members drawer** — tap the 👥 icon to see all registered members with `you` badge

### Study Timer — Webcam + GIF Pipeline
The home screen activates the webcam, runs a study timer, captures frames every 5 seconds, and generates an animated GIF on stop. The GIF can be downloaded or shared directly to the chat room.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | **Flutter Web** (Dart) — single codebase for web/mobile |
| Backend | **FastAPI** (Python) — async REST API + WebSocket |
| Database | **SQLite** via SQLAlchemy ORM |
| Auth | **Email OTP + JWT** — passwordless, stateless token auth |
| Real-time | **WebSocket** broadcast for live chat |
| GIF Engine | **gif.js** (client-side, Web Worker-based) |
| Infra | **Kubernetes (k3s)** + Traefik Ingress + HTTPS |

---

## Architecture

```mermaid
graph TB
    subgraph Client [Flutter Web - Dart]
        A[Login Screen] -->|email input| B[OTP Verification]
        B -->|JWT issued| C[Home Screen]
        C -->|webcam frames| D[Capture Service]
        D -->|captured images| E[GIF Service - gif.js]
        C -->|navigate| F[Chat Screen]
        F -->|WebSocket| G[Live Messages]
        F -->|open drawer| H[Members List]
    end

    subgraph Server [FastAPI - Python]
        I[POST /api/auth/send-otp]
        J[POST /api/auth/verify-otp]
        K[POST /api/auth/register]
        L[GET /api/auth/me]
        M[POST /api/auth/refresh]
        N[GET /api/messages]
        O[POST /api/messages]
        P[GET /api/users]
        Q[WS /api/ws]
    end

    subgraph Infra [Kubernetes k3s]
        R[Traefik Ingress] -->|/api/*| S[bithabit-api Pod]
        R -->|/*| T[nginx Pod - Flutter static]
        S --> U[(SQLite)]
        S --> V[Gmail SMTP]
    end

    A -->|POST| I
    B -->|POST| J
    F -->|GET| N
    F -->|POST + GIF base64| O
    F -->|connect| Q
    Q -->|broadcast| G
    H -->|GET| P
```

---

## Auth — Email OTP + JWT Token System

Zero passwords. Users prove identity via email OTP, then receive JWT tokens for persistent sessions.

### Login Flow (OTP → JWT issuance)

```mermaid
sequenceDiagram
    participant U as User
    participant F as Flutter<br/>login_screen.dart
    participant API as FastAPI<br/>main.py
    participant DB as SQLite
    participant G as Gmail SMTP

    U->>F: Enter email
    F->>API: POST /api/auth/send-otp
    API->>API: generate_otp() → 6-digit code
    API->>DB: Save otp_code + otp_expires_at (5 min)
    API->>G: send_otp_email() via SMTP
    G-->>U: 📧 "Code: 483921"
    U->>F: Enter 6-digit code
    F->>API: POST /api/auth/verify-otp {email, otp}
    API->>DB: Check otp_code match + expiry
    API->>API: create_access_token() → 7-day JWT
    API->>API: create_refresh_token() → 30-day JWT
    API-->>F: {user, access_token, refresh_token}
    F->>F: saveTokens() → SharedPreferences
    F->>F: Navigate to HomeScreen
```

### Auto-Login Flow (token-based, no re-authentication)

Users stay logged in for up to 30 days without re-entering email/OTP.

```mermaid
sequenceDiagram
    participant F as Flutter<br/>main.dart → AuthWrapper
    participant S as SharedPreferences<br/>(localStorage)
    participant API as FastAPI<br/>main.py

    F->>S: Read access_token
    alt access_token exists
        F->>API: GET /api/auth/me<br/>Authorization: Bearer {token}
        API->>API: verify_token() → decode JWT
        alt Token valid (within 7 days)
            API-->>F: {id, username} ✅
            F->>F: Navigate to ChatScreen
        else Token expired
            F->>S: Read refresh_token
            F->>API: POST /api/auth/refresh
            API->>API: verify_token() → check type=refresh
            alt Refresh valid (within 30 days)
                API->>API: create_access_token() + create_refresh_token()
                API-->>F: New token pair ✅
                F->>S: saveTokens()
                F->>F: Navigate to ChatScreen
            else Refresh expired
                API-->>F: 401 Unauthorized
                F->>S: clearTokens()
                F->>F: Show LoginScreen
            end
        end
    else No token
        F->>F: Show LoginScreen
    end
```

### JWT Implementation Details

| Component | File | Function | Description |
|-----------|------|----------|-------------|
| Token creation | `main.py` | `create_access_token()` | HS256-signed JWT, 7-day expiry, payload: `{sub, username, type}` |
| Token creation | `main.py` | `create_refresh_token()` | HS256-signed JWT, 30-day expiry, payload: `{sub, type}` |
| Token verification | `main.py` | `verify_token()` | Decodes + validates signature and expiry via `python-jose` |
| Route protection | `main.py` | `get_current_user()` | FastAPI `Depends()` — extracts Bearer token → returns `User` |
| Token storage | `api_service.dart` | `saveTokens()` | Saves both tokens to `SharedPreferences` (browser localStorage) |
| Auto-login | `api_service.dart` | `tryAutoLogin()` | Tries access → falls back to refresh → clears on failure |
| Logout | `api_service.dart` | `clearTokens()` | Removes all tokens + user data from localStorage |
| Auth header | `api_service.dart` | `_authHeaders()` | Injects `Authorization: Bearer` into every API request |
| Members list | `api_service.dart` | `getUsers()` | Fetches all registered users for the members drawer |

**Design choices:**
- **7-day access token** — users access ~5x/week, so 7 days means they rarely need to re-authenticate
- **30-day refresh token** — even if they skip a week, they stay logged in
- **HS256 signing** — symmetric key, simple for single-server deployment
- **Stateless** — server never stores tokens; validation is pure signature check (no DB query)
- **Graceful degradation** — message API accepts requests with or without JWT for backward compatibility

---

## Study Session → GIF Pipeline

```mermaid
sequenceDiagram
    participant U as User
    participant Cam as CameraService
    participant Cap as CaptureService
    participant GIF as GifService (gif.js)
    participant Chat as ChatScreen

    U->>Cam: Start (getUserMedia)
    loop Every 5 seconds
        Cam->>Cap: Capture frame via Canvas
    end
    U->>Cap: Stop
    Cap->>GIF: Pass captured frames (data URLs)
    GIF->>GIF: Web Worker renders GIF
    GIF-->>U: Preview + Download
    U->>Chat: Share GIF (base64 via POST /api/messages)
    Chat->>Chat: WebSocket broadcasts to all users
```

**Technical highlights:**
- **Client-side GIF generation** — no server compute needed; gif.js runs in a Web Worker
- **Canvas-based frame capture** — `drawImage()` from `<video>` element every 5s
- **20-minute alert** — AudioContext oscillator beep + CSS blink animation
- **Camera switch** — `facingMode` toggle between `user` and `environment`

---

## Project Structure

```
bithabit_flutter/               # Frontend
├── lib/
│   ├── main.dart               # App entry, AuthWrapper (auto-login logic)
│   ├── screens/
│   │   ├── login_screen.dart   # Email → OTP → Register (3-step flow)
│   │   ├── home_screen.dart    # Camera + Timer + GIF generation
│   │   └── chat_screen.dart    # Real-time chat + Members drawer
│   ├── services/
│   │   ├── api_service.dart    # REST API client + JWT token management
│   │   ├── camera_service.dart # getUserMedia wrapper
│   │   ├── capture_service.dart# Periodic frame capture (Canvas)
│   │   └── gif_service.dart    # gif.js JS interop
│   └── widgets/                # Reusable UI components
│
bithabit_api/                   # Backend
├── main.py                     # FastAPI app, endpoints + JWT auth + WebSocket
├── models.py                   # SQLAlchemy models (User, Message)
├── database.py                 # SQLite connection
├── requirements.txt            # python-jose, fastapi, sqlalchemy, etc.
└── Dockerfile                  # Production container image
```

---

## Deployment

```
habit.bit-habit.com
    │
    ├── Traefik Ingress (TLS termination)
    │     ├── /api/*  →  bithabit-api Pod (FastAPI, port 8000)
    │     └── /*      →  static-web Pod (nginx, Flutter build/web)
    │
    ├── bithabit-api Deployment
    │     ├── Docker image: bithabit-api:latest
    │     ├── Env: GMAIL_ADDRESS, GMAIL_APP_PASSWORD, JWT_SECRET
    │     └── Volume: hostPath → /data/bithabit.db + /data/uploads/
    │
    └── static-web Deployment
          └── Volume: hostPath → bithabit_flutter/build/web/
```

`flutter build web` → files are live instantly (nginx serves from hostPath mount).

---

## Local Development

```bash
# Backend
cd bithabit_api
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080

# Frontend (dev mode)
cd bithabit_flutter
flutter pub get && flutter run -d chrome

# Frontend (production build)
flutter build web  # → build/web/
```
