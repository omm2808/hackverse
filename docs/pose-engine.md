# Fit Odyssey — Pose Engine & Biomechanical Architecture

> **Architecture:** Single-Layer On-Device Deterministic Pipeline  
> **Engine Runtime:** Pure Dart Module (`mobile/lib/features/workout/engine/`)  
> **Vision Model:** Google ML Kit BlazePose (On-Device, 33 3D Keypoints)  
> **Design Philosophy:** 100% deterministic, explainable biomechanics. Zero external network dependency, zero black-box custom ML classifier.

---

## 1. Single-Layer On-Device Pipeline

```
 [ Camera Frame (~10-15 FPS) ]
               │
               ▼
 [ Google ML Kit Pose Detection ] ── 33 3D Landmarks (x, y, z, visibility)
               │
               ▼
 [ Thin Adapter Layer ]           ── Converts ML Kit Pose to pure-Dart PoseFrame
               │
               ▼
 [ Temporal Smoothing (EMA) ]     ── EMA Filter (α = 0.6) removes frame jitter
               │
               ▼
 [ Biomechanical Math ]           ── Calculates 3D joint angles & torso verticality
               │
               ▼
 [ Deterministic State Machine ]  ── Exercise-specific state progression (Squat/Push-up/Plank)
               │
               ▼
 [ Form Evaluation & Flags ]      ── Checks knee valgus, spine sagging, torso lean
               │
               ▼
 [ Real-Time Feedback Delivery ]  ── Visual HUD chips + Audio Cues (flutter_tts: English / Odia)
```

---

## 2. Pure-Dart Module Isolation

To ensure complete testability and enforce strict privacy barriers, the pose engine resides in:
`mobile/lib/features/workout/engine/`

### Architectural Rules:
1. **Zero Framework Dependencies:** The engine imports **neither** Flutter UI packages (`flutter/material.dart`), camera drivers (`camera`), nor ML Kit types (`google_mlkit_pose_detection`).
2. **Zero Network / Disk IO:** No imports from `dart:io`, `http`, or `supabase_flutter`.
3. **Pluggable Testing:** Unit tests run entirely in standard Dart CLI environments using synthesized coordinate frames without mocking hardware.
4. **Thin Adapter:** A single translation class in the mobile app maps ML Kit landmarks to internal immutable `Landmark` and `PoseFrame` domain objects.

---

## 3. Core Interface & Contracts

```dart
/// Represents a 3D coordinate point with visibility confidence
class Landmark {
  final double x;
  final double y;
  final double z;
  final double visibility;
  const Landmark({required this.x, required this.y, required this.z, required this.visibility});
}

/// A single timestamped frame containing the 33 BlazePose landmarks
class PoseFrame {
  final Map<int, Landmark> landmarks;
  final int timestampMs;
  const PoseFrame({required this.landmarks, required this.timestampMs});
}

/// Pre-workout calibration diagnostic result
class CalibrationResult {
  final bool isReady;
  final bool isFullBodyVisible;
  final bool isDistanceOk;
  final double averageConfidence;
  final String feedbackMessage;
  const CalibrationResult({
    required this.isReady,
    required this.isFullBodyVisible,
    required this.isDistanceOk,
    required this.averageConfidence,
    required this.feedbackMessage,
  });
}

/// Analysis output produced for each incoming frame
class AnalysisResult {
  final String exercise;
  final String currentState;
  final int completedReps;
  final double holdDurationSec;
  final double formAccuracy;
  final List<String> activeFormFlags;
  final String? audioCue;
  final String? visualFeedback;
  final bool isConfidenceLow;
  const AnalysisResult({
    required this.exercise,
    required this.currentState,
    required this.completedReps,
    required this.holdDurationSec,
    required this.formAccuracy,
    required this.activeFormFlags,
    this.audioCue,
    this.visualFeedback,
    this.isConfidenceLow = false,
  });
}

/// Base contract for all exercise analyzers
abstract class ExerciseAnalyzer {
  CalibrationResult checkCalibration(PoseFrame frame);
  AnalysisResult analyze(PoseFrame frame, int timestampMs);
  void reset();
}
```

