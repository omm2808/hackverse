# Fit Odyssey — Machine Learning Workspace

This workspace houses the offline training, evaluation, and export pipeline for Fit Odyssey's **Custom Exercise AI Model (Layer 2)**.

## Architecture Role

```
   ┌──────────────────────────────────────────────────────────────────┐
   │                       ON-DEVICE INFERENCE                        │
   │                                                                  │
   │  Camera Frame                                                    │
   │       │                                                          │
   │       ▼                                                          │
   │  [Pretrained MediaPipe Pose] ── Layer 1: Edge Pose Estimation    │
   │       │                                                          │
   │       ▼                                                          │
   │  33 Normalized Landmarks                                         │
   │       │                                                          │
   │       ▼                                                          │
   │  [Feature Extraction / Normalization]                            │
   │       │                                                          │
   │       ▼                                                          │
   │  [Custom Trained Model]      ── Layer 2: Exercise/State Model    │
   │       │                                                          │
   │       ▼                                                          │
   │  Exercise / State Probability                                    │
   │       │                                                          │
   │       ▼                                                          │
   │  [Deterministic State Machine Engine]                            │
   │       │                                                          │
   │       ▼                                                          │
   │  Reps, Hold Timing & Real-time Form Feedback                     │
   └──────────────────────────────────────────────────────────────────┘
```

## Directory Structure

- `dataset/`: Training dataset storage, format specifications, and split manifests.
- `preprocessing/`: Landmark extraction, bounding-box/hip normalization, temporal feature engineering.
- `training/`: Dataset loaders, model definitions (MLP, 1D-CNN, GRU/LSTM), and training loop.
- `evaluation/`: Classification metrics, confusion matrix plotting, per-class F1-scores.
- `inference/`: Python predictor testbed mirroring on-device feature extraction.
- `export/`: Model serialization (TFLite / ONNX / CoreML / JSON weights) with mandatory embedded metadata.
- `models/`: Exported model binaries and training artifacts.
- `notebooks/`: Exploratory data analysis (EDA) and prototype notebooks.

## Key Rules
1. **No Data Leakage**: Splits must be grouped by subject / session, never random frame-level shuffling.
2. **Deterministic Downstream Engine**: The ML model classifies movement/state; the state machine counts reps and calculates hold durations.
3. **Model Versioning**: All exported models include strict metadata (dataset version, input shape, classes, author, metrics).
