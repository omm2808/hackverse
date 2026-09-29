# Fit Odyssey — System Architecture

> **Version:** 1.0.0 (MVP)
> **Last Updated:** 2026-09-29
> **Author:** Senior Architect

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview](#2-system-overview)
3. [Monorepo Structure](#3-monorepo-structure)
4. [Technology Stack](#4-technology-stack)
5. [Web / Mobile Relationship](#5-web--mobile-relationship)
6. [Backend Architecture](#6-backend-architecture)
7. [Database Design](#7-database-design)
8. [Authentication & Authorization](#8-authentication--authorization)
9. [Pose Engine](#9-pose-engine)
10. [Gamification Engine](#10-gamification-engine)
11. [Progress Engine](#11-progress-engine)
12. [Heritage Journey System](#12-heritage-journey-system)
13. [Privacy Architecture](#13-privacy-architecture)
14. [API Design](#14-api-design)
15. [Offline-First Mobile Strategy](#15-offline-first-mobile-strategy)
16. [Deployment Architecture](#16-deployment-architecture)
17. [Implementation Phases](#17-implementation-phases)
18. [Risks & Technical Decisions](#18-risks--technical-decisions)

---

## 1. Executive Summary

**Fit Odyssey** is an AI-powered gamified fitness platform that uses on-device computer vision (MediaPipe Pose Landmarker) to provide real-time exercise tracking, rep counting, and basic form feedback — all without expensive wearables. User activity fuels a virtual heritage journey through Odisha's landmarks, driving engagement through culturally relevant gamification.

The MVP consists of:
- **Mobile App** (React Native / Expo) — primary AI fitness experience with camera-based pose estimation
- **Web App** (Next.js) — fitness command center for analytics, progress, and management
- **Shared Backend** (NestJS) — single API serving both clients
- **Shared Database** (PostgreSQL + Prisma) — single source of truth

### Architectural Principles

| Principle | Description |
|---|---|
| **Single Backend** | One NestJS API serves both mobile and web clients |
| **Single Database** | One PostgreSQL instance with Prisma ORM |
| **Privacy by Design** | Raw video never leaves the device; only metrics are synced |
| **Offline-First Mobile** | Workouts function without internet; sync when connected |
| **Server-Side Authority** | Backend is the source of truth for XP, leaderboards, streaks |
| **Deterministic CV** | Rep counting uses state machines + joint angles, not LLMs |
| **Extensible Architecture** | Exercise analyzers, challenge types, badge rules are pluggable |

---

## 2. System Overview

```
                         FIT ODYSSEY
                              │
               ┌──────────────┴──────────────┐
               │                             │
          📱 MOBILE APP                  💻 WEB APP
          React Native / Expo            Next.js
               │                             │
               │  ┌───────────────────┐      │
               │  │  ON-DEVICE ONLY   │      │
               │  │  ┌─────────────┐  │      │
               │  │  │ Layer 1:    │  │      │
               │  │  │ MediaPipe   │  │      │
               │  │  │ Pose Engine │  │      │
               │  │  └──────┬──────┘  │      │
               │  │         ▼         │      │
               │  │  ┌─────────────┐  │      │
               │  │  │ Preprocess  │  │      │
               │  │  │ & Features  │  │      │
               │  │  └──────┬──────┘  │      │
               │  │         ▼         │      │
               │  │  ┌─────────────┐  │      │
               │  │  │ Layer 2:    │  │      │
               │  │  │ Custom AI   │  │      │
               │  │  │ Model       │  │      │
               │  │  └──────┬──────┘  │      │
               │  │         ▼         │      │
               │  │  ┌─────────────┐  │      │
               │  │  │ Layer 3:    │  │      │
               │  │  │ Deterministic  │      │
               │  │  │ State Machine  │      │
               │  │  └─────────────┘  │      │
               │  └───────────────────┘      │
               │                             │
               └──────────────┬──────────────┘
                              │
                     SAME REST API (HTTPS)
                              │
                    ┌─────────┴─────────┐
                    │   🔐 BACKEND API   │
                    │   NestJS + TS      │
                    │                     │
                    │  Auth Module        │
                    │  User Module        │
                    │  Workout Module     │
                    │  Progress Module    │
                    │  Heritage Module    │
                    │  Challenge Module   │
                    │  XP Module          │
                    │  Badge Module       │
                    │  Leaderboard Module │
                    │  Streak Module      │
                    │  Goal Module        │
                    │  Privacy Module     │
                    │  Admin Module       │
                    └─────────┬──────────┘
                              │
                    ┌─────────┴─────────┐
                    │  🗄️ PostgreSQL     │
                    │  + Prisma ORM      │
                    │  + Supabase Auth   │
                    └───────────────────┘
```

### Data Flow — On-Device Two-Layer AI Workout Pipeline

```
Camera Frame (mobile device only)
      │
      ▼
Pretrained Pose Estimator (MediaPipe Pose Landmarker)
──→ Produces 33 3D normalized body landmarks (x, y, z, visibility)
      │
      ▼
Preprocessing & Normalization (packages/pose-engine)
──→ Temporal EMA smoothing (jitter eradication)
──→ Mid-hip translation centering & torso-scale normalization
      │
      ▼
Biomechanical Feature Extraction (packages/pose-engine)
──→ Computes joint angles (knees, hips, elbows, shoulders) & normalized offsets
      │
      ▼
Custom Trained AI Model (Layer 2 - On-Device TFLite/ONNX)
──→ Classifies exercise type (Squat / Push-up / Plank / Idle) & movement phase
      │
      ▼
Deterministic Exercise State Machine Engine (packages/pose-engine)
──→ Tracks validated biomechanical state transitions:
    e.g. Squat: STANDING → DESCENDING → BOTTOM → ASCENDING → STANDING
      │
      ▼
Rep Counting / Hold Timing & Real-Time Form Feedback
──→ "Good depth", "Keep torso upright", "Rep counted"
      │
      ▼
Local Workout State (Zustand & offline storage)
      │
      ▼
Backend Synchronization (POST /workouts - metrics ONLY, ZERO raw video)
      │
      ▼
Shared NestJS Backend Processing
──→ Server-authoritative XP, badge evaluation, streak update,
    heritage journey progress, leaderboard recalculation
```

---

## 3. Monorepo Structure

```
fit-odyssey/
│
├── apps/
│   ├── web/                          # Next.js web application
│   │   ├── src/
│   │   │   ├── app/                  # App Router pages
│   │   │   ├── components/           # Web-specific components
│   │   │   ├── hooks/                # Web-specific hooks
│   │   │   ├── lib/                  # Web utilities
│   │   │   └── styles/               # Global styles
│   │   ├── public/                   # Static assets
│   │   ├── next.config.js
│   │   ├── tailwind.config.ts
│   │   ├── tsconfig.json
│   │   └── package.json
│   │
│   ├── mobile/                       # React Native / Expo app
│   │   ├── src/
│   │   │   ├── screens/              # Mobile screens
│   │   │   ├── components/           # Mobile-specific components
│   │   │   ├── navigation/           # React Navigation setup
│   │   │   ├── hooks/                # Mobile-specific hooks
│   │   │   ├── services/             # Device services (camera, storage)
│   │   │   └── utils/                # Mobile utilities
│   │   ├── assets/                   # Images, fonts
│   │   ├── app.json
│   │   ├── tsconfig.json
│   │   └── package.json
│   │
│   └── api/                          # NestJS backend
│       ├── src/
│       │   ├── modules/
│       │   │   ├── auth/
│       │   │   ├── users/
│       │   │   ├── workouts/
│       │   │   ├── exercises/
│       │   │   ├── progress/
│       │   │   ├── heritage/
│       │   │   ├── challenges/
│       │   │   ├── xp/
│       │   │   ├── badges/
│       │   │   ├── leaderboards/
│       │   │   ├── streaks/
│       │   │   ├── goals/
│       │   │   ├── privacy/
│       │   │   └── admin/
│       │   ├── common/
│       │   │   ├── guards/
│       │   │   ├── decorators/
│       │   │   ├── filters/
│       │   │   ├── interceptors/
│       │   │   ├── middleware/
│       │   │   └── pipes/
│       │   ├── prisma/
│       │   ├── app.module.ts
│       │   └── main.ts
│       ├── test/
│       ├── tsconfig.json
│       └── package.json
│
├── packages/
│   ├── shared-types/
│   ├── validation/
│   ├── api-client/
│   ├── gamification/
│   ├── progress-engine/
│   ├── pose-engine/
│   └── config/
│
├── ml/                               # Dedicated ML Workspace (Offline Model Training)
│   ├── dataset/                      # Dataset manifests & subject-level split definitions
│   ├── preprocessing/                # Landmark extraction, normalization, feature engineering
│   ├── training/                     # Dataset loaders, model definitions (MLP/CNN/GRU), train loop
│   ├── evaluation/                   # Metrics, confusion matrix, diagnostics
│   ├── inference/                    # Local Python predictor testbed
│   ├── export/                       # Mobile serialization (TFLite/ONNX) + metadata packaging
│   ├── models/                       # Checkpoints & exported model binaries
│   ├── notebooks/                    # Exploratory data analysis notebooks
│   └── README.md
│
├── prisma/
│   ├── schema.prisma
│   ├── seed.ts
│   └── migrations/
│
├── docs/
│   ├── architecture.md
│   ├── ml-training.md
│   ├── api.md
│   ├── database.md
│   ├── security.md
│   ├── privacy.md
│   ├── pose-engine.md
│   └── development.md
│
├── .env.example
├── .gitignore
├── package.json
├── turbo.json
├── tsconfig.base.json
└── README.md
```

---

## 4. Technology Stack

| Layer | Technology | Justification |
|---|---|---|
| **Monorepo** | Turborepo | Fast builds, task caching, dependency graph awareness |
| **Web** | Next.js 14+ (App Router) | SSR, RSC, excellent DX, mature ecosystem |
| **Web Styling** | Tailwind CSS | Rapid UI development, consistent design system |
| **Mobile** | React Native + Expo SDK 50+ | Cross-platform, shared TypeScript, OTA updates |
| **Backend** | NestJS + TypeScript | Modular architecture, decorators, guards, pipes |
| **Database** | PostgreSQL 15+ | ACID, JSON support, full-text search, mature |
| **ORM** | Prisma 5+ | Type-safe queries, migrations, schema-first |
| **Auth** | Supabase Auth | JWT-based, email/password, session management |
| **Pose** | MediaPipe Pose Landmarker | On-device, 33 landmarks, runs on mobile GPU |
| **State (Client)** | Zustand | Lightweight, TypeScript-first, no boilerplate |
| **Validation** | Zod (shared) + class-validator (NestJS) | Runtime type safety across stack |
| **API** | REST (JSON) | Simple, well-understood, sufficient for MVP |
| **Package Manager** | pnpm | Fast, disk-efficient, workspace support |

### Explicitly Excluded Technologies

| Technology | Reason |
|---|---|
| GraphQL | Unnecessary complexity for MVP |
| Redis | No caching layer needed yet |
| Docker Compose | Adds setup complexity for hackathon |
| Firebase | Conflicting with Supabase Auth choice |
| TensorFlow Lite | MediaPipe is sufficient and simpler |
| WebSockets | Polling/REST sufficient for MVP |

---

## 5. Web / Mobile Relationship

### Mobile App — Primary AI Fitness Experience

The mobile app is where users **do** workouts. It owns:

- Camera access and pose estimation
- Real-time exercise analysis and rep counting
- Offline workout recording
- Local data persistence and sync

**Screens:**

| Screen | Description |
|---|---|
| Splash | App loading |
| Login | Email/password authentication |
| Register | Account creation |
| Forgot Password | Password reset flow |
| Onboarding | First-time user setup |
| Home | Dashboard with stats, quick start |
| Workout | Exercise selection |
| Exercise Selection | Choose squat, push-up, or plank |
| Camera Calibration | Body positioning validation |
| Live Workout | Real-time pose overlay, reps, feedback |
| Workout Result | Summary, XP earned, achievements |
| Workout History | Past workout sessions |
| Progress | Charts, trends |
| Heritage Journey | Virtual Odisha trek progress |
| Challenges | Active/available challenges |
| Leaderboard | Global/college rankings |
| Badges | Earned/locked badges |
| Profile | User settings |
| Privacy Settings | Data controls |

**Bottom Navigation:** Home | Workout | Journey | Leaderboard | Profile

### Web App — Fitness Command Center

The web app is where users **review and manage** their fitness journey. It owns:

- Rich analytics dashboards
- Progress charts and trends
- Heritage journey visualization
- Challenge management
- Account and privacy management
- Admin panels (for COLLEGE_ADMIN and SUPER_ADMIN)

**Routes:**

| Route | Description |
|---|---|
| `/login` | Authentication |
| `/register` | Account creation |
| `/dashboard` | Main analytics hub |
| `/workouts` | Workout history with details |
| `/progress` | Charts, weekly/monthly views |
| `/heritage` | Heritage journey map + progress |
| `/challenges` | Browse and join challenges |
| `/leaderboard` | Rankings |
| `/badges` | Badge collection |
| `/profile` | Account settings |
| `/privacy` | Privacy controls |
| `/admin` | Admin panel (protected) |

### Shared Responsibilities

Both clients:
- Use the same `api-client` package for API calls
- Use the same `shared-types` for TypeScript interfaces
- Use the same `validation` schemas for input validation
- Authenticate through the same Supabase Auth flow
- Read/write to the same backend and database

---

## 6. Backend Architecture

### Module Architecture

```
                    HTTP Request
                         │
                    ┌────┴────┐
                    │  Guards  │  ←── AuthGuard, RolesGuard
                    └────┬────┘
                         │
                    ┌────┴────┐
                    │  Pipes  │  ←── ValidationPipe (Zod/class-validator)
                    └────┬────┘
                         │
                ┌────────┴────────┐
                │   Controller    │  ←── Route handlers, thin layer
                └────────┬────────┘
                         │
                ┌────────┴────────┐
                │    Service      │  ←── Business logic, orchestration
                └────────┬────────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
    ┌─────┴─────┐  ┌────┴────┐  ┌─────┴─────┐
    │  Prisma   │  │  Event  │  │  External  │
    │ Repository│  │ Emitter │  │  Services  │
    └───────────┘  └─────────┘  └───────────┘
```

### Event Flow — Workout Completion

```
POST /workouts/:id/complete
         │
    WorkoutService.completeWorkout()
         │
    Emit: WorkoutCompletedEvent
         │
    ┌────┼────────────┬────────────┬──────────────┐
    ▼    ▼            ▼            ▼              ▼
   XP  Badges    Streak      Heritage       Leaderboard
 Award  Check    Update    Progress Update    Recalculate
   │     │         │            │                │
   ▼     ▼         ▼            ▼                ▼
  XP   Badge    Streak     Checkpoint       Leaderboard
 Trans  Grant   Record      Unlock           Entry
```

---

## 7. Database Design

### Entity Relationship Overview

```
User ──────┬──── Profile
           ├──── WorkoutSession ──── ExerciseResult
           ├──── XPTransaction
           ├──── UserBadge
           ├──── Streak
           ├──── UserGoal
           ├──── ChallengeProgress
           ├──── UserJourneyProgress
           ├──── ProgressSnapshot
           ├──── PrivacyPreference
           └──── LeaderboardEntry

Exercise (standalone)

Challenge ──── ChallengeProgress

HeritageJourney ──── HeritageCheckpoint
                └──── UserJourneyProgress

Badge ──── UserBadge

Leaderboard ──── LeaderboardEntry

AuditLog (standalone)
```

### Core Tables

| Table | Description | Key Fields |
|---|---|---|
| `User` | Authentication identity | id, email, role, createdAt |
| `Profile` | User profile data | userId, displayName, avatar, college |
| `WorkoutSession` | A workout instance | userId, startedAt, endedAt, totalReps, xpEarned, syncStatus |
| `Exercise` | Exercise definitions | id, name, type, description |
| `ExerciseResult` | Per-exercise results in a workout | workoutSessionId, exerciseId, reps, duration, metrics |
| `WorkoutMetric` | Granular metric snapshots | exerciseResultId, metricType, value |
| `XPTransaction` | Every XP change | userId, amount, source, sourceId, createdAt |
| `Badge` | Badge definitions | id, key, name, description, criteria |
| `UserBadge` | Earned badges | userId, badgeId, earnedAt |
| `Challenge` | Challenge definitions | id, type, name, target, startDate, endDate |
| `ChallengeProgress` | User's progress in a challenge | userId, challengeId, currentValue |
| `HeritageJourney` | Odisha heritage routes | id, name, totalDistance, isActive |
| `HeritageCheckpoint` | Stops along a journey | journeyId, name, distanceFromStart, unlockOrder |
| `UserJourneyProgress` | User's position on a journey | userId, journeyId, distanceCovered, currentCheckpointId |
| `Streak` | Streak records | userId, currentStreak, longestStreak, lastActivityDate |
| `Leaderboard` | Leaderboard definitions | id, type, scope |
| `LeaderboardEntry` | Ranked entries | leaderboardId, userId, score, rank |
| `UserGoal` | Adaptive goals | userId, type, currentTarget, previousTarget, reason |
| `ProgressSnapshot` | Periodic summaries | userId, period, data, createdAt |
| `PrivacyPreference` | User privacy settings | userId, cameraDataPolicy, locationSharing, leaderboardVisibility |
| `AuditLog` | Administrative action log | actorId, action, targetType, targetId, metadata |

### Indexing Strategy

- Primary keys: UUID v4 on all tables
- Foreign keys: indexed automatically by Prisma
- Query-optimized indexes: `(userId, createdAt)` on WorkoutSession, XPTransaction
- Leaderboard: `(leaderboardId, score DESC)` for rank queries
- Streak: `(userId)` unique for current streak lookup
- Unique constraints: `(userId, badgeId)` on UserBadge, `(userId, challengeId)` on ChallengeProgress

---

## 8. Authentication & Authorization

### Authentication — Supabase Auth

```
Client (Mobile/Web)
       │
       ▼
  Supabase Auth
  (email/password)
       │
       ▼
  JWT Token (access + refresh)
       │
       ▼
  API Request with Bearer token
       │
       ▼
  NestJS AuthGuard
       │
       ▼
  Verify JWT via Supabase
       │
       ▼
  Attach user to request context
```

**Supported flows:**
- Registration (email + password)
- Login
- Logout (token invalidation)
- Email verification
- Password reset
- Session refresh
- Account deletion

**Token storage:**
- Web: HttpOnly cookies or secure localStorage
- Mobile: Expo SecureStore (encrypted device storage)

### Authorization — Role-Based Access Control

```typescript
enum UserRole {
  USER = 'USER',
  COLLEGE_ADMIN = 'COLLEGE_ADMIN',
  SUPER_ADMIN = 'SUPER_ADMIN',
}
```

**Permission Matrix:**

| Resource | USER | COLLEGE_ADMIN | SUPER_ADMIN |
|---|---|---|---|
| Own profile | CRUD | CRUD | CRUD |
| Own workouts | CRUD | CRUD | CRUD |
| Own progress | R | R | R |
| Join challenges | ✓ | ✓ | ✓ |
| View leaderboards | ✓ | ✓ | ✓ |
| Earn badges | ✓ | ✓ | ✓ |
| College challenges | — | CRUD | CRUD |
| College groups | — | CRUD | CRUD |
| Aggregate stats | — | R | R |
| Heritage journeys | — | — | CRUD |
| Challenge templates | — | — | CRUD |
| Badge definitions | — | — | CRUD |
| Exercise management | — | — | CRUD |
| User management | — | — | CRUD |

All authorization is enforced at the **backend**. Frontend role checks are for UX only.

### Row-Level Security

Every data query includes a `userId` filter. The `/users/me` pattern ensures users only access their own data.

---

## 9. Pose Engine

### Architecture — Two-Layer Hybrid AI Pipeline

The pose engine is split across:
1. `apps/mobile`: Native camera acquisition, MediaPipe hardware delegate execution, and local model inference runtime (TFLite/ONNX).
2. `packages/pose-engine`: Platform-agnostic normalization, feature extraction, model interfaces, state machines, and feedback logic.
3. `ml/`: Dedicated offline training, evaluation, and export workspace.

```
┌──────────────────────────────────────────────────────────────────┐
│                  MOBILE DEVICE (ON-DEVICE ONLY)                  │
│                                                                  │
│  Camera Feed                                                     │
│        │                                                         │
│        ▼                                                         │
│  [Pretrained MediaPipe Pose]  ── Layer 1: Edge Pose Estimator    │
│        │                                                         │
│        ▼                                                         │
│  33 Normalized Landmarks (x, y, z, visibility)                   │
│        │                                                         │
│        ▼                                                         │
│  [Temporal EMA Smoothing]     ── Jitter reduction                │
│        │                                                         │
│        ▼                                                         │
│  [Normalization & Features]   ── Mid-hip center & 16-D vector    │
│        │                                                         │
│        ▼                                                         │
│  [Custom Trained AI Model]    ── Layer 2: Exercise Classifier    │
│        │ (Output: class probabilities & movement state)          │
│        ▼                                                         │
│  [Deterministic State Machine]── Layer 3: Rep & Hold Counter     │
│        │                                                         │
│        ▼                                                         │
│  [Real-Time Form Feedback]    ── "Good depth", "Keep upright"    │
│        │                                                         │
│        ▼                                                         │
│  Local Workout State (Zustand & Offline Storage)                 │
│                                                                  │
│  ⚠️ ZERO RAW CAMERA VIDEO OR FRAMES EVER LEAVE THIS DEVICE       │
└──────────────────────────────────────────────────────────────────┘
```

### Model Versioning Specification
Exported models are packaged with an immutable metadata manifest:
```json
{
  "model_name": "fit-odyssey-exercise-model",
  "model_version": "0.1.0",
  "dataset_version": "1.0.0",
  "training_date": "2026-09-29T21:30:00Z",
  "classes": ["squat", "pushup", "plank", "idle"],
  "input_shape": [1, 16],
  "output_classes": ["squat", "pushup", "plank", "idle"],
  "feature_configuration": {
    "normalized_to": "mid_hip",
    "scaled_by": "torso_length",
    "features": 16
  },
  "model_format": "tflite"
}
```

### ExerciseAnalyzer & Model Predictor Interfaces

```typescript
export interface ModelPrediction {
  predictedClass: string;
  confidence: number;
  probabilities: Record<string, number>;
  movementState?: string;
}

export interface CustomModelPredictor {
  readonly metadata: ModelMetadata;
  predict(features: number[]): Promise<ModelPrediction> | ModelPrediction;
}

export interface ExerciseAnalyzer {
  readonly exerciseId: string;
  readonly name: string;

  checkCalibration(landmarks: NormalizedLandmarks): CalibrationResult;
  analyze(landmarks: NormalizedLandmarks, timestampMs: number): AnalysisResult;
  reset(): void;
}
```

### Squat Analyzer — State Machine

```
         ┌──────────┐
    ┌───▶│ STANDING  │◀──────────────────┐
    │    └────┬──────┘                    │
    │         │ knee angle < threshold    │
    │         ▼                           │
    │    ┌──────────┐                     │
    │    │DESCENDING│                     │
    │    └────┬─────┘                     │
    │         │ knee angle < bottom       │
    │         ▼                           │
    │    ┌──────────┐                     │
    │    │  BOTTOM  │                     │
    │    └────┬─────┘                     │
    │         │ knee angle increasing     │
    │         ▼                           │
    │    ┌──────────┐                     │
    │    │ASCENDING │                     │
    │    └────┬─────┘                     │
    │         │ knee angle > stand        │
    │         └──── VALID REP ────────────┘
    │
    └── timeout / invalid ── discard partial
```

### Calibration Checks

| Check | Criteria | Failure Message |
|---|---|---|
| Full body visible | All 33 landmarks detected | "Ensure your full body is visible" |
| Landmark confidence | Average visibility > 0.7 | "Tracking confidence low" |
| Camera distance | Body height > 40% frame | "Move farther away" / "Move closer" |
| Lighting | Frame brightness adequate | "Improve lighting" |
| Stability | Landmark variance < threshold | "Hold still for calibration" |

---

## 10. Gamification Engine

### XP System

XP is **server-calculated only**. The client cannot assign XP directly.

| Action | XP Award |
|---|---|
| Complete a workout | 50 + (reps × 2) |
| Complete a challenge | 100–500 (based on difficulty) |
| Reach heritage checkpoint | 75 |
| Maintain 7-day streak | 150 |
| Maintain 30-day streak | 500 |

### Badge Engine

Badges are **database-driven**:

| Key | Name | Criteria |
|---|---|---|
| `FIRST_WORKOUT` | First Steps | Complete 1 workout |
| `7_DAY_STREAK` | Week Warrior | Maintain 7-day streak |
| `100_REPS` | Century | Complete 100 total reps |
| `500_REPS` | Five Hundred | Complete 500 total reps |
| `FIRST_HERITAGE_CHECKPOINT` | Heritage Explorer | Reach first checkpoint |
| `HERITAGE_FINISHER` | Journey Complete | Finish a heritage journey |
| `WEEKLY_CHALLENGE` | Challenger | Complete a weekly challenge |

### Challenge Engine

| Type | Metric | Example |
|---|---|---|
| `WORKOUT_COUNT` | Number of workouts | "Complete 5 workouts this week" |
| `REP_COUNT` | Total reps | "Complete 200 squats" |
| `STREAK` | Consecutive days | "Maintain a 7-day streak" |
| `DISTANCE` | Heritage journey distance | "Travel 10 km on heritage journey" |
| `WEEKLY_GOAL` | Composite weekly target | "3 workouts + 100 reps this week" |

---

## 11. Progress Engine

### Tracking Dimensions

| Dimension | Granularity | Storage |
|---|---|---|
| Workouts completed | Per session | WorkoutSession |
| Total reps | Per exercise per session | ExerciseResult |
| Active minutes | Per session | WorkoutSession.duration |
| XP earned | Per transaction | XPTransaction |
| Streaks | Daily | Streak |
| Challenge progress | Per challenge | ChallengeProgress |
| Heritage progress | Per journey | UserJourneyProgress |

### Adaptive Goals

```
User completes workout
        │
        ▼
  Calculate completion rate (last 7 days)
        │
  ┌─────┴──────────────────────┐
  │  >= 90%: increase target   │
  │  60-90%: maintain target   │
  │  < 60%: reduce/maintain    │
  └─────┬──────────────────────┘
        │
  Create new UserGoal with reason
```

---

## 12. Heritage Journey System

### Data Model

```
HeritageJourney (Lingaraj → Konark)
    ├── Checkpoint 1: Lingaraj Temple    (0 km)
    ├── Checkpoint 2: Dhauli             (8 km)
    ├── Checkpoint 3: Udayagiri          (14 km)
    ├── Checkpoint 4: Pipili             (28 km)
    └── Checkpoint 5: Konark             (65 km)
```

### Distance Calculation

```typescript
const DISTANCE_PER_REP = 0.05;    // km per rep
const DISTANCE_PER_MINUTE = 0.1;  // km per active minute
const DISTANCE_PER_WORKOUT = 0.5; // km bonus per completed workout
```

---

## 13. Privacy Architecture

| Rule | Implementation |
|---|---|
| Raw video stays on device | Pose engine runs locally; no frame upload API exists |
| Pose inference is local | MediaPipe runs in mobile app process |
| Only metrics are synced | API accepts ExerciseResult (reps, duration, metrics JSON) |
| Location is optional | Stored only if user opts in |
| Explicit permissions | Camera permission requested with clear explanation |
| Account deletion | DELETE /users/me — cascading delete of all user data |
| Workout deletion | DELETE /workouts/:id |
| Privacy settings | PATCH /users/me/privacy |
| Data export | GET /users/me/data-export |
| Admin audit logging | All admin actions logged to AuditLog table |

---

## 14. API Design

### Authentication Endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Sign in |
| POST | `/auth/logout` | Sign out |
| POST | `/auth/refresh` | Refresh token |
| POST | `/auth/forgot-password` | Request password reset |
| POST | `/auth/reset-password` | Complete password reset |

### User Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | USER | Get own profile |
| PATCH | `/users/me` | USER | Update own profile |
| GET | `/users/me/privacy` | USER | Get privacy settings |
| PATCH | `/users/me/privacy` | USER | Update privacy settings |
| GET | `/users/me/badges` | USER | Get earned badges |
| DELETE | `/users/me/data` | USER | Delete user data |
| DELETE | `/users/me` | USER | Delete account |

### Workout, Progress, Heritage, Challenge, Leaderboard, Badge, Admin Endpoints

See full API reference in `docs/api.md`.

---

## 15. Offline-First Mobile Strategy

### Sync Architecture

```
┌──────────────────────────────────────┐
│            MOBILE DEVICE             │
│                                      │
│  Live Workout ──→ Local Store        │
│                      │               │
│              Sync Manager            │
│              ┌──────────────┐        │
│              │ PENDING      │        │
│              │ SYNCED       │        │
│              │ FAILED       │        │
│              └──────┬───────┘        │
└─────────────────────┼───────────────┘
                      │ (when online)
                      ▼
               Backend API
```

- **Idempotent sync** — client-generated UUIDs prevent duplicates
- **Server-authoritative** — XP, badges recalculated server-side
- **Auto-retry** — failed syncs retry when connectivity returns

---

## 16. Deployment Architecture

### Development

| Service | Port |
|---|---|
| Next.js (web) | 3000 |
| NestJS (api) | 3001 |
| PostgreSQL | 5432 |
| Expo (mobile) | 8081 |

---

## 17. Implementation Phases

| Phase | Name | Est. Time |
|---|---|---|
| 0 | Architecture | ✅ Done |
| 1 | Monorepo Foundation | 2–3 hrs |
| 2 | Auth & Authorization | 2–3 hrs |
| 3 | Database & Backend | 3–4 hrs |
| 4 | Mobile Shell | 3–4 hrs |
| 5 | Pose Engine | 4–5 hrs |
| 6 | Workout Tracking | 3–4 hrs |
| 7 | Progress Engine | 2–3 hrs |
| 8 | Heritage & Challenges | 2–3 hrs |
| 9 | XP, Badges, Leaderboard | 2–3 hrs |
| 10 | Web Dashboard | 3–4 hrs |
| 11 | Privacy & Security | 2–3 hrs |
| 12 | Testing | 3–4 hrs |
| 13 | Hackathon Polish | 2–3 hrs |

---

## 18. Risks & Technical Decisions

### Decisions Made

| Decision | Rationale |
|---|---|
| pnpm over npm/yarn | Faster installs, strict deps, workspace support |
| Turborepo over Nx | Simpler config, zero-config caching |
| NestJS over Express | Modular architecture with DI, guards, pipes |
| Supabase Auth over custom | Production-ready auth in hours |
| Prisma over TypeORM | Better DX, type safety, migrations |
| REST over GraphQL | Simpler, sufficient for MVP |
| Zustand over Redux | Minimal boilerplate, TypeScript-first |
| MediaPipe over TFLite | Purpose-built for pose, simpler integration |
| Deterministic rep counting | Reliable, testable, no training data needed |

### Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| MediaPipe RN integration | HIGH | Use react-native-mediapipe or WebView fallback |
| Expo + Camera perf | MEDIUM | expo-camera with frame processor; throttle to 15 FPS |
| Pose jitter false reps | MEDIUM | EMA smoothing + min movement threshold + debounce |
| Offline sync conflicts | LOW | Client UUIDs + server-authoritative recalculation |
| Supabase free tier limits | LOW | Sufficient for hackathon |

---

## Appendix: Environment Variables

```env
DATABASE_URL=postgresql://user:password@localhost:5432/fitodyssey
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
API_PORT=3001
API_URL=http://localhost:3001
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
EXPO_PUBLIC_API_URL=http://localhost:3001
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
JWT_SECRET=your-jwt-secret
RATE_LIMIT_TTL=60
RATE_LIMIT_LIMIT=100
```

## Appendix: Key Architectural Constraints

1. **One backend, one database** — no microservices, no separate DBs
2. **Server-side authority** — XP, leaderboards, streaks, badges are NEVER client-trusted
3. **No video upload** — the backend has NO endpoint to receive camera frames
4. **Deterministic CV** — joint angles + state machines, not LLMs or cloud AI
5. **Privacy-first** — data minimization, explicit consent, deletion capability
6. **Offline-capable** — mobile workouts must function without internet
7. **Extensible** — pluggable analyzers, database-driven badges/challenges, modular backend
