# Fit Odyssey — Comprehensive Dataset Inspection Report

> **Dataset Inspected:** `ml/dataset/raw/Dataset Subject-wise/`  
> **Auxiliary Dataset:** `ml/dataset/raw/fitness_poses_csvs_out_full_list.csv`  
> **Inspection Date:** 2026-09-29  
> **Inspector:** Lead AI & Computer Vision Architect  
> **Status:** Inspection Complete (Zero Modifications Made to Raw Data)

---

## 1. Executive Summary

A comprehensive, non-destructive recursive audit of `ml/dataset/raw/Dataset Subject-wise/` was conducted. The dataset comprises **1,042 high-definition MP4 videos** spanning **26 human subjects**, totaling **2.90 GB (2,971.95 MB)** and **8.25 hours (495.20 minutes)** of exercise footage.

### Key Inspection Findings:
1. **Physical Exercises Available:** 7 distinct exercise categories are present: **`squat`**, **`push_up`**, **`bicep_curl`**, **`shoulder`**, **`abs`**, **`back`**, and **`tricep`**.
2. **Target MVP Exercise Audit:**
   - **Squat:** **PRESENT** (150 videos across 25 subjects).
   - **Push-up:** **PRESENT** (144 videos across 24 subjects).
   - **Plank:** **NOT PRESENT** as a discrete directory in this dataset (ab exercises in this dataset feature dynamic movements rather than static isometric holds).
3. **Quality & View Balance:** The dataset exhibits near-perfect symmetry:
   - **Quality Labels:** Exactly 50.0% `good` (521 videos) and 50.0% `bad` (521 videos).
   - **Camera Angles:** Balanced across 3 camera perspectives: `diagonal` (348), `front` (348), and `side` (346).
4. **Data Integrity & Duplicate Detection:**
   - Zero missing or 0-byte files (100% valid MP4 container headers).
   - **33 duplicate file clusters** (34 redundant files) were discovered: 23 intra-subject duplicates (identical video copied into both `good` and `bad`) and 10 inter-subject duplicates (identical video shared between subjects, e.g., subjects 5 & 6, 15 & 26).
5. **Leakage-Safe Subject Partitioning:** A dedicated grouping strategy is formulated so that all interconnected subjects are isolated into the Training split, guaranteeing **zero data leakage** into Validation and Test sets.

---

## 2. Directory Structure & Naming Conventions

### Directory Hierarchy:
```
ml/dataset/raw/Dataset Subject-wise/
└── subject_XXX/                      # 26 Subjects (subject_001 to subject_026)
    └── {exercise}/                   # 7 Categories (abs, back, bicep_curl, push_up, shoulder, squat, tricep)
        ├── good/                     # Execution Quality: Correct biomechanics
        │   ├── diagonal/             # Camera Angle: ~45° perspective
        │   ├── front/                # Camera Angle: Coronal / front perspective
        │   └── side/                 # Camera Angle: Sagittal / side perspective
        └── bad/                      # Execution Quality: Form defect
            ├── diagonal/
            ├── front/
            └── side/
```

### File Naming Convention:
Filenames strictly adhere to a deterministic 4-part descriptor:
$$\text{\{subject\_id\}}\_\text{\{exercise\}}\_\text{\{quality\}}\_\text{\{view\}}\text{.mp4}$$
*Examples:*
- `subject_001_squat_good_front.mp4`
- `subject_001_push_up_bad_side.mp4`
- `subject_012_abs_good_diagonal.mp4`

---

## 3. Dataset Statistics

| Metric | Measured Value |
|---|---|
| **Total Subjects** | **26** (`subject_001` through `subject_026`) |
| **Total Video Files** | **1,042** MP4 files |
| **Total Disk Footprint** | **2,971.95 MB (2.90 GB)** |
| **Average Video Size** | **2.85 MB** (Min: 0.09 MB, Max: 11.03 MB) |
| **Total Video Duration** | **495.20 minutes (~8.25 hours)** |
| **Average Video Duration** | **28.51 seconds** (Min: 1.40s, Max: 46.40s) |
| **Container & Codec** | MP4 container (`avc1` / H.264 video streams) |
| **Video Resolutions** | Variable smartphone recordings: $810 \times 1440$ (portrait), $1440 \times 810$ (landscape), $358 \times 636$ |
| **Unreadable / Corrupt Videos** | **0** (All 1,042 videos successfully verified) |
| **Zero-Byte Files** | **0** |

