# Fit Odyssey — Pose Landmark Extraction & ML Preprocessing Pipeline

This directory contains the automated preprocessing, pose estimation, landmark normalization, and feature engineering pipeline for Fit Odyssey's custom Layer-2 ML model.

---

## 1. Pipeline Overview

```
Raw Video (.mp4)
      │
      ▼  (Temporal sampling @ ~15 FPS)
MediaPipe PoseLandmarker (33 3D Keypoints)
      │
      ▼  (Body-relative origin & torso scaling)
Landmark Normalization (x', y', z')
      │
      ▼  (Kinematic & temporal feature extraction)
Feature Engineering (Groups A, B, C, D — 140 features)
      │
      ▼  (PyArrow Snappy Parquet)
ML-Ready Split Datasets (Train / Val / Test)
```

---

## 2. Directory Structure

```
ml/preprocessing/
├── extract_landmarks.py    # Main orchestration pipeline & batch extractor
├── pose_extractor.py       # MediaPipe Tasks Vision wrapper & skeleton overlay
├── normalize.py            # Mid-hip centering & torso scale normalization
├── feature_engineering.py  # 140 kinematic, angular, spatial & temporal features
├── metadata.py             # Dataset scanner, split assignment & leakage verification
└── README.md               # Documentation and execution instructions
```

---

## 3. Input Dataset

- **Path**: `ml/dataset/raw/Dataset Subject-wise/`
- **Scope**: Target MVP exercises only:
  - `squat` (150 videos)
  - `push_up` (144 videos)
  - **Total**: 294 videos
  - *Non-MVP exercises (`abs`, `back`, `bicep_curl`, `shoulder`, `tricep`) are untouched and excluded at this stage.*
- **Labels**: Balanced 50% Good form / 50% Bad form across Front, Side, and Diagonal camera views.

---

## 4. Subject-Level Splitting & Leakage Prevention

To strictly prevent data leakage and inflated validation metrics:
- **Rule**: All videos from a single human subject belong exclusively to one split partition. Frames or videos from the same subject are never split randomly.
- **Approved Splits**:
  - **TRAIN** (18 subjects): `001, 002, 003, 004, 005, 006, 007, 008, 009, 010, 011, 012, 013, 014, 015, 019, 020, 026` (210 videos)
  - **VALIDATION** (4 subjects): `016, 017, 018, 021` (48 videos)
  - **TEST** (3 subjects with target exercises): `022, 023, 024` (36 videos; `025` only performed triceps)
- **Duplicate Protection**:
  All 10 inter-subject duplicate clusters identified during dataset inspection are strictly contained inside the `Train` partition, guaranteeing **0 hash duplicate collisions** into `Validation` or `Test`.

---

## 5. Landmark Normalization

Raw pixel coordinates depend on camera resolution, user distance, and position in frame. The deterministic normalization transforms landmarks into body-relative coordinates:
1. **Origin Translation**: Origin $(0,0,0)$ placed at the mid-hip point:
   $$\mathbf{C}_{\text{hip}} = \frac{\mathbf{L}_{23} + \mathbf{L}_{24}}{2}$$
2. **Torso Scale Factor**: Torso length between mid-hip and mid-shoulder:
   $$s = \|\mathbf{S}_{\text{shoulder}} - \mathbf{C}_{\text{hip}}\|, \quad \mathbf{S}_{\text{shoulder}} = \frac{\mathbf{L}_{11} + \mathbf{L}_{12}}{2}$$
   *(Fallback: shoulder-to-shoulder width if torso is obscured; 1.0 if degenerate).*
3. **Normalized Coordinates**:
   $$\mathbf{L}'_i = \frac{\mathbf{L}_i - \mathbf{C}_{\text{hip}}}{s}$$

---

## 6. Feature Engineering (140 Total Dimensions)

| Group | Features | Count | Description |
| :--- | :--- | :--- | :--- |
| **Group A** | `norm_lm_0_x` ... `norm_lm_32_z` | 99 | Normalized 3D coordinates for all 33 body keypoints |
| **Group B** | `angle_left_knee`, `angle_right_knee`, `angle_left_hip`, `angle_right_hip`, `angle_left_elbow`, `angle_right_elbow`, `angle_left_shoulder`, `angle_right_shoulder`, `angle_left_ankle`, `angle_right_ankle`, `angle_trunk_inclination`, `angle_neck` | 12 | 3D joint angles computed with vector dot products and arccos in degrees |
| **Group C** | Ankle-to-hip, wrist-to-shoulder, wrist-to-hip, knee-to-hip, stance width, hand width, hip width, shoulder width | 12 | Anatomical distance ratios normalized by torso length |
| **Group D** | Landmark velocities ($\Delta \mathbf{L} / \Delta t$) and angular rates ($\Delta \theta / \Delta t$) | 17 | Dynamic movement velocities and joint inflection rates |

This feature separation enables training ablation comparisons between:
1. Landmark-only models
2. Engineered kinematic feature models
3. Spatio-temporal dynamic models

---

## 7. Output Dataset Artifacts

All outputs are saved to `ml/dataset/processed/`:

- `metadata/dataset_manifest.csv`: 294 rows of video-level metadata, durations, source FPS, extracted frame count, and processing status.
- `splits/splits.json`: Approved subject IDs and video counts per partition.
- `landmarks/`:
  - `{video_id}.parquet`: Frame-level raw and normalized landmarks per video.
  - `train_landmarks.parquet`, `val_landmarks.parquet`, `test_landmarks.parquet`: Aggregated split tables.
- `features/`:
  - `{video_id}.parquet`: Frame-level 140 engineered features per video.
  - `train_features.parquet`, `val_features.parquet`, `test_features.parquet`: Aggregated split feature tables.
- `reports/`:
  - `landmark_extraction_report.md`: Extraction statistics, detection rates, and leakage verification.
  - `visual_checks/`: Skeleton overlay preview images verifying keypoint alignment on squats and push-ups across front, side, and diagonal views.

---

## 8. How to Reproduce

Run the extraction pipeline:

```bash
# Using 4 parallel worker threads (adjust based on CPU cores)
python -m ml.preprocessing.extract_landmarks 4
```

To run only metadata verification and leakage checks:

```bash
python -m ml.preprocessing.metadata
```
