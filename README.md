# Campus Bus Live Tracking & Notification System
### Dr. Harisingh Gour University (DHSGU), Sagar, M.P.

A production-grade, real-time campus shuttle tracking and notification ecosystem built for students, drivers, and transport administrators.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph DriverApp["Driver Mobile App (Flutter)"]
        D_UI["Cockpit Interface"]
        D_FGS["Android Foreground Service<br/>(Background GPS Streaming)"]
        D_SOCK["Socket.IO Client"]
        D_UI --> D_FGS --> D_SOCK
    end

    subgraph BackendEngine["Backend Engine (Node.js & Express)"]
        B_SOCK["Socket.IO Server"]
        B_GEO["GPS Validation & Distance Engine"]
        B_TRIP["Trip State Machine<br/>(7-Sequence Circular Route)"]
        B_NOTIF["Notification Service<br/>(Deduplication & Multi-Device)"]
        B_BREVO["Brevo Email Service<br/>(Student OTP Verification)"]
        
        B_SOCK --> B_GEO --> B_TRIP --> B_NOTIF
    end

    subgraph Storage["Databases & Infrastructure"]
        DB_MONGO[("MongoDB Atlas<br/>(Users, Trips, Stops, Tokens)")]
        DB_REDIS[("Redis Cache<br/>(Realtime GPS & Dedup Keys)")]
        FCM["Firebase Cloud Messaging<br/>(System Tray Push Alerts)"]
    end

    subgraph StudentApp["Student Mobile App (Flutter)"]
        S_MAP["Map-First Interface<br/>(Road-Following Polyline)"]
        S_WAIT["I'm Waiting Counter"]
        S_NOTIF_RCV["FCM Background Receiver<br/>(Notification Tray Alerts)"]
        S_SOCK["Socket.IO Real-Time Stream"]
    end

    D_SOCK -- "driver:location (2s interval)" --> B_SOCK
    B_TRIP --> DB_MONGO
    B_GEO --> DB_REDIS
    B_NOTIF -- "High Priority FCM" --> FCM --> S_NOTIF_RCV
    B_BREVO -- "Transactional OTP" --> StudentApp
    B_SOCK -- "driver_location_updated<br/>stop_reached / next_stop_updated" --> S_SOCK --> S_MAP
```

---

## Key Features

### 1. Driver Cockpit & Background GPS Tracking
- **Automated Workflow**: Driver only logs in, verifies the assigned vehicle (`BUS-01` to `BUS-04`), presses **START TRIP**, and drives.
- **Android 14+ Foreground Service**: Uses `android:foregroundServiceType="location"` with a persistent system notification (`Campus Bus • BUS-04 is tracking live GPS`).
- **Continuous Background Tracking**: Location streams continue without interruption when the phone is locked, minimized, or switched to another app.
- **Offline Buffering**: Buffers coordinates in memory if internet is lost; flushes the latest location immediately when the socket reconnects.
- **Smart GPS Throttling**: Suppresses duplicate transmissions when stationary (displacement < 3m, speed < 0.5 m/s) with an 8-second heartbeat.
- **Vehicle Reassignment**: Drivers can switch buses via an interactive bottom sheet with conflict prevention (`BUS_UNAVAILABLE` rejection if another trip is active).

### 2. Server-Authoritative Stop Progression & Detection
- **Dual-Phase Stop Detection**:
  - **Approach Phase (120 meters)**: Emits `next_stop_updated` (`approaching: true`) and triggers `BUS_APPROACHING_STOP` FCM push alert to waiting pickup students.
  - **Arrival Phase (45 meters)**: Automatically completes the current stop, advances the route sequence, and triggers `BUS_ARRIVED_STOP` FCM push alert.
- **Accuracy Filtering**: GPS readings with an accuracy error > 50 meters are rejected to prevent false triggers caused by GPS jitter.
- **Strict Deduplication**: Uses deterministic deduplication keys (`tripId + routeStopId + type`) across Redis and MongoDB to guarantee at-most-once notification delivery.
- **Final Stop Confirmation**: When Sequence 7 (Center Point Final) is reached, prompts driver for confirmation rather than abruptly auto-killing the trip.

### 3. Student Mobile Experience
- **Map-First UI**: Custom OpenStreetMap canvas with rich road-following polyline geometry along university avenues and highway bypasses.
- **Sequence-Aware Timeline**: Correctly displays all stops on the circular route, distinguishing between multiple Center Point occurrences.
- **System Tray Push Notifications**: Background FCM notifications arrive in the Android notification drawer with high priority and proper notification channel (`campus_bus_alerts`).
- **"I'm Waiting" System**: Students can flag their presence at a pickup stop, updating driver and campus-wide counters in real-time.
- **Responsive Layout**: Zero RenderFlex overflows across all device widths (320px, 360px, 375px, 390px, 412px, 430px).
- **Brevo Email Authentication**: Secure 6-digit OTP delivery for registration and password resets.

---

## Verified Bus Stops & Route Order

### 1. Verified Campus Stop Coordinates
| Stop Name | Latitude | Longitude |
| :--- | :--- | :--- |
| **Computer Science Department** | `23.824232252667205` | `78.78215542847788` |
| **Criminology Department** | `23.823290586415027` | `78.78310833763173` |
| **Center Point** | `23.826769418621495` | `78.77207848833157` |
| **Boys Hostel** | `23.822333272296800` | `78.77027060622879` |
| **Girls Hostel** | `23.831797143673885` | `78.78234670088726` |

### 2. Fixed Circular Route Order (7 Sequences)
> [!IMPORTANT]
> **Center Point** appears 3 times in the route. All systems identify stops by **`sequence`** and **`routeStopId`**, never by name alone.

```
Sequence 1: Center Point (Origin)
    ↓
