# 🕐 BitHabit

> **A habit-tracking app for small study groups.**  
> Record study sessions via webcam, auto-generate GIFs, and share progress in real-time chat.

🌐 **Live**: [habit.bit-habit.com](https://habit.bit-habit.com)  
📦 **Repo**: [github.com/bookseal/bithabit](https://github.com/bookseal/bithabit)  
🏆 **2nd Place — IITP Hackathon** · Users still active after 2 years

---

## Why This Exists

Habit apps like Challengers focus on growing user numbers, but sacrifice **proof quality**. In a "walk the stairs" challenge, just taking a photo of stairs counts as proof. That's too easy to fake.

What people actually need is proof that they **focused for 20+ minutes** — and a way to share it that's lightweight and trustworthy.

### BitHabit vs Challengers

| | Challengers | BitHabit |
|---|---|---|
| Proof method | Single photo | **Time-lapse video (random interval captures)** |
| Fake risk | High (reuse old photos) | **Low (date/name overlay + random timing)** |
| File size | N/A | **Much smaller than video (GIF)** |
| Group size | Large (less accountability) | **Small (3-5 people, real accountability)** |
| Still used after 2 years? | — | **Yes** |

---

## Core Flow

```mermaid
flowchart LR
    A["Start Session\nActivate webcam"] --> B["Every 5 seconds\nCapture frame via Canvas"]
    B --> C["Stop\ngif.js (Web Worker)"]
    C --> D["Generate GIF\n+ date/name overlay"]
    D --> E["Share to chat\nbase64 via POST"]
    E --> F["WebSocket broadcast\nAll users see it instantly"]
```

---

## Screenshots

### Login — Passwordless Email OTP
<img src="screenshots/01_login.png" width="320" alt="Login screen" />

Enter email → get a 6-digit code → sign in. No password needed.

### Login Page — Built-in About Section
<img src="screenshots/02_login_about.png" width="320" alt="Login with About section" />

The login page doubles as a portfolio — feature cards, tech stack, and data flow are shown before signup.

### Chat Room — Real-time Messaging
- **"Start Session" button** — opens the webcam timer
- **WebSocket real-time** — messages appear instantly for everyone
- **Members drawer** — tap 👥 to see all members

### Study Timer — Webcam + GIF
Webcam activates, timer runs, frames are captured every 5 seconds. On stop, a GIF is generated and can be shared to the chat room.

---

## Architecture

```mermaid
graph TB
    subgraph Client ["Flutter Web (Dart)"]
        A[Login Screen] -->|email| B[OTP Verification]
        B -->|JWT| C[Home Screen]
        C -->|webcam| D[Capture Service]
        D -->|frames| E[GIF Service - gif.js]
        C --> F[Chat Screen]
        F -->|WebSocket| G[Live Messages]
        F --> H[Members List]
    end

    subgraph Server ["FastAPI (Python)"]
        I[POST /api/auth/send-otp]
        J[POST /api/auth/verify-otp]
        N[GET /api/messages]
        O[POST /api/messages]
        Q[WS /api/ws]
    end

    subgraph Infra ["Kubernetes (k3s)"]
        R[Traefik Ingress] -->|/api/*| S[bithabit-api Pod]
        R -->|/*| T[nginx Pod - Flutter static]
        S --> U[(SQLite)]
        S --> V[Gmail SMTP]
    end

    A --> I
    B --> J
    F --> N
    F -->|GIF base64| O
    F --> Q
    Q --> G
```

---

## Auth — Email OTP + JWT

No passwords. Users verify their email with a one-time code, then get JWT tokens.

```mermaid
sequenceDiagram
    participant U as User
    participant F as Flutter
    participant API as FastAPI
    participant DB as SQLite
    participant G as Gmail SMTP

    U->>F: Enter email
    F->>API: POST /api/auth/send-otp
    API->>API: Generate 6-digit OTP
    API->>DB: Save OTP + expiry (5 min)
    API->>G: Send via SMTP
    G-->>U: 📧 "Code: 483921"
    U->>F: Enter OTP
    F->>API: POST /api/auth/verify-otp
    API->>DB: Check match + expiry
    API->>API: Create JWT (Access 7d + Refresh 30d)
    API-->>F: {user, access_token, refresh_token}
    F->>F: Save tokens locally
    F->>F: Go to ChatScreen
```

### Why these token lifetimes?

| Decision | Value | Why |
|---|---|---|
| Access token | 7 days | Users visit ~5x/week — rarely need to re-auth |
| Refresh token | 30 days | Skip a week and still stay logged in |
| Algorithm | HS256 | Simple, enough for single-server setup |
| Server-side storage | None (stateless) | Pure signature check, no DB query needed |

---

## GIF Pipeline — $0 Server Cost

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
        Cap->>Cap: Add date/name overlay
    end
    U->>Cap: Stop (or 20-min auto-alert)
    Cap->>GIF: Send frames (data URLs)
    GIF->>GIF: Web Worker renders GIF
    GIF-->>U: Preview + Download
    U->>Chat: Share GIF (base64 POST)
    Chat->>Chat: WebSocket broadcasts to all
```

**Key design choices:**
- **Client-side GIF** — gif.js runs in a Web Worker. Server does zero work
- **Date/name overlay** — Canvas `drawText()` prevents reusing others' recordings
- **20-minute alert** — beep + blink animation when time is up
- **Random capture timing** — harder to game with pre-recorded content

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Frontend | **Flutter Web** (Dart) | One codebase for web and mobile |
| Backend | **FastAPI** (Python) | Async REST + WebSocket |
| Database | **SQLite** + SQLAlchemy | Lightweight, fits single server |
| Auth | **Email OTP + JWT** | No passwords, stateless |
| Real-time | **WebSocket** broadcast | Live chat |
| GIF Engine | **gif.js** (Web Worker) | Runs on client, $0 server cost |
| Infra | **k3s** + Traefik + HTTPS | Production Kubernetes |

---

## Deployment

```
habit.bit-habit.com
    │
    ├── Traefik Ingress (TLS)
    │     ├── /api/*  →  bithabit-api Pod (FastAPI :8000)
    │     └── /*      →  static-web Pod (nginx, Flutter build)
    │
    ├── bithabit-api
    │     ├── Env: GMAIL_ADDRESS, GMAIL_APP_PASSWORD, JWT_SECRET
    │     └── Volume: /data/bithabit.db + /data/uploads/
    │
    └── static-web
          └── Volume: Flutter build/web/
```

---

## Project Structure

```
bithabit_flutter/               # Frontend
├── lib/
│   ├── main.dart               # Entry + auto-login logic
│   ├── screens/
│   │   ├── login_screen.dart   # Email → OTP → Register
│   │   ├── home_screen.dart    # Camera + Timer + GIF
│   │   └── chat_screen.dart    # Real-time chat + Members
│   ├── services/
│   │   ├── api_service.dart    # REST client + JWT
│   │   ├── camera_service.dart # getUserMedia wrapper
│   │   ├── capture_service.dart# Frame capture
│   │   └── gif_service.dart    # gif.js interop
│   └── widgets/

bithabit_api/                   # Backend
├── main.py                     # FastAPI + JWT + WebSocket
├── models.py                   # SQLAlchemy models
├── database.py                 # SQLite connection
├── requirements.txt
└── Dockerfile
```

---

## Run Locally

```bash
# Backend
cd bithabit_api
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080

# Frontend (dev)
cd bithabit_flutter
flutter pub get && flutter run -d chrome

# Frontend (production)
flutter build web
```

---

Built with Flutter + FastAPI. Deployed via k3s on Oracle OCI.
