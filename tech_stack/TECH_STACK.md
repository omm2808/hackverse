# Fit Odyssey — Comprehensive Tech Stack & Tools Reference

> **A Complete Overview of Architecture, Technologies, Frameworks, Libraries, and Tools with Their Purpose.**  
> *Prepared for development teams, technical architects, and project stakeholders.*

---

## 1. Executive System Overview

**Fit Odyssey** is an AI-powered, gamified fitness platform featuring real-time, on-device pose estimation, biomechanical angle analysis, deterministic exercise repetition gating, and an offline-first **MongoDB + NestJS** cloud synchronization architecture.

### Core Architectural Pillars
1. **Zero-Latency Edge AI**: Pose detection (Google BlazePose) and form classification (Custom Decision Forest) execute 100% on the mobile device without streaming video frames over the network (complete user privacy & zero network lag).
2. **Deterministic State Machine Rep Gating**: Machine learning classifies movement probabilities, while mathematical state machines count reps, evaluate joint depth, and reject non-exercise motion (walking, leg raises, arm waves).
3. **Pure Dart In-Process Execution**: The machine learning model runs directly in Dart via compact JSON decision trees, eliminating native C++ JNI bridge overhead and platform crash risks.
4. **Offline-First Synchronization with MongoDB**: A local SQLite database via Drift persists workouts on the phone. Once online, sessions, telemetry, and achievements sync to **MongoDB** via the NestJS backend API.
5. **Document-Oriented Database (MongoDB)**: Workout sessions, rep-by-rep kinematic telemetry, and dynamic gamification profiles are naturally hierarchical JSON structures, making MongoDB’s flexible schema and aggregation pipelines ideal for fitness analytics.
6. **Modern Monorepo Architecture**: Turborepo + pnpm workspaces manage backend services, web applications, and shared TypeScript domain libraries.

---

## 2. High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           ON-DEVICE MOBILE CLIENT (FLUTTER)                     │
│                                                                                 │
│   Camera Stream (30 FPS)                                                        │
│         │                                                                       │
│         ▼                                                                       │
│   Google ML Kit (BlazePose) ── Layer 1: 33 Normalized 3D Keypoints              │
│         │                                                                       │
│         ▼                                                                       │
│   MlKitPoseAdapter ────────── Decouples native ML Kit from Domain Engine        │
│         │                                                                       │
│         ▼                                                                       │
│   PoseSmoother ────────────── Exponential Moving Average (EMA) Jitter Filter    │
│         │                                                                       │
│         ▼                                                                       │
│   PoseFeatureExtractor ────── 140 Features (Angles, Velocities, Trunk Vectors)  │
│         │                                                                       │
│         ├───► Decision Forest Classifier ── Layer 2: Form & Exercise Prediction │
│         │                                                                       │
│         ▼                                                                       │
│   Exercise State Machines ─── Layer 3: Deterministic Repetition & Form Gates   │
│   ├── SquatStateMachine (Depth, Lateral Stability, Walking Rejection)           │
│   ├── PushupStateMachine (Occlusion-aware Elbow Flexion, Lockout, Hip Sag)      │
│   └── PlankStateMachine (Isometric Hold Timing, Spinal Alignment)               │
│         │                                                                       │
│         ├───► Flutter TTS Voice Feedback ("Drive up through heels!", etc.)      │
│         ├───► Real-Time Biomechanics HUD (Angle Gauges, Phase Badges, Rep Count)│
│         └───► Drift SQLite Storage (Offline Local Workout Persistence)          │
└────────────────────────────────────────┬────────────────────────────────────────┘
                                         │ Secure REST API (JSON / JWT)
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           BACKEND & CLOUD ECOSYSTEM                             │
│                                                                                 │
│   NestJS Enterprise API Gateway (@fit-odyssey/api)                              │
│         ├── JWT Authentication & User Session Management                        │
│         ├── Workout & Telemetry Ingestion Controller                            │
│         ├── Gamification & Progress Engine (XP, Badges, Streaks, Leaderboards)  │
│         └── Mongoose / MongoDB ODM Driver Layer                                 │
│                                                                                 │
│   MongoDB Database (Cloud Atlas / Self-Hosted)                                  │
│         ├── Users & Authentication Collection                                   │
│         ├── Workout Sessions & Rep Telemetry (Hierarchical JSON Documents)      │
│         ├── Gamification, Achievements & Social Feed Collections                │
│         └── Aggregation Pipelines for Athlete Progress & Performance Analytics  │
│                                                                                 │
│   Next.js 14 Web Portal (@fit-odyssey/web)                                      │
│         └── Responsive Athlete Analytics & Coach Performance Dashboard          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Mobile Client Tech Stack (`/mobile`)

