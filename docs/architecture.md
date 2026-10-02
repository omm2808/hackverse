# Fit Odyssey — System Architecture

> **Version:** 2.0.0 (Hackathon MVP)  
> **Status:** Active Reference  
> **Author:** Senior Engineering Team  

---

## 1. Executive Summary

**Fit Odyssey** is an AI-powered, offline-first gamified fitness application built for college students and fitness enthusiasts in Odisha, India. It leverages on-device computer vision (`google_mlkit_pose_detection` BlazePose) to deliver real-time exercise rep counting, phase detection, and biomechanical form corrections without wearables or expensive sensors.

Every validated workout powers a cultural heritage journey across Odisha's historic landmarks—from **Lingaraj Temple to Konark Sun Temple**—while rewarding athletic progress through streaks, weekly/monthly campus leaderboards, and server-driven adaptive goals.

### Core Architectural Tenets
1. **Zero Video Ingestion (Privacy by Design):** Camera frames live exclusively in volatile RAM for ~33–66 ms during local landmark extraction. No raw images or video feeds ever touch local storage or any network interface.
2. **Server-Side Authority:** Clients possess zero write access to workouts, XP, streaks, trek distance, or leaderboards. All gamification calculations and record creations happen atomically in a single PostgreSQL `SECURITY DEFINER` RPC (`submit_workout`).
3. **Offline-First Resilience:** Workouts are persisted locally in SQLite (`drift`) with client-assigned UUIDs and queued for sync. Synchronizations are completely idempotent.
4. **Lightweight Operational Surface:** Built entirely on Flutter for mobile and Supabase (Postgres, RLS, Auth, RPC, `pg_cron`, and one Edge Function `delete-account`) for backend infrastructure. No custom application servers (no NestJS, no Express).

---

## 2. System Overview & Architecture Diagram

```
                              FIT ODYSSEY ECOSYSTEM
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
            📱 MOBILE APPLICATION                  💻 WEB DASHBOARD (OPTIONAL)
          Flutter (Android First)                      React + Vite + TS
                    │                                       │
     ┌──────────────┴──────────────┐                        │
     │      ON-DEVICE ONLY         │                        │
     │  ┌───────────────────────┐  │                        │
     │  │ Camera Stream (10-15f)│  │                        │
     │  └───────────┬───────────┘  │                        │
     │              ▼              │                        │
     │  ┌───────────────────────┐  │                        │
     │  │ ML Kit Pose Landmarker│  │                        │
     │  │ (33 3D Keypoints)     │  │                        │
     │  └───────────┬───────────┘  │                        │
     │              ▼              │                        │
     │  ┌───────────────────────┐  │                        │
     │  │ Pure Dart Pose Engine │  │                        │
     │  │ • EMA Smoothing (α=0.6│  │                        │
     │  │ • Angle Trigonometry  │  │                        │
     │  │ • State Machines      │  │                        │
     │  │ • Form Flags & Audio  │  │                        │
     │  └───────────┬───────────┘  │                        │
     │              ▼              │                        │
     │  ┌───────────────────────┐  │                        │
     │  │ Local SQLite (Drift)  │  │                        │
     │  │ Offline Sync Queue    │  │                        │
     │  └───────────┬───────────┘  │                        │
     └──────────────┼──────────────┘                        │
                    │                                       │
                    │ HTTPS / Supabase SDK                  │ HTTPS / Read-Only
                    │ (Anon Key Only)                       │ (Anon Key Only)
                    ▼                                       ▼
    ┌──────────────────────────────────────────────────────────────┐
    │                     SUPABASE BACKEND PLATFORM                │
    │                                                              │
    │  ┌────────────────────┐   ┌───────────────────────────────┐  │
    │  │   Supabase Auth    │   │      PostgreSQL Database      │  │
    │  │ • Email / Password │   │ • Profiles, Workouts, XP      │  │
    │  │ • Email Verify     │   │ • Streaks, Heritage, Goals    │  │
    │  │ • Password Reset   │   │ • Row Level Security (RLS)    │  │
    │  └────────────────────┘   └───────────────┬───────────────┘  │
    │                                           │                  │
    │  ┌────────────────────────────────────────┴───────────────┐  │
    │  │             Server Functions & Automation              │  │
    │  │ • RPC: submit_workout() [Atomic write & Anti-Cheat]    │  │
    │  │ • RPC: leaderboard(), my_rank(), monthly_summary()     │  │
    │  │ • pg_cron: close_month [Automated monthly snapshots]   │  │
    │  └────────────────────────────────────────────────────────┘  │
    │                                                              │
    │  ┌────────────────────────────────────────────────────────┐  │
    │  │           Edge Functions (Exactly ONE Function)        │  │
    │  │ • delete-account (Service-role cascade user wipe)      │  │
    │  └────────────────────────────────────────────────────────┘  │
    └──────────────────────────────────────────────────────────────┘
```