---

## 4. Exercise Distribution

| Exercise Category | Video Count | Percentage | Subjects Present | Form Balance (`good` / `bad`) | View Balance (`diag` / `front` / `side`) |
|---|---|---|---|---|---|
| **`tricep`** | 154 | 14.8% | 26 / 26 | 77 good / 77 bad | 52 diag / 52 front / 50 side |
| **`abs`** | 150 | 14.4% | 25 / 26 | 75 good / 75 bad | 50 diag / 50 front / 50 side |
| **`bicep_curl`** | 150 | 14.4% | 25 / 26 | 75 good / 75 bad | 50 diag / 50 front / 50 side |
| **`shoulder`** | 150 | 14.4% | 25 / 26 | 75 good / 75 bad | 50 diag / 50 front / 50 side |
| **`squat`** | **150** | **14.4%** | **25 / 26** | **75 good / 75 bad** | **50 diag / 50 front / 50 side** |
| **`back`** | 144 | 13.8% | 24 / 26 | 72 good / 72 bad | 48 diag / 48 front / 48 side |
| **`push_up`** | **144** | **13.8%** | **24 / 26** | **72 good / 72 bad** | **48 diag / 48 front / 48 side** |
| **Total** | **1,042** | **100.0%** | — | **521 good / 521 bad** | **348 diag / 348 front / 346 side** |

---

## 5. Quality & View Distribution

### Form Quality Distribution
- **Good Form (`good`):** 521 videos (**50.00%**)
- **Defective Form (`bad`):** 521 videos (**50.00%**)
- *Assessment:* Perfectly balanced 1:1 prior distribution across every individual exercise class.

### Camera View Perspective Distribution
- **Diagonal Perspective (`diagonal`):** 348 videos (**33.40%**)
- **Frontal Perspective (`front`):** 348 videos (**33.40%**)
- **Lateral / Side Perspective (`side`):** 346 videos (**33.20%**)
- *Assessment:* Exceptionally balanced 3-view dataset. Crucial for training camera-invariant classifiers on edge mobile devices.

---

## 6. Subject Distribution & Cross-Condition Presence

```
   ┌────────────────────────────────────────────────────────┐
   │ 24 Complete Subjects (subject_001 to subject_024)      │
   │ 42 videos each (7 exercises × 2 qualities × 3 views)   │ ──▶ 1,008 videos
   └────────────────────────────────────────────────────────┘
   ┌────────────────────────────────────────────────────────┐
   │ 1 Partial Subject (subject_026)                        │
   │ 30 videos (5 exercises × 2 qualities × 3 views)        │ ──▶    30 videos
   │ (Missing: back, push_up)                               │
   └────────────────────────────────────────────────────────┘
   ┌────────────────────────────────────────────────────────┐
   │ 1 Sparse Subject (subject_025)                         │
   │ 4 videos (tricep: 2 qualities × 2 views)               │ ──▶     4 videos
   └────────────────────────────────────────────────────────┘
                                                    TOTAL   ──▶ 1,042 videos
```

### Critical Finding: Multi-Condition Subject Re-identification
- **Yes**, the exact same human subject appears across multiple exercises, quality modes, and viewing angles.
- In subjects 1 through 24, each participant was recorded performing all 7 exercises under both good and bad technique, across front, side, and diagonal perspectives.
- **Architectural Consequence:** Video-level random splitting is strictly prohibited. If video $A$ of `subject_001` is placed in Train and video $B$ of `subject_001` is placed in Test, the model will identify the subject's clothing, physical build, and background rather than learning exercise biomechanics.

---

## 7. Data Quality & Duplicate File Audit

A cryptographic MD5 hash was computed across all 1,042 video streams.

- **Unique Video Streams:** 1,008 unique files.
- **Duplicate Instances:** 34 redundant copies clustered in 33 collision sets.

