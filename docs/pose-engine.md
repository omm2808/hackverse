# Fit Odyssey — Pose Engine Architecture

## Architectural Separation
- `packages/pose-engine`: Reusable, platform-agnostic exercise analyzers, landmark mathematical functions, temporal exponential moving average (EMA) smoothing, state machines, and real-time form feedback rules.
- `apps/mobile`: Native camera stream access, hardware frame acquisition, MediaPipe bridge lifecycle, and real-time UI canvas overlay rendering.
- `apps/web`: No camera workout pipeline in MVP (as specified).

## Exercise State Machine Design
Exercises implement the `ExerciseAnalyzer` interface:
- **SquatAnalyzer**: Tracks hip-knee-ankle angles through `STANDING -> DESCENDING -> BOTTOM -> ASCENDING -> STANDING`
- **PushUpAnalyzer**: Tracks shoulder-elbow-wrist and torso alignment
- **PlankAnalyzer**: Tracks continuous hold duration and spine curvature