The mobile client is a cross-platform application developed in Flutter and Dart, engineered specifically for high-frequency camera image stream processing.

| Technology / Tool | Version | Purpose in Fit Odyssey |
| :--- | :--- | :--- |
| **Flutter SDK** | `>=3.22.0` | Cross-platform UI toolkit providing high-performance 60 FPS rendering on Android and iOS with native hardware access. |
| **Dart SDK** | `>=3.4.0 <4.0.0` | Strongly-typed, sound-null-safe programming language powering the client UI and pure-Dart ML inference engine. |
| **google_mlkit_pose_detection** | `^0.12.0` | On-device Google ML Kit BlazePose edge model extracting 33 full-body 3D landmarks in real time from live camera stream. |
| **camera** | `^0.11.0` | Low-level camera controller capturing live preview frames via high-speed image streams (`NV21` / `YUV420`) with front/back switching and orientation handling. |
| **flutter_riverpod** | `^2.5.1` | Reactive state management framework managing dependency injection, workout session state, and UI state binding. |
| **go_router** | `^14.2.0` | Declarative, deep-linkable URL routing engine handling app transitions, modal sheets, and onboarding flows. |
| **flutter_tts** | `^4.0.2` | Text-to-Speech audio synthesizer providing hands-free, real-time voice coaching cues during active sets without looking at the screen. |
| **fl_chart** | `^0.68.0` | Interactive charting library rendering biomechanical velocity curves, joint angle telemetry, and workout progression charts. |
| **drift** | `^2.18.0` | Type-safe, reactive SQLite ORM and persistence library storing offline workout sessions, rep logs, and user profile data locally. |
| **sqlite3_flutter_libs** | `^0.5.20` | Bundled latest native SQLite C-libraries ensuring consistent database behavior across Android versions and architectures. |
| **connectivity_plus** | `^6.0.3` | Network status monitor detecting online/offline transitions to queue and resume background sync to the MongoDB backend. |
| **flutter_secure_storage** | `^9.0.0` | Hardware-backed encrypted key-value storage (Android Keystore / iOS Keychain) storing JWT auth tokens and sensitive credentials. |
| **share_plus** | `^9.0.0` | System share dialog integration enabling athletes to share workout summaries, PR achievements, and rep telemetry cards. |
| **path_provider** | `^2.1.3` | Multi-platform file-system locator accessing device cache, app support, and document directories for logs and local assets. |
| **intl & flutter_localizations** | `>=0.19.0` | Internationalization and localization framework managing multi-language UI, number formatting, and date/time formatting. |
| **flutter_test & flutter_lints** | `^4.0.0` | Unit, widget, and state machine test runner paired with official Dart strict linting rules. |
| **drift_dev & build_runner** | `^2.18.0` | Code generation utilities producing type-safe SQLite query code, database schema migrations, and model serializers. |

---

## 4. Machine Learning & Biomechanical Engine Stack (`/ml` & `/mobile/lib/core/pose_engine`)

The intelligence pipeline combines computer vision, mathematical kinematics, scikit-learn models, and deterministic state machines.