### Categorization of Duplicates:

#### A. Intra-Subject Collisions (23 clusters)
The exact same video file was duplicated into both `good` and `bad` subfolders for the same subject.
- *Examples:*
  - `subject_003/squat/bad/diagonal` $\equiv$ `subject_003/squat/good/diagonal`
  - `subject_019/push_up/bad/side` $\equiv$ `subject_019/push_up/good/side`
  - `subject_023/squat/bad/side` $\equiv$ `subject_023/squat/good/side`
- *Impact on Model:* For **Exercise Classification (Layer 2)**, this is completely benign (both files are genuine squats). However, for **Form Quality Scoring**, these duplicates represent conflicting labels and must be filtered or handled during form-correction training.

#### B. Inter-Subject Collisions (10 clusters)
Identical video files appear under different subject IDs:
- `subject_005` and `subject_006` (shared `squat` and `shoulder` files)
- `subject_010` and `subject_013` (shared `push_up` file)
- `subject_014` and `subject_020` (shared `push_up` file)
- `subject_019` and `subject_020` (shared `back` file)
- `subject_015` and `subject_026` (shared `bicep_curl` and `squat` files)

---

## 8. Data Leakage Analysis & Recommended Partitioning

To maintain 100% mathematical independence between training, validation, and test splits:
1. **Split at the Subject Level:** All videos of a subject stay strictly inside one partition.
2. **Cluster Inter-Subject Duplicates into Train:** Subjects that share identical files must be co-located in the same partition (`Train`) to prevent leakage into `Validation` or `Test`.

### Subject Inter-dependency Groups:
- **Group A (Coupled):** `{subject_005, subject_006}`
- **Group B (Coupled):** `{subject_010, subject_013}`
- **Group C (Coupled):** `{subject_014, subject_019, subject_020}`
- **Group D (Coupled):** `{subject_015, subject_026}`

### Recommended Subject-Level Split:

```
┌────────────────────────────────────────────────────────────────────────┐
│ TRAIN SET: 18 Subjects (744 Videos ~71.4% of total dataset)            │
│ Includes all coupled subjects + 9 clean subjects                       │
│ Subjects: 001, 002, 003, 004, 005, 006, 007, 008, 009,                │
│           010, 011, 012, 013, 014, 015, 019, 020, 026                 │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ VALIDATION SET: 4 Subjects (168 Videos ~16.1% of total dataset)        │
│ Completely independent clean subjects (4 × 42 videos)                  │
│ Subjects: 016, 017, 018, 021                                          │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TEST SET: 4 Subjects (130 Videos ~12.5% of total dataset)              │
│ Completely independent clean subjects (3 × 42 + 4 videos)              │
│ Subjects: 022, 023, 024, 025                                          │
└────────────────────────────────────────────────────────────────────────┘
```

**Guaranteed Result:** Zero video overlap, zero subject overlap, zero background leakage between splits.

---

## 9. Target MVP Exercise Availability (Squat / Push-up / Plank)

| Exercise | Status in Dataset | Sample Count | Feasibility Assessment |
|---|---|---|---|
| **Squat** | **CONFIRMED AVAILABLE** | **150 videos** (75 good, 75 bad) | **Ready for extraction & training.** Exceptional quality across 25 subjects with 3 camera perspectives. |
| **Push-up** | **CONFIRMED AVAILABLE** | **144 videos** (72 good, 72 bad) | **Ready for extraction & training.** Rich lateral and diagonal coverage across 24 subjects. |
| **Plank** | **NOT AVAILABLE DIRECTLY** | **0 explicit videos** | **Alternative Architectural Strategy (Detailed Below)** |