---

## 3. Technology Stack

| Layer | Technology | Purpose & Rationale |
|---|---|---|
| **Mobile Core** | Flutter 3.22+ (Dart 3.4+) | High performance Android-first framework; native camera pipeline; unified UI. |
| **Mobile State** | Riverpod (`flutter_riverpod`) | Compile-safe, testable state management without boilerplate. |
| **Mobile Routing** | `go_router` | Declarative deep-linking and stateful navigation. |
| **On-Device Vision**| `google_mlkit_pose_detection` | On-device BlazePose model generating 33 3D landmarks at 10–15 FPS. |
| **Pose Engine** | Pure Dart Module | Zero-dependency biomechanical math module; 100% unit-testable without mocks. |
| **Audio Feedback** | `flutter_tts` | Immediate vocal rep count and form alerts; English & Odia voice support with fallback. |
| **Mobile Charts** | `fl_chart` | Interactive monthly progress and volume visualization. |
| **Mobile Storage** | `drift` + `sqlite3_flutter_libs` | Local SQLite relational database powering offline-first workout queue. |
| **Connectivity** | `connectivity_plus` | Real-time network detection to drive background sync. |
| **Credentials** | `flutter_secure_storage` | Encrypted storage for Supabase auth refresh tokens. |
| **Data Export** | `share_plus` + `path_provider` | Native Android share sheet integration for CSV report sharing. |
| **Backend & DB** | Supabase (PostgreSQL 15+) | Complete backend: Auth, Postgres DB, Row Level Security, RPCs, and `pg_cron`. |
| **Backend Scripting**| PL/pgSQL Stored Procedures | `SECURITY DEFINER` atomic transactions for anti-cheat, XP, streaks, and trek progress. |
| **Edge Function** | Deno / TypeScript (Supabase Edge) | Exactly one function (`delete-account`) accessing service-role auth deletion. |
| **Web Dashboard** | React 18 + Vite + TypeScript | Optional read-only web portal for viewing monthly progress and campus leaderboards. |

---

## 4. Five Scoped Feature Areas

### Area 1: Real-Time Pose Estimation (Mobile Only)
- **Pipeline:** Camera Frame $\to$ ML Kit Landmark Extraction $\to$ EMA Smoothing ($\alpha=0.6$) $\to$ Joint Angle Trigonometry $\to$ State Machine $\to$ Rep/Hold Events $\to$ Audio/Visual Feedback.
- **Pure-Dart Architecture:** Located in `mobile/lib/features/workout/engine/`. Contains zero imports from Flutter, camera, or ML Kit. Easily unit tested using synthetic coordinate frames.
- **Supported Exercises:**
  - **Squat:** Hip–Knee–Ankle angle. `STANDING` ($\ge 150^\circ$) $\to$ `DESCENDING` ($< 150^\circ$) $\to$ `BOTTOM` ($\le 100^\circ$, triggers "Good depth") $\to$ `ASCENDING` ($> 110^\circ$) $\to$ `STANDING` ($\ge 160^\circ$). Partial reps trigger "Go slightly lower" and yield no rep.
  - **Push-up:** Shoulder–Elbow–Wrist angle + spine line. `HIGH` ($\ge 150^\circ$) $\to$ `DESCENDING` ($< 150^\circ$) $\to$ `BOTTOM` ($\le 95^\circ$) $\to$ `ASCENDING` ($> 105^\circ$) $\to$ `HIGH` ($\ge 155^\circ$).
  - **Plank:** Shoulder–Hip–Ankle angle. Valid range: $155^\circ$–$185^\circ$. Hold timer runs only while form is valid; pauses with alerts on sagging ($< 155^\circ$) or piked ($> 185^\circ$) hips.
- **Biomechanical Injury-Risk Flags:** Knee valgus (inward collapse), excessive forward torso lean, and sagging lumbar spine. Aggregated into `form_flags` JSON.
- **Calibration Phase:** Pre-set calibration verifies full body visibility, distance, and orientation before initiating a 3-2-1 countdown.

### Area 2: Heritage Challenge (Virtual Odisha Journey)
- **Journey Route:** Lingaraj Temple (Bhubaneswar, 0 km) $\to$ Dhauli Shanti Stupa (8 km) $\to$ Udayagiri Caves (14 km) $\to$ Pipili Heritage Craft Village (28 km) $\to$ Konark Sun Temple (65 km).
- **Server-Only Distance Formula:**
  $$\text{km} = (\text{reps} \times 0.05) + (\text{active\_minutes} \times 0.1) + 0.5\text{ (per completed workout)}$$
