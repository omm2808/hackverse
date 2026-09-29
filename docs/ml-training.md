# Fit Odyssey — Machine Learning Training & Model Architecture

> **Document Version:** 1.0.0  
> **Target:** Layer 2 Custom Exercise & Movement Classification Model

---

## 1. Why Pretrained MediaPipe is Used (Layer 1)

Training a full computer vision body-pose keypoint estimator from raw RGB pixels requires millions of annotated images, massive GPU clusters, and complex heatmap regression architectures. 

Instead, we use **MediaPipe Pose Landmarker** on the edge:
- **Efficiency:** Hardware-accelerated (CPU/GPU delegate) inference optimized specifically for mobile devices.
- **Rich Topology:** Produces 33 3D normalized body landmarks (x, y, z, and visibility score) in real time (30+ FPS).
- **Zero Raw Video Transmission:** Landmarks are computed directly on the smartphone, eliminating video streaming latency, server infrastructure costs, and privacy vulnerabilities.

MediaPipe serves as **Layer 1: Edge Pose Estimation**.

---

## 2. Why We Train a Custom Model (Layer 2)

While MediaPipe tells us *where* joints are located in space, it does not understand *what exercise is being performed* or the *biomechanical movement phase*:
1. **Exercise Disambiguation:** Differentiates between similar postures (e.g., distinguishing a low squat from a forward fold or seated rest).
2. **Robustness to View Angle & Perspective Distortion:** A custom neural classifier trained on diverse Indian user datasets learns invariance across side, diagonal, and frontal smartphone camera angles.
3. **Adaptive Movement-State Classification:** Identifies micro-phases of repetitions (eccentric descent, isometric inflection, concentric ascent) to drive downstream state machines.
4. **Zero Hardware Constraint:** Runs on landmark vectors (16–64 floats), requiring $< 0.5\text{ ms}$ inference time and $< 2\text{ MB}$ memory footprint.

---

## 3. Data Pipeline: Dataset → Landmarks → Features → Model

```
Raw Exercise Video / Images
          │
          ▼
MediaPipe Landmark Extractor
(33 landmarks × [x, y, z, visibility])
          │
          ▼
Mid-Hip Translation & Torso Scale Normalization
(Invariant to user height and camera distance)
          │
          ▼
Biomechanical Feature Engineering
- 8 Joint angles (left/right knees, hips, elbows, shoulders)
- Normalized vertical coordinate offsets (knees, hips, shoulders, wrists)
- Temporal displacement / velocity over sliding window
          │
          ▼
Feature Vector $X \in \mathbb{R}^{D}$ (or Sequence $X \in \mathbb{R}^{T \times D}$)
          │
          ▼
Custom Model Classifier (Layer 2)
```

---

## 4. Model Training Pipeline

```
DATASET 
  ↓
DATASET INSPECTION (Inspect classes, fps, sequence lengths, subjects)
  ↓
DATA VALIDATION (Filter low-confidence frames, occluded joints)
  ↓
POSE LANDMARK EXTRACTION (Extract 33 3D landmarks)
  ↓
LANDMARK NORMALIZATION (Mid-hip zero-centering + Torso scaling)
  ↓
FEATURE ENGINEERING (Joint angles & coordinate deltas)
  ↓
SUBJECT/SESSION-LEVEL DATA SPLIT (Strictly isolate participants to prevent leakage)
  ↓
MODEL TRAINING (Lightweight MLP / 1D-CNN / GRU)
  ↓
VALIDATION & HYPERPARAMETER TUNING
  ↓
TEST SET INFERENCE & DIAGNOSTICS
  ↓
MODEL EXPORT WITH METADATA MANIFEST
```

### Critical Rule: No Data Leakage
- **Frames from the same subject/session must NEVER appear in both training and test sets.**
- Random frame-level shuffling causes extreme synthetic over-fitting due to consecutive video frames sharing background, clothing, lighting, and anatomy.
- Splits are partitioned strictly by `subject_id` (e.g., 70% train subjects, 15% validation subjects, 15% test subjects).

---

## 5. Model Selection Strategy

The final architecture will be selected based on dataset characteristics:

| Dataset Characteristics | Recommended Architecture | Latency | Mobile Suitability |
|---|---|---|---|
| Static poses / discrete frames | **Lightweight MLP** (Dense 64 → 32 → Softmax) | $< 0.1\text{ ms}$ | Extremely High |
| Fixed temporal windows (e.g. 1–2 sec clips) | **1D Temporal CNN** (Conv1D + Pooling) | $< 0.4\text{ ms}$ | Very High |
| Variable length continuous sequences | **Lightweight GRU** (48 units) | $< 1.2\text{ ms}$ | High |

---

## 6. Evaluation Framework

Models are evaluated on held-out subjects using:
- **Macro & Micro F1-Score:** Ensures minor classes or rare movement anomalies are not dominated by idle frames.
- **Confusion Matrix Analysis:** Identifies cross-exercise misclassifications.
- **Latency Benchmark:** Confirms mobile execution completes well under 10 ms per frame.
- **Cross-Subject Generalization Gap:** Difference between train and validation accuracy must not exceed 8%.

---

## 7. Model Export & Format

Trained models are exported to:
- **TensorFlow Lite (`.tflite`)** with FP16 or INT8 quantization for mobile execution.
- **ONNX (`.onnx`)** for cross-platform interoperability.
- **Metadata Manifest (`.metadata.json`)** generated alongside the binary.

---

## 8. Model Versioning Specification

Every exported model bundle includes an immutable metadata manifest:

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
    "features": 16,
    "angles_included": ["knee", "hip", "elbow", "shoulder"]
  },
  "model_format": "tflite"
}
```

---

## 9. Mobile Inference Pipeline (Edge)

```
[ Camera Feed (Mobile) ]
          │
          ▼
[ MediaPipe Pose Landmarker ] (Runs on edge GPU/NPU)
          │  33 landmarks
          ▼
[ Normalization & Feature Extraction ] (packages/pose-engine)
          │  16 floats
          ▼
[ Custom Exercise Model ] (Layer 2 Inference)
          │  Exercise Class & Confidence
          ▼
[ Deterministic State Machine Engine ] (packages/pose-engine)
          │  Rep counted / Hold tracked / Form checked
          ▼
[ Real-Time Audio/Visual HUD Feedback ]
          │
          ▼
[ Workout Session Metrics ] ──(Sync)──▶ [ Shared NestJS Backend ]
```

---

## 10. Privacy Guarantees

1. **Zero Raw Video Leaving Device:** Video frames exist solely in volatile memory during camera capture and are processed frame-by-frame on device.
2. **Zero Frame Upload:** No backend API endpoint exists or will ever be created to upload video frames.
3. **Metrics-Only Synchronization:** Only summarized workout results (exercise ID, repetition count, duration seconds, form accuracy score) are synced to the backend.

---

## 11. Known Limitations & Roadmap

- **Occlusion:** Low camera angles where legs or arms are blocked will trigger a calibration warning ("Full body not visible").
- **Lighting:** Drastic underexposure reduces MediaPipe landmark visibility scores.
- **Future Exercises:** Extension interfaces allow plug-and-play addition of Lunges, Surya Namaskar, and Jumping Jacks upon collecting relevant subject training data.