---

## 4. Centralized Biomechanical Configuration Constants

All operational constants, smoothing parameters, and angle thresholds are defined in `pose_engine_config.dart`:

```dart
class PoseEngineConfig {
  // Smoothing & Confidence
  static const double emaAlpha = 0.6; // Single global EMA smoothing constant
  static const double minLandmarkVisibility = 0.6; // Discard landmarks below this confidence
  static const int minPhaseDurationMs = 250; // Prevents phantom bounces
  static const int repDebounceMs = 400; // Debounce window between completed reps
  static const int partialRepTimeoutMs = 3000; // Reset stuck partial rep after 3 seconds

  // Squat Thresholds (Hip-Knee-Ankle)
  static const double squatStandingMinAngle = 150.0;
  static const double squatBottomMaxAngle = 100.0; // Depth threshold ("Good depth!")
  static const double squatAscentAngle = 110.0;
  static const double squatRepCompleteAngle = 160.0;
  static const double squatMaxTorsoLeanDeg = 45.0; // Angle from vertical
  static const double squatKneeValgusRatioMin = 0.85; // Knee distance / Ankle distance

  // Push-up Thresholds (Shoulder-Elbow-Wrist + Spine)
  static const double pushupHighMinAngle = 150.0;
  static const double pushupBottomMaxAngle = 95.0;
  static const double pushupAscentAngle = 105.0;
  static const double pushupRepCompleteAngle = 155.0;
  static const double pushupMinBodyLineAngle = 150.0; // Sagging threshold

  // Plank Thresholds (Shoulder-Hip-Ankle)
  static const double plankMinValidSpineAngle = 155.0; // Sagging if below
  static const double plankMaxValidSpineAngle = 185.0; // Piked if above
}
```

---

## 5. Exercise State Machine Specifications

### 5.1. Squat Analyzer (`SquatAnalyzer`)
- **Tracked Joints:** Hip–Knee–Ankle angle (bilateral average), Hip–Shoulder torso vertical inclination, Knee-to-Ankle lateral ratio.
- **State Progression:**
  1. `STANDING`: Angle $\ge 150^\circ$. Awaits initiation of descent.
  2. `DESCENDING`: Angle drops $< 150^\circ$. Minimum phase duration: 250 ms.
  3. `BOTTOM`: Angle reaches $\le 100^\circ$. Triggers audio cue: `"Good depth"`. Form accuracy evaluated.
  4. `ASCENDING`: Angle rises $> 110^\circ$.
  5. `STANDING`: Angle reaches $\ge 160^\circ$ $\implies$ **Rep Validated (+1)**. Debounced for 400 ms.
- **Partial Rep Guard:** If descent stops without reaching $\le 100^\circ$ and user returns to standing, triggers visual feedback: `"Go slightly lower"` without incrementing rep counter.
- **Injury Flags:**
  - *Knee Valgus:* Knee distance divided by ankle distance $< 0.85$ (knees caving inward).
  - *Torso Lean:* Torso inclination relative to vertical $> 45^\circ$.

### 5.2. Push-Up Analyzer (`PushUpAnalyzer`)
- **Tracked Joints:** Shoulder–Elbow–Wrist angle and Shoulder–Hip–Ankle spine line.
- **State Progression:**
  1. `HIGH`: Elbow angle $\ge 150^\circ$.
  2. `DESCENDING`: Elbow angle $< 150^\circ$.
  3. `BOTTOM`: Elbow angle $\le 95^\circ$.
  4. `ASCENDING`: Elbow angle rises $> 105^\circ$.
  5. `HIGH`: Elbow angle $\ge 155^\circ$ $\implies$ **Rep Validated (+1)**.
- **Injury Flags:**
  - *Sagging Hips:* Spine angle $< 150^\circ$ during repetition.