| Technology / Tool | Category | Purpose in Fit Odyssey |
| :--- | :--- | :--- |
| **Google BlazePose (MediaPipe)** | Edge Pose Tracking | Detects 33 anatomical landmarks (shoulders, elbows, wrists, hips, knees, ankles, feet) with 3D coordinate estimation. |
| **MlKitPoseAdapter** | Architectural Bridge | Isolates native Google ML Kit data structures from domain entities, enabling pure testability with synthetic frames. |
| **PoseSmoother (EMA)** | Signal Processing | Exponential Moving Average filter ($\alpha = 0.65$) smoothing camera landmark jitter without introducing perceptual lag. |
| **PoseFeatureExtractor** | Kinematic Engineering | Computes 140 standardized features from landmarks: 99 normalized coordinates, 12 joint angles, 12 relative distances, and 17 temporal velocity/acceleration derivatives. |
| **Python 3.10+** | ML Training Runtime | Runtime environment for dataset preparation, feature extraction, cross-validation, and model serialization. |
| **scikit-learn** | ML Framework | Trains `RandomForestClassifier` and `LogisticRegression` models on curated biomechanical datasets for exercise and form classification. |
| **pandas & numpy** | Data Processing | Vectorized data manipulation, coordinate normalization, batch transformations, and dataset splitting. |
| **pyarrow (Parquet)** | Data Storage | High-speed columnar storage format for normalized multi-gigabyte pose landmark training datasets. |
| **Decision Forest Engine (Pure Dart)** | Edge Model Interpreter | Custom tree-traversal evaluator executing the exported scikit-learn random forest directly in Dart without C++ dependencies or TFLite runtime bloat. |
| **SquatStateMachine & SquatRepGate** | Biomechanical Logic | Multi-signal squat tracker enforcing parallel depth ($\le 105^\circ$), side-angle lean calibration ($\le 82^\circ$), bilateral symmetry, and scale-drift walking rejection. |
| **PushupStateMachine** | Biomechanical Logic | Push-up tracker with side-camera occlusion compensation (`effectiveElbow`), horizontal posture gating, lockout detection ($140^\circ$), and hip sag/pike alerts. |
| **PlankStateMachine** | Biomechanical Logic | Isometric hold analyzer tracking duration and alerting users to hip elevation or lumbar sagging. |

---

## 5. Backend API Tech Stack (`/apps/api`)

The backend API is a modular enterprise microservice handling business logic, MongoDB persistence, analytics, and integrations.

| Technology / Tool | Version | Purpose in Fit Odyssey |
| :--- | :--- | :--- |
| **NestJS** | `^10.3.8` | Enterprise progressive Node.js framework providing modular architecture, dependency injection, and decorators. |
| **MongoDB / Mongoose** | Latest | Document-oriented database driver mapping workout telemetry, user accounts, and gamification events to MongoDB collections. |
| **Express Platform** | `^10.3.8` | Battle-tested HTTP server powering NestJS request routing, middleware execution, and REST endpoints. |
| **TypeScript** | `^5.8.2` | Statically-typed superset of JavaScript ensuring end-to-end type safety between backend, database, and frontend. |
| **RxJS** | `^7.8.1` | Reactive programming library utilized within NestJS interceptors, asynchronous stream handling, and event pipelines. |
| **Reflect-Metadata** | `^0.2.2` | Runtime metadata reflection polyfill enabling NestJS decorator-based dependency injection. |
| **Nest CLI & Schematics** | `^10.3.2` | Command-line developer tool for generating boilerplate-free modules, controllers, services, and build configurations. |

---

## 6. Web Dashboard Tech Stack (`/apps/web`)

The web client provides athletes and trainers with full-screen telemetry review, historical analytics, and account management.

| Technology / Tool | Version | Purpose in Fit Odyssey |
| :--- | :--- | :--- |
| **Next.js** | `^14.2.20` | React framework utilizing the App Router, server-side rendering (SSR), static site generation, and optimized image delivery. |
| **React & React DOM** | `^18.3.1` | Component-based declarative user interface library powering all web views and interactive widgets. |
| **Tailwind CSS** | `^3.4.17` | Utility-first CSS framework enabling design token styling, responsive layouts, and dark mode theming. |
| **PostCSS & Autoprefixer** | `^8.4.49` | CSS processing pipeline adding vendor prefixes and optimizing production stylesheets. |
| **Lucide React** | `^0.460.0` | Comprehensive, consistent vector icon library for dashboard navigation, badges, and exercise indicators. |
| **clsx & tailwind-merge** | `^2.1.1` | Utility functions for conditionally merging Tailwind CSS classes without specificity conflicts. |

---

## 7. Shared Monorepo Packages (`/packages`)

Shared packages allow code reuse, unified types, and synchronized validation rules across Web, Mobile, and Backend API.

