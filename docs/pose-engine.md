# Fit Odyssey — Pose Engine & AI Model Architecture

## 1. Architectural Separation

- **`packages/pose-engine`**: Platform-independent, reusable computational core:
  - 33 landmark topology and geometric definitions (`Point3D`, `PoseLandmark`).
  - Exponential Moving Average (`LandmarkSmoother`) for frame-to-frame jitter removal.
  - Scale & translation invariant normalization (`normalizeLandmarks` via mid-hip & torso scaling).
  - 16-dimensional biomechanical feature extraction (`extractLandmarkFeatures`).
  - Layer 2 model interfaces (`CustomModelPredictor`, `ModelPrediction`, `ModelMetadata`).
  - Deterministic state machines for rep counting, hold timing, and real-time form feedback rules.
  - **Strict Constraint:** Contains NO native camera code, Expo camera code, Android/iOS code, or ML training code.

- **`apps/mobile`**: Platform-specific edge execution:
  - Native camera preview and frame acquisition.
  - MediaPipe Pose Landmarker edge runtime execution (Layer 1).
  - On-device inference runner for the custom model (Layer 2, e.g., TFLite / ONNX runtime).
  - Real-time HUD canvas rendering (landmark skeletons, rep counters, form feedback chips).
  - Local workout session persistence and sync queue manager.

- **`ml/`**: Independent Python machine learning workspace:
  - Offline landmark extraction from training videos.
  - Subject/session-level leakage-free dataset splitting.
  - Architecture search and training (MLP, 1D-CNN, GRU).
  - Evaluation diagnostics and mobile-optimized model export with versioning manifests.

- **`apps/web`**: Web Command Center:
  - Consumes processed workout results from the shared NestJS API.
  - Does NOT include real-time camera workout functionality in MVP.

---

## 2. On-Device Three-Stage Pipeline

```
[ Camera Frame (Mobile Native) ]
              │
              ▼
[ MediaPipe Pose Landmarker ]  ── Layer 1: Edge Pose Estimator
              │  33 (x, y, z, visibility) coordinates
              ▼
[ Temporal Smoothing (EMA) ]   ── Jitter reduction filter (α = 0.6)
              │
              ▼
[ Normalization ]              ── Mid-hip zero-centering & torso-scale normalization
              │
              ▼
[ Feature Extraction ]         ── 16 biomechanical joint angles & coordinate deltas
              │
              ▼
[ Custom Trained Model ]       ── Layer 2: Exercise & Movement Phase Classifier
              │  Class probabilities & movement state
              ▼
[ Deterministic State Machine] ── Layer 3: Rep Counting & Hold Duration Tracking
              │
              ▼
[ Real-Time Form Feedback ]    ── Audio/Visual cues ("Good depth", "Keep chest upright")
              │
              ▼
[ Session Metrics & Sync ]     ── Only aggregated metrics sent to shared NestJS API
```

---

## 3. Exercise State Machine Specifications

### SquatAnalyzer
- **Key Joint Tracked:** Hip–Knee–Ankle angle.
- **State Progression:**
  - `STANDING`: Angle $\ge 150^\circ$
  - `DESCENDING`: Angle drops $< 150^\circ$
  - `BOTTOM`: Angle reaches $\le 100^\circ$ (triggers "Good depth!")
  - `ASCENDING`: Angle returns upwards $> 110^\circ$
  - `STANDING`: Angle reaches $\ge 160^\circ$ $\implies$ Rep validated (+1)
- **Anti-Cheat:** Double counting debounced; partial repetitions without reaching bottom trigger corrective feedback ("Go slightly lower") rather than a rep increment.

### PushUpAnalyzer
- **Key Joint Tracked:** Shoulder–Elbow–Wrist angle and spine alignment.
- **State Progression:**
  - `PLANK_HIGH`: Angle $\ge 150^\circ$
  - `DESCENDING`: Angle drops $< 150^\circ$
  - `BOTTOM`: Angle reaches $\le 95^\circ$
  - `ASCENDING`: Angle returns upwards $> 105^\circ$
  - `PLANK_HIGH`: Angle reaches $\ge 155^\circ$ $\implies$ Rep validated (+1)

### PlankAnalyzer
- **Key Dimension Tracked:** Shoulder–Hip–Ankle spine angle ($155^\circ - 185^\circ$) and continuous hold timer.
- **State Progression:**
  - `HOLDING`: Torso and hips aligned; hold timer increments in seconds.
  - `IMPROPER_FORM`: Sagging hips ($< 155^\circ$) or piked hips ($> 185^\circ$) pauses hold timer and warns user.