### 5.3. Plank Analyzer (`PlankAnalyzer`)
- **Tracked Geometry:** Continuous Shoulder–Hip–Ankle spine alignment angle.
- **State Progression:**
  1. `HOLDING`: Spine angle remains within $155^\circ \le \theta \le 185^\circ$. Hold timer increments continuously in tenths of a second.
  2. `PAUSED_SAGGING`: Spine angle $< 155^\circ$. Timer pauses immediately; visual/audio alert: `"Raise your hips"`.
  3. `PAUSED_PIKED`: Spine angle $> 185^\circ$. Timer pauses immediately; visual/audio alert: `"Lower your hips"`.

---

## 6. Pre-Workout Calibration Flow

Before any exercise set begins, the user enters a full-screen Calibration screen:
1. **Pose Detection Readiness:** Confirms ML Kit landmark detector is initialized.
2. **Full Body Visibility:** Checks that required landmarks (shoulders, hips, knees, ankles) all exceed visibility confidence $\ge 0.6$.
3. **Distance Check:** Evaluates bounding box height and torso length against viewport dimensions to ensure the user is neither too close nor too far ($1.8\text{m} - 2.5\text{m}$ optimal).
4. **Confidence Threshold:** Average confidence across key joints must be $\ge 0.70$.
5. **Auto-Countdown:** When calibration conditions hold stable for 1.5 seconds, an animated 3-2-1 audio-visual countdown triggers the workout session start.

---

## 7. Low-End Android Optimization Strategy

Targeting budget Android devices common in student communities requires disciplined resource management:

- **Throttled Frame Pipeline:** Camera stream frames are throttled to ~10–15 FPS. When a frame is being processed by ML Kit, subsequent frames are immediately dropped (`isProcessing` lock).
- **Camera Resolution:** Initialized with `ResolutionPreset.medium` (or `low` on entry-level devices) rather than full HD, reducing native pixel buffer copies.
- **Garbage Collection Optimization:** Reusable landmark vectors and coordinate buffers minimize heap allocations per frame.
- **Lightweight Skeleton Drawing:** Overlay rendered via a custom Flutter `CustomPainter` that repaints only landmark points and connection bones with confidence $\ge 0.6$.
- **Lifecycle Cleanup:** Camera controllers and ML Kit detectors are aggressively closed in `dispose()`.

---

## 8. Bilingual Audio & Voice Feedback (`flutter_tts`)

- **Speech Engine:** Configured using `flutter_tts` for immediate auditory cues during exercise.
- **Supported Locales:** English (`en_IN` / `en_US`) and Odia (`or_IN`).
- **Graceful Fallback:** If the device lacks Odia speech synthesis voice data, the app falls back seamlessly to English speech or silent visual HUD alerts without throwing exceptions.
- **Cues Library:**
  - Rep count: `"One"`, `"Two"`, `"Three"` / `"ଏକ"`, `"ଦୁଇ"`, `"ତିନି"`
  - Form guidance: `"Good depth"`, `"Go slightly lower"`, `"Keep your chest up"`, `"Raise your hips"` / `"ଅଣ୍ଟା ସିଧା ରଖନ୍ତୁ"`

---

## 9. Synthetic Testing Methodology

Because the pose engine is a pure Dart module, unit tests generate mathematical coordinate trajectories to simulate human movement scenarios:
- **`valid_squat_test.dart`**: Simulates smooth sinusoidal knee angles from $170^\circ \to 90^\circ \to 170^\circ$, verifying rep count $+1$.
- **`partial_squat_test.dart`**: Simulates descent to $115^\circ$ (stopping short of $100^\circ$ bottom) and returning to standing, verifying rep count remains $0$ and corrective feedback is generated.
- **`knee_valgus_test.dart`**: Injects narrowing knee x-coordinates during ascent, verifying `knee_valgus` flag is incremented.
- **`jitter_robustness_test.dart`**: Injects $\pm 5^\circ$ Gaussian noise into landmark coordinates, verifying EMA filter ($\alpha=0.6$) absorbs jitter without false phase switches.
- **`low_visibility_test.dart`**: Injects visibility $< 0.6$, verifying engine enters `LOW_CONFIDENCE` state instead of guessing angles.