| Package | Purpose |
| :--- | :--- |
| **`@fit-odyssey/shared-types`** | Canonical TypeScript interfaces and types for User Profiles, MongoDB Workout Documents, Rep Telemetry, Badges, and Auth. |
| **`@fit-odyssey/config`** | Shared application constants, MongoDB connection URIs, environment variable schemas, and configuration profiles. |
| **`@fit-odyssey/validation`** | Reusable validation schemas ensuring consistent input validation across Web and Backend API. |
| **`@fit-odyssey/api-client`** | Type-safe HTTP client abstraction utilized by the web frontend and mobile client to communicate with the NestJS API. |
| **`@fit-odyssey/gamification`** | Gamification domain rules calculating XP points, leveling curves, streak bonuses, and badge eligibility. |
| **`@fit-odyssey/progress-engine`**| Mathematical routines calculating volume load, 1RM estimations, velocity loss, and consistency metrics. |
| **`@fit-odyssey/pose-engine`** | Shared kinematics and landmark interface definitions shared across TypeScript consumers. |

---

## 8. Database, Cloud & Infrastructure Stack (MongoDB Architecture)

| Technology / Tool | Layer | Purpose in Fit Odyssey |
| :--- | :--- | :--- |
| **MongoDB** | Primary Database | Document-oriented NoSQL database storing users, nested workout sessions, rep-by-rep telemetry arrays, and social feeds. |
| **MongoDB Atlas** | Cloud Deployment | Fully managed cloud database with automated scaling, global replication, automated backups, and encryption at rest. |
| **MongoDB Aggregation Framework** | Analytics Engine | Server-side pipeline stages (`$group`, `$facet`, `$unwind`, `$match`) computing athlete workout stats, PR trends, and leaderboards. |
| **Mongoose ODM / MongoDB Native Driver** | Data Modeling | Schema validation, indexing (compound, geospatial, TTL for tokens), and lifecycle middleware in NestJS. |
| **Drift (SQLite)** | Edge Local DB | Client-side SQLite storage on mobile ensuring offline workout tracking, synced to MongoDB when network reconnects. |
| **Turborepo (`turbo`)** | Monorepo Orchestration | High-performance build system with intelligent task caching, parallel execution, and dependency graph pruning. |
| **pnpm Workspaces** | Package Management | Fast, disk-space-efficient package manager leveraging hard links and strict dependency isolation. |

---

## 9. Why MongoDB is Chosen for Fit Odyssey

1. **Natural Fit for Nested Workout Telemetry**:
   - A single workout session contains metadata, exercise lists, and arrays of completed reps (each with peak joint angles, active biomechanical flags, duration, and confidence scores).
   - In relational SQL, this requires complex multi-table joins across `workouts`, `sets`, `reps`, and `telemetry_flags`. In **MongoDB**, an entire workout session is stored as a rich, unified document retrieved in a single sub-millisecond query.
2. **Schema Flexibility for Emerging Exercises**:
   - As new exercises are introduced (squats, push-ups, planks, pull-ups, lunges), each exercise has unique biomechanical parameters (e.g. elbow angles for push-ups vs. knee flexion for squats). MongoDB accommodates polymorphic exercise documents without migration locks.
3. **High-Speed Time-Series & Aggregation**:
   - MongoDB Aggregation Pipelines allow rapid computation of athlete volume load, weekly consistency streaks, and exercise-specific personal records directly on the database cluster.

---

## 10. Summary Matrix by Layer

| Layer | Primary Technologies | Key Responsibility |
| :--- | :--- | :--- |
| **Edge Vision (Mobile)** | Flutter, Google ML Kit BlazePose | Real-time camera capture & 33 3D landmark extraction |
| **AI Inference (Mobile)** | Pure Dart Decision Forest (JSON weights) | Zero-latency on-device form & exercise classification |
| **Kinematics & Reps** | Custom State Machines (Dart) | Rep counting, depth checks, occlusion correction, tempo |
| **Mobile Local Storage** | Drift (SQLite), Secure Storage | Offline persistence, local query reactivity, token safety |
| **Cloud Database** | **MongoDB (Atlas / Self-Hosted)** | Document store for workouts, rep telemetry, users, feeds |
| **Backend API** | NestJS, TypeScript, Mongoose/MongoDB | REST API gateway, business logic, analytics pipelines |
| **Web Portal** | Next.js 14, React 18, Tailwind CSS | Web-based athlete dashboard & coach telemetry review |
| **Build & Tooling** | Turborepo, pnpm workspaces | Monorepo caching, build automation, dependency sharing |

---
*Fit Odyssey Engineering Documentation — Tech Stack & Tooling Reference.*