- **Checkpoints:** Seeded with bilingual metadata (English and Odia). Crossing a checkpoint unlocks a cultural monument card and awards an immutable $+75\text{ XP}$ bonus (enforced via unique constraint on `(user_id, checkpoint_id)`).
- **Illustrated UI:** Stylized vector map showing user avatar movement, milestone checkpoints, and unlockable heritage cards without external map SDK dependencies.

### Area 3: Leaderboards & Campus Competition
- **Scopes & Periods:** Global, College (e.g., CET, VSSUT, Ravenshaw, KIIT, SOA, OUTR), and Hostel. Filterable by Weekly and Monthly periods.
- **Server Calculation:** Uses SQL window functions `rank() over (order by xp desc)` directly against `xp_events` aggregated over the selected date range.
- **Privacy Enforcement:** Users configured with `leaderboard_visibility = 'anonymous'` display as `"Athlete #NNNN"`; `'hidden'` users are omitted. The RPC never returns other users' `user_id`.
- **Anti-Cheat Validation:** `submit_workout` validates rep rates ($\le 60\text{ reps/min}$), duration minimums ($\ge 1.0\text{ sec/rep}$), and daily session counts ($\le 20\text{ sessions/day}$). Flagged violations are logged to `workout_rejections` without crediting XP.

### Area 4: Monthly Progress & Adaptive Goals
- **Monthly Summary RPC:** `monthly_summary(p_month date)` aggregates total workouts, per-exercise volume, active minutes, XP, km travelled, average form score, form flags, best streak, and a 30-day activity heatmap.
- **Snapshot Automation:** `pg_cron` runs `close_month` at midnight on the 1st of every month to snapshot preceding month totals into `monthly_snapshots`.
- **Server-Side Adaptive Goals:** On workout submission, the server evaluates the last 7 days of performance against weekly goals:
  - $\ge 90\%$ completion rate: raises target by $10\%$.
  - $60\% - 89\%$ completion rate: maintains target.
  - $< 60\%$ completion rate: lowers target by $10\%$ (bounded by a minimum floor of 50 reps/week).
- **Data Export:** RPC `export_monthly_report(p_month)` returns structured JSON. Mobile app converts it to CSV and shares via native Android share sheet.

### Area 5: Data Privacy & Security (DPDP Act 2023)
- **Zero Video Ingestion:** No frame write to storage or network upload. No Supabase Storage bucket exists.
- **Consent Gate:** Explicit first-run consent modal captures acceptance version (`consent_version`) and timestamp (`consent_accepted_at`) before invoking the OS camera permission prompt.
- **Self-Service Sovereignty:**
  - `export_my_data()`: Generates full JSON archive of profile, workouts, XP logs, and milestones.
  - `delete_workout_history()`: Atomically wipes workouts and resets XP/streaks without deleting user identity.
  - `delete-account` Edge Function: Completely purges auth credentials and triggers database cascade wipes.

---

## 5. Folder Structure

```
fit-odyssey/
├── mobile/                            # Flutter Mobile Application (Android First)
│   ├── android/                       # Android native project and manifest
│   ├── assets/                        # Fonts, illustrations, Odia/English ARB files
│   │   ├── i18n/                      # app_en.arb, app_or.arb
│   │   └── images/                    # Heritage illustrations, monuments
│   ├── lib/
│   │   ├── core/                      # Constants, theme, router, Supabase client
│   │   ├── data/                      # Drift local SQLite DB, SyncManager
│   │   ├── features/
│   │   │   ├── auth/                  # Login, Register, Forgot Password, Consent
│   │   │   ├── workout/               # Camera preview, calibration, live HUD
│   │   │   │   └── engine/            # PURE DART: analyzers, geometry, EMA, state machines
│   │   │   ├── heritage/              # Journey map, checkpoint monument cards
│   │   │   ├── leaderboard/           # Scope tabs, ranking lists
│   │   │   ├── progress/              # Charts, monthly summary, CSV export
│   │   │   └── profile/               # Language toggle, privacy settings, data management
│   │   └── main.dart                  # App bootstrap and initialization
│   ├── test/                          # Unit tests (pose engine, analyzers, Drift)
│   └── pubspec.yaml                   # Dart dependencies
├── web/                               # Minimal React + Vite Read-Only Dashboard
│   ├── src/
│   │   ├── components/                # Progress charts, leaderboard table, monument gallery
│   │   ├── lib/                       # Supabase JS client (anon key only)
│   │   └── App.tsx                    # Read-only dashboard view
│   ├── package.json
│   └── vite.config.ts
├── supabase/                          # Supabase Configuration & Migrations
│   ├── config.toml                    # Local CLI config (ports, auth, cron)
│   ├── migrations/                    # Monotonically ordered SQL migrations
│   │   └── 20260930000000_init_schema.sql
│   ├── functions/
│   │   └── delete-account/            # Exactly ONE Edge Function (Deno)
│   │       └── index.ts
│   ├── seed.sql                       # Heritage journey, checkpoints, app_config
│   └── tests/                         # pgTAP database tests (RLS, anti-cheat, RPC)
├── docs/                              # Project Documentation
│   ├── architecture.md                # This document
│   ├── api.md                         # Database & RPC Reference
│   ├── database.md                    # Postgres Schema, RLS, Indexes, Migrations
│   ├── security.md                    # Auth, Server Authority, Anti-Cheat
│   ├── privacy.md                     # DPDP Act 2023, Data Inventory, Privacy Flow
│   ├── pose-engine.md                 # Biomechanical Math, State Machines, Calibration
│   ├── ml-training.md                 # Future ML Strategy & Scoping Rationale
│   ├── development.md                 # Setup, Commands, Testing, Android Device Run
│   └── decisions.md                   # Architectural Decision Records (ADR)
└── README.md                          # Repository overview and quickstart
```

