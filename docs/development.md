# Fit Odyssey — Local Development & Testing Guide

> **Stack:** Flutter (Mobile, Android First) • Supabase (Postgres, RLS, Auth, RPC, pg_cron, Edge Function) • React + Vite (Dashboard)

---

## 1. Prerequisites & Environment Setup

Ensure the following runtimes and tools are installed on your workstation:

| Tool | Recommended Version | Purpose |
|---|---|---|
| **Flutter SDK** | `>= 3.22.x` (Dart `>= 3.4.x`) | Mobile application development and engine tests |
| **Android Studio** | Latest Stable (Koala / Ladybug) | Android SDK (API 34), NDK, Android emulator / device debugging |
| **Docker Desktop / Engine** | `>= 24.x` | Required by Supabase CLI to run local PostgreSQL, Auth, and Edge containers |
| **Supabase CLI** | `>= 1.160.x` | Local database migrations, seed management, and pgTAP testing |
| **Node.js** | `20.x LTS` (npm `>= 10.x`) | React web dashboard tooling and Supabase Edge Function dev |

---

## 2. Backend Development (Supabase Local Environment)

### 2.1. Initializing and Starting Local Services
```bash
# Navigate to repository root
cd fit-odyssey

# Start local Supabase containers (PostgreSQL, Auth, Storage, Edge Functions)
supabase start
```
*Note: `supabase start` provides local API credentials, including `API URL`, `anon key`, and local Inbucket email test server (`http://localhost:54324`).*

### 2.2. Applying Migrations and Seed Data
```bash
# Apply all SQL migrations from supabase/migrations/ and populate seed.sql
supabase db reset

# Create a new monotonic migration file
supabase migration new <migration_name>
```

### 2.3. Running Database Tests (pgTAP)
Database security, RLS enforcement, anti-cheat rules, and RPC integrity are verified using pgTAP:
```bash
# Execute all pgTAP tests located in supabase/tests/
supabase test db
```

### 2.4. Serving Edge Functions Locally
```bash
# Serve the single delete-account Edge Function locally
supabase functions serve delete-account --no-verify-jwt
```

### 2.5. Fallback: Hosted Supabase Free Tier (When Docker is Unavailable)
If Docker cannot run locally:
1. Create a free hosted project at [database.new](https://database.new).
2. Link your local project: `supabase link --project-ref <your-project-id>`.
3. Push migrations: `supabase db push`.
4. Copy the hosted URL and anon key into `mobile/.env` and `web/.env`.
5. *Note:* Refer to `docs/decisions.md` regarding the 7-day inactivity pause mitigation for hosted free projects.

---

## 3. Mobile Development (Flutter / Android)

### 3.1. Mobile Project Setup
```bash
cd mobile

# Fetch Flutter dependencies
flutter pub get

# Generate Drift SQLite database code and model serializers
dart run build_runner build --delete-conflicting-outputs
```

### 3.2. Static Analysis & Privacy Guard Checks
```bash
# Run strict Dart linter
flutter analyze

# Verify zero forbidden network or disk-writing imports in the pose engine
flutter test test/privacy/privacy_guard_test.dart
```

### 3.3. Running Pure-Dart Pose Engine Tests
```bash
# Run all unit tests (synthetic movement, squat, pushup, plank, EMA, jitter)
flutter test test/engine/
```

### 3.4. Running on a Real Android Device
Running pose estimation requires physical camera hardware (emulators do not simulate real-time BlazePose inference accurately):
1. Enable **Developer Options** and **USB Debugging** on your Android smartphone.
2. Connect your device via USB cable and confirm connection:
   ```bash
   flutter devices
   ```
3. Launch the application in profile or debug mode:
   ```bash
   flutter run -d <device-id> --profile
   ```
4. **Target Metrics to Verify:**
   - Inference throughput: 10–15 FPS.
   - UI frame rate: 60 FPS smooth animation.
   - Audio TTS cues fire crisply on rep completion.

---

## 4. Web Dashboard Development (React + Vite)

The web dashboard is an optional, lightweight, read-only analytics portal.

```bash
cd web

# Install dependencies
npm install

# Start local Vite development server
npm run dev

# Build production bundle
npm run build
```

---

## 5. Security & Pre-Commit Verification Checklist

Before opening a pull request or submitting milestones, run the following security gates:

### Gate 1: Service-Role Key Leak Check
Ensure the `service_role` secret never appears under client source trees:
```bash
# Must return ZERO matches:
grep -rn "service_role" mobile/ web/ && (echo "FAILURE: service_role key leaked in client bundle!" && exit 1) || echo "PASS: No service_role key found in client apps."
```

### Gate 2: Pose Engine Network Isolation Check
Verify that `mobile/lib/features/workout/engine/` contains zero external network or disk IO imports:
```bash
# Must return ZERO matches:
grep -rnE "(dart:io|package:http|package:supabase_flutter)" mobile/lib/features/workout/engine/ && (echo "FAILURE: Network/IO leak in engine!" && exit 1) || echo "PASS: Pose engine is pure and isolated."
```

### Gate 3: End-to-End Test Suite Run
```bash
# 1. Database pgTAP tests
supabase test db

# 2. Flutter Unit & Engine tests
cd mobile && flutter test
```