Sequence 2: Computer Science Department
    ↓
Sequence 3: Criminology Department
    ↓
Sequence 4: Center Point (Midway Junction)
    ↓
Sequence 5: Boys Hostel
    ↓
Sequence 6: Girls Hostel
    ↓
Sequence 7: Center Point (Final Destination)
```

---

## Repository Structure

```
campus-bus-system/
├── .gitignore                   # Root gitignore (covers node, flutter, android, secrets)
├── README.md                    # Global architecture and project documentation
│
├── backend/                     # Node.js + Express + Socket.IO + MongoDB API
│   ├── .env.example             # Template for environment variables
│   ├── .gitignore               # Backend-specific ignore rules
│   ├── package.json             # Backend dependencies and scripts
│   ├── src/
│   │   ├── config/              # Database, Redis, Brevo, Firebase configuration
│   │   ├── controllers/         # Driver, student, auth, notification controllers
│   │   ├── middleware/          # JWT auth, role validation, rate limiters
│   │   ├── models/              # Mongoose models (User, Bus, Trip, DeviceToken, etc.)
│   │   ├── routes/              # Express REST route definitions
│   │   ├── services/            # Trip engine, locationService, notificationService
│   │   ├── sockets/             # Socket.IO connection handlers and emitters
│   │   └── utils/               # Haversine distance, geometry, constants, validators
│   └── src/__tests__/           # Unit and integration test suites (16 tests)
│
├── driver_app/                  # Flutter Driver Application
│   ├── .gitignore               # Flutter driver ignore rules
│   ├── pubspec.yaml             # Flutter dependencies
│   ├── android/                 # Android manifest with Location Foreground Service
│   ├── lib/
│   │   ├── core/                # Theme and route configuration
│   │   ├── providers/           # TripProvider, AuthProvider
│   │   ├── screens/             # HomeScreen (Cockpit), RouteScreen, ProfileScreen
│   │   ├── services/            # DeviceLocationService, SocketService, ApiClient
│   │   └── widgets/             # BusSelectionSheet, responsive cards
│   └── test/                    # Responsive layout and smoke tests (13 tests)
│
└── student_app/                 # Flutter Student Application
    ├── .gitignore               # Flutter student ignore rules
    ├── pubspec.yaml             # Flutter dependencies
    ├── android/                 # Android manifest with POST_NOTIFICATIONS & channels
    ├── lib/
    │   ├── core/                # App theme, verified coordinates
    │   ├── providers/           # LiveProvider, AuthProvider
    │   ├── screens/             # HomeScreen, NotificationsScreen, ProfileScreen
    │   ├── services/            # FcmService, SocketService, RouteGeometryService
    │   └── widgets/             # RouteSheet, WaitingSheet, custom markers
    └── test/                    # Coordinate verification and layout tests (31 tests)
```

---

## GitHub Push Guidelines

### What to PUSH to GitHub
- Source code files (`.js`, `.dart`, `.kt`, `.json`, `.xml`, `.yaml`, `.md`).
- Project configuration templates: `backend/.env.example`.
- App assets (icons, images, sound files).
- Unit and responsive test files.
- Gradle build scripts (`build.gradle.kts`, `settings.gradle.kts`).

### What NOT to Push (Ignored by `.gitignore`)
- **Environment & Secrets**: `backend/.env` (contains MongoDB connection string, Brevo API key, JWT secret, Firebase private key).
- **Dependencies**: `node_modules/`, `.dart_tool/`, `.pub/`, `.pub-cache/`.
- **Machine-Specific Configurations**: `local.properties` (contains local machine Android SDK paths).
- **Build Artifacts**: `build/`, `dist/`, `.gradle/`, `*.apk`, `*.aab`.
- **Signing Keys**: `*.jks`, `*.keystore`.
- **IDE Caches**: `.idea/`, `.vscode/`, `*.iml`.
- **OS Metadata**: `.DS_Store`, `Thumbs.db`, `*.log`.

---

## Setup & Installation

### Prerequisites
- **Node.js**: v18.0.0 or higher
- **Flutter SDK**: v3.13.2 or higher
- **MongoDB**: MongoDB Atlas cluster or local instance (v6.0+)
- **Redis**: Local Redis server (port 6379) or Redis Cloud (in-memory fallback available)
- **Brevo Account**: Active API key for email OTP delivery
- **Firebase Project**: Firebase Cloud Messaging enabled for Android

---

### Step 1: Backend Setup

1. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Configure Environment Variables**:
   Copy `.env.example` to `.env` and fill in your credentials:
   ```bash
   cp .env.example .env
   ```
   Required variables:
   ```env
   PORT=4000
   NODE_ENV=development
   MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/campus_bus
   JWT_SECRET=your-secure-random-jwt-secret
   BREVO_API_KEY=xkeysib-your-brevo-key
   BREVO_SENDER_EMAIL=your-verified-sender@example.com
   BREVO_SENDER_NAME="Campus Bus DHSGU"
   FIREBASE_PROJECT_ID=registration-a6358
   FIREBASE_CLIENT_EMAIL=your-firebase-admin-email
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   ```

4. **Seed Database (Stops, Route, Fleet & Accounts)**:
   ```bash
   npm run seed
   ```
   *Default seed credentials:*
   - Driver: `driver@dhsgu.ac.in` / `Driver@12345` (Assigned to `BUS-04`)
   - Admin: `admin@dhsgu.ac.in` / `Admin@12345`

5. **Run Tests**:
   ```bash
   npm test
   ```

6. **Start Backend Server**:
   ```bash
   npm run dev
   ```

---

### Step 2: Driver App Setup

1. **Navigate to the driver app directory**:
   ```bash
   cd driver_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Firebase Config**:
   Ensure `driver_app/android/app/google-services.json` is present.