---

## 6. Implementation Phases

```
Phase 1: Documentation Rewrite & Verification (TASK 1) ── [CURRENT]
Phase 2: Project Scaffolding (Flutter, i18n en/or, Supabase CLI, Initial Migration)
Phase 3: Auth & Consent Workflow (Email Verification, Onboarding, Profile Row)
Phase 4: Pure-Dart Pose Engine & Comprehensive Unit Tests
Phase 5: Camera Pipeline, Calibration HUD, Skeleton Painter & TTS
Phase 6: Drift Offline SQLite Queue & submit_workout RPC Integration
Phase 7: Leaderboards, Monthly Progress Summaries, Adaptive Goals & CSV Export
Phase 8: Privacy Controls, export_my_data, delete-account Edge Function & pgTAP RLS Tests
Phase 9: Offline Airplane-Mode Sync Testing, Android Profiling & Polish
Phase 10: (Optional) Minimal React + Vite Read-Only Dashboard
```

---

## 7. Risks & Mitigations

| Risk | Severity | Description | Mitigation Strategy |
|---|---|---|---|
| **Supabase Free-Tier Inactivity Pause** | High | Hosted Supabase projects pause after 7 days of inactivity. | For hackathon demo/staging, automated ping script (`ping-supabase.sh`) or pg_cron query keeps the instance warm; local Supabase CLI is used for core development. |
| **Low-End Android Thermal & Frame Drops** | High | Camera frame acquisition + ML inference causes thermal throttling on low-end chipsets. | Throttle camera stream to 10–15 FPS; drop frames during busy inference; use low-resolution preview preset; avoid heavy canvas repaints. |
| **Offline Sync Conflicts & Clock Drift** | Medium | User device clock may be desynchronized or offline workouts batched over multiple days. | Client provides session duration and relative workout interval; server checks bounds against received server timestamp and enforces idempotent UUID deduplication. |
| **Landmark Occlusion in Small Rooms** | Medium | College dorm rooms have tight spaces where legs or feet are obscured by furniture. | Pre-workout calibration phase mandates full-body visibility; state machine enters `LOW_CONFIDENCE` state instead of guessing partial reps. |
| **Missing Odia TTS Voice on Low-Cost Phones**| Low | Some budget Android ROMs omit the Odia (`or_IN`) speech synthesis engine. | Graceful fallback checks available TTS voices; if Odia speech engine is absent, displays localized visual text alerts without crashing. |

---

## 8. Roadmap (Post-MVP / Not Built in Scope)

The following capabilities are explicitly documented for future commercial expansion and are **NOT built** in the hackathon MVP:
1. **Nutrition & Meal-Photo Engine:** Automated Odia food calorie estimation (e.g., Pakhala, Dalma, Chhena Poda) using multimodal vision.
2. **Accountability Workout Partners:** Peer-to-peer live workout rooms and synchronous campus challenges.
3. **OpenStreetMap (OSM) Campus Sync:** Geo-mapping real campus running paths and outdoor open-air gyms across Odisha colleges.
4. **Automated PDF Medical Reports:** PDF generation for physical education credit certificates and physician summaries.
5. **Yoga & Asana Flow Tracking:** Multi-pose static alignment verification for Surya Namaskar and Pranayama breath timers.