### Handling the Plank Requirement:
1. `Dataset Subject-wise` contains dynamic core exercises under `abs` (150 videos) rather than static isometric holds.
2. In our system architecture ([docs/pose-engine.md](file:///d:/omm'model/docs/pose-engine.md)), **Plank tracking is governed by isometric hold timing and spine angle verification** ($\approx 155^\circ - 185^\circ$), not dynamic repetition cycles.
3. Therefore:
   - For **Squat** and **Push-up**: Train the Custom Model (Layer 2) on the 294 annotated videos from this dataset.
   - For **Plank**: The deterministic `PlankAnalyzer` in `packages/pose-engine` already handles isometric holds and spine curvature with zero latency. Downstream, isometric plank samples can be augmented from push-up starting postures (the `PLANK_HIGH` state) which are abundantly present in the 144 push-up videos.

---

## 10. Auxiliary CSV Dataset Analysis

- **File:** `ml/dataset/raw/fitness_poses_csvs_out_full_list.csv`
- **Total Records:** 1,424 pre-extracted landmark vectors across 101 columns (image identifier, pose class label, and 99 spatial coordinates = 33 keypoints $\times$ 3D coordinates).
- **Classes Present:**
  - `lateral_raises_down` (135), `lateral_raises_up` (126)
  - `knee_raises_up` (125), `knee_raises_down` (117)
  - `shoulder_press_down` (119), `shoulder_press_up` (106)
  - `shoulder_flexion_up` (114)
  - `leg_raises_up` (106), `leg_raises_down` (100)
  - `lateral_leg_raises_down` (99), `lateral_leg_raises_up` (89)
  - `glute_bridge_down` (96), `glute_bridge_up` (92)
- **Role:** Excellent benchmark dataset for validating landmark feature normalization and state classification pipelines.

---

## 11. Practicality of Pose Landmark Extraction

- **Total Duration to Process:** 495.2 minutes ($\approx 29,712$ seconds).
- **Target Frame Sampling:** Extracting at 15 FPS (matching mobile camera inference rates) yields:
  $$29,712 \text{ seconds} \times 15 \text{ FPS} \approx 445,680 \text{ frames}$$
- **Processing Throughput:**
  - MediaPipe Pose Landmarker on CPU processes at ~40–60 FPS.
  - Multi-core batch extraction (e.g. 6 worker threads) achieves an effective throughput of ~250–300 FPS.
  - **Estimated Extraction Duration:** $\approx 25 - 35 \text{ minutes}$ for the entire 1,042 video repository.
- **Estimated Extracted Dataset Size:**
  - 445,680 frames $\times$ 33 keypoints $\times$ 4 floats $\times$ 4 bytes $\approx 235 \text{ MB}$ uncompressed ($< 70 \text{ MB}$ compressed in Parquet/NPZ format).
- **Conclusion:** Batch offline landmark extraction is **eminently practical, lightweight, and fast**.

---

## 12. Recommended Model Architecture

Based on dataset inspection (short 15–40s videos with continuous temporal rep cycles):

1. **Architecture: 1D Temporal CNN (or Lightweight 2-layer MLP)**
   - Input: Sliding window of 15–30 frames (1–2 seconds) $\times$ 16 biomechanical joint features (knees, hips, elbows, shoulders angles and vertical offsets).
   - Footprint: $< 50,000$ parameters ($< 250 \text{ KB}$ binary size).
   - Inference latency: $< 0.5 \text{ ms}$ on mobile device CPU/NPU.
2. **Output Classes:**
   - Primary exercise classifier: `squat`, `push_up`, `bicep_curl`, `shoulder`, `abs`, `back`, `tricep`, `idle`.
   - Movement sub-state: `descending`, `bottom`, `ascending`, `standing`.

---

## 13. Recommended Next ML Preprocessing Steps

1. **Step 1 — Virtual Environment & Extraction Tools:**
   Install extraction dependencies (`mediapipe`, `opencv-python`, `pandas`, `pyarrow`) inside `ml/venv`.
2. **Step 2 — Manifest Generation (`splits.json`):**
   Serialize the leakage-safe subject-level train/validation/test split into `ml/dataset/splits.json`.
3. **Step 3 — Batch Landmark Extraction:**
   Run `ml/preprocessing/extract_landmarks.py` on the 1,042 videos at 15 FPS, outputting normalized coordinates to `ml/dataset/processed/landmarks.parquet`.
4. **Step 4 — Duplicate Label Filtering:**
   Filter out conflicting intra-subject duplicate videos before training form-quality heads.