4. **Run Analysis & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

5. **Run the App**:
   ```bash
   flutter run
   ```

---

### Step 3: Student App Setup

1. **Navigate to the student app directory**:
   ```bash
   cd student_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Firebase Config**:
   Ensure `student_app/android/app/google-services.json` is present.

4. **Run Analysis & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

5. **Run the App**:
   ```bash
   flutter run
   ```

---

## API & Socket.IO Specification

### REST Endpoints
| Method | Route | Description | Auth |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/register` | Student sign-up with Brevo OTP dispatch | Public |
| `POST` | `/api/auth/verify-otp` | Verify 6-digit registration OTP | Public |
| `POST` | `/api/auth/login` | Student or Driver authentication | Public |
| `GET` | `/api/student/live` | Current campus live state & waiting counts | Student |
| `PATCH`| `/api/student/pickup-stop` | Update student's selected pickup stop | Student |
| `POST` | `/api/student/waiting` | Flag presence ("I'm Waiting") | Student |
| `DELETE`|`/api/student/waiting` | Cancel waiting status | Student |
| `POST` | `/api/student/fcm-token` | Register/update device FCM token | Student |
| `DELETE`|`/api/student/fcm-token` | Deactivate device FCM token on logout | Student |
| `GET` | `/api/driver/buses` | Fleet list with availability status | Driver |
| `POST` | `/api/driver/bus/assign` | Assign bus to driver | Driver |
| `POST` | `/api/driver/trip/start` | Start trip on active route | Driver |
| `POST` | `/api/driver/trip/pause` | Temporarily pause trip | Driver |
| `POST` | `/api/driver/trip/resume` | Resume paused trip | Driver |
| `POST` | `/api/driver/trip/end` | Confirm and complete trip | Driver |
| `POST` | `/api/driver/stop/skip` | Skip upcoming route stop | Driver |

### Socket.IO Real-Time Events
| Event Name | Direction | Payload Description |
| :--- | :--- | :--- |
| `driver:location` | Client → Server | High-precision GPS reading `{ latitude, longitude, speed, heading, accuracy, timestamp }` |
| `driver_location_updated` | Server → Campus | Live bus position, heading, speed, current stop, next stop, road ETA |
| `next_stop_updated` | Server → Campus | Next route sequence, ETA string, and `approaching` flag |
| `stop_reached` | Server → Campus | Arrival event `{ reachedStop: { id, name, sequence }, isFinalStopReached }` |
| `stop_skipped` | Server → Campus | Skipped stop details `{ skippedStop: { id, name, sequence } }` |
| `student_waiting_updated` | Server → Campus | Live headcounts per stop for driver and student dashboards |
| `driver_trip_paused` | Server → Campus | Trip pause notification with optional driver reason |
| `driver_trip_resumed` | Server → Campus | Trip resumed broadcast |
| `driver_trip_ended` | Server → Campus | Trip completion and bus offline broadcast |
| `notification_created` | Server → User | In-app notification delivery to active connected users |

---

## Test Verification Summary

| Test Suite | Total Tests | Result | Coverage Highlights |
| :--- | :---: | :---: | :--- |
| **Backend** | 16 | **PASS** | Brevo OTP, Zod validation, 7-stop circular sequence logic, final stop confirmation, notification deduplication keys, GPS accuracy jitter filter |
| **Driver App** | 13 | **PASS** | Full responsive layout (320px–430px), zero RenderFlex overflow, cockpit header, bus selection sheet |
| **Student App** | 31 | **PASS** | Verified stop coordinates, road-following polylines (>200 coordinates), responsive header layouts (320px–430px) |

---

## License & University Attribution
Developed for **Dr. Harisingh Gour University (A Central University), Sagar, Madhya Pradesh, India**.  
All rights reserved © 2026.
