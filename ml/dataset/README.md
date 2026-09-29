# Fit Odyssey — Exercise Dataset Directory

Place raw and processed dataset files in this directory.

## Expected Structure

Datasets can be structured either as video recordings or pre-extracted landmark CSV/Parquet files:

```
dataset/
├── raw/
│   ├── squats/
│   │   ├── subject_01_session_01.mp4
│   │   └── ...
│   ├── pushups/
│   │   └── ...
│   └── planks/
│       └── ...
├── processed/
│   ├── landmarks.parquet
│   └── features.parquet
└── splits/
    ├── train_subjects.txt
    ├── val_subjects.txt
    └── test_subjects.txt
```

## Anti-Leakage Policy
To guarantee model generalization on real users:
- **Never split frames randomly.**
- Videos or frames belonging to `subject_01` must be strictly confined to either `train`, `val`, or `test`.
- GroupKFold or Subject-aware Stratified splits must be used.
