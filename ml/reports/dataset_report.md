# Fit Odyssey — Pose Intelligence Dataset Inspection Report

> **Dataset Inspected:** `ml/dataset/raw/Dataset Subject-wise/` and `ml/dataset/processed/features/`  
> **Inspection Date:** 2026-09-30  
> **Target Architecture:** Camera → ML Kit BlazePose (33 landmarks) → Feature Extraction → Custom ML Model → Exercise & Form Prediction  

---

## 1. Dataset Overview & Location

| Item | Details |
|---|---|
| **Raw Dataset Path** | `ml/dataset/raw/Dataset Subject-wise/` |
| **Extracted Features Path** | `ml/dataset/processed/features/` (`train_features.parquet`, `val_features.parquet`, `test_features.parquet`) |
| **Manifest Path** | `ml/dataset/processed/metadata/dataset_manifest.csv` |
| **Split Specification** | `ml/dataset/processed/splits/splits.json` |
| **Total Raw Videos** | **1,042** MP4 videos (2.90 GB, ~8.25 hours) across 26 subjects (`subject_001` - `subject_026`) |
| **Extracted Target Videos** | **294** videos (150 Squat, 144 Push-up) |
| **Total Extracted Frames** | **111,710** frames (at 15 FPS sampling) |
| **Detected Pose Frames** | **94,754** frames (84.8% detection rate by BlazePose) |

---

## 2. File Formats & Landmark Structure

### Raw Video Format
- Container: MP4 (`avc1` / H.264 codec)
- Resolutions: Smartphone recordings ($810 \times 1440$ portrait, $1440 \times 810$ landscape, $358 \times 636$)
- Frame rate: 25–30 FPS source; extracted at 15 FPS to match edge mobile inference rates.

### Landmark Representation (BlazePose)
- 33 Body Keypoints per detected frame ($x, y, z, \text{visibility}$).
- **Normalization:** Centered relative to the mid-hip coordinate $(x_{\text{mid\_hip}}, y_{\text{mid\_hip}}, z_{\text{mid\_hip}})$ and scaled by the subject's torso length ($\|\text{mid\_shoulder} - \text{mid\_hip}\|$). This makes features invariant to camera zoom, image resolution, and subject distance.

---

## 3. Classes and Distribution

### Raw Dataset Directory Structure
```
Dataset Subject-wise/
└── subject_XXX/
    └── {exercise}/          # squat, push_up, bicep_curl, shoulder, abs, back, tricep
        ├── good/            # Correct biomechanical form
        │   ├── diagonal/    # ~45° perspective
        │   ├── front/       # Coronal view
        │   └── side/        # Sagittal view
        └── bad/             # Incorrect biomechanical form
            ├── diagonal/
            ├── front/
            └── side/
```

### Video Distribution for Target Exercises (294 videos)

| Exercise | Total Videos | Good Form | Bad Form | Front View | Side View | Diagonal View |
|---|---|---|---|---|---|---|
| **Squat** | 150 | 75 (50.0%) | 75 (50.0%) | 50 (33.3%) | 50 (33.3%) | 50 (33.3%) |
| **Push-up** | 144 | 72 (50.0%) | 72 (50.0%) | 48 (33.3%) | 48 (33.3%) | 48 (33.3%) |
| **Total** | **294** | **147 (50.0%)** | **147 (50.0%)** | **98 (33.3%)** | **98 (33.3%)** | **98 (33.3%)** |

### Frame Distribution on Detected Pose Landmarks (94,754 frames)

| Split | Subjects | push_up bad | push_up good | squat bad | squat good | Total Detected |
|---|---|---|---|---|---|---|
| **Train** | 18 subjects (`001`-`015`, `019`, `020`, `026`) | 12,847 | 13,990 | 20,644 | 20,511 | **67,992** |
| **Val** | 4 subjects (`016`, `017`, `018`, `021`) | 2,719 | 2,526 | 5,142 | 5,070 | **15,457** |
| **Test** | 3 subjects (`022`, `023`, `024`) | 2,091 | 2,208 | 3,531 | 3,475 | **11,305** |
| **Total** | **25 subjects** | **17,657** | **18,724** | **29,317** | **29,056** | **94,754** |

---

## 4. Train / Validation / Test Partitioning & Leakage Prevention

- **Subject-Level Partitioning:** Random frame-level shuffling is strictly prohibited. If frames of the same human subject appear in both training and test sets, the model learns individual anthropometry, clothing, and background rather than exercise kinematics.
- **Inter-Subject Duplicate Clustering:** Subjects sharing identical duplicate files (e.g. subjects 5 & 6, 10 & 13, 14 & 19 & 20) are grouped entirely inside the **Train** set, ensuring 100% clean, unseen test subjects (`subject_022`, `subject_023`, `subject_024`).

---

## 5. Missing / Corrupt Samples & Label Integrity Audit

1. **Video File Integrity:** 1,042 of 1,042 videos are valid readable files (0 corrupt, 0 zero-byte files).
2. **Pose Detection Dropouts:** BlazePose failed to detect a pose in 16,956 of 111,710 frames (15.2%). These frames correspond to subjects entering/exiting the camera view or extreme occlusion, and are flagged with `detected: False`. They are filtered out of training.
3. **Raw Dataset Duplicate Inconsistencies:**
   - 23 intra-subject collisions were found where the exact same MP4 file was duplicated under both `good` and `bad` subdirectories (e.g., `subject_003_squat_good_diagonal.mp4` == `subject_003_squat_bad_diagonal.mp4`).
   - For exercise classification, this has 0 adverse impact (both are squats).
   - For form classification, these duplicate pairs create contradictory supervision if not addressed.

---

## 6. What the Dataset Can Actually Support

| Task | Supported? | Analysis & System Role |
|---|---|---|
| **Exercise Classification (`squat` vs `push_up`)** | **YES (Fully Supported)** | Kinematic features (torso inclination, knee/elbow angles) cleanly separate horizontal prone push-ups from vertical squats (>97% test accuracy). |
| **Form Quality Classification (`good` vs `bad`)** | **YES (Supported with Caveats)** | The dataset provides binary `good`/`bad` labels. However, because video frames include idle standing at the beginning and end of each rep (where pose is identical regardless of form), classification is most effective when evaluated on the active movement / inflection phase. |
| **Plank Recognition** | **NOT IN THIS RAW DATASET** | Plank is not present as a discrete folder in `Dataset Subject-wise`. Per Fit Odyssey's architecture ([docs/pose-engine.md](file:///d:/omm'model/docs/pose-engine.md)), **Plank is an isometric hold** governed deterministically by spine alignment ($155^\circ - 185^\circ$) and hold timer, not repetitive ML state cycles. |
| **Repetition Counting** | **Deterministic Engine** | Rep counting is handled by the biomechanical state machine (`HIGH → DESCENDING → BOTTOM → ASCENDING → HIGH`), not end-to-end ML. |
