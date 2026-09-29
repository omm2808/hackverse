# Fit Odyssey — Development Guide

## Prerequisites

- **JavaScript / TypeScript Runtime:** Node.js >= 20, pnpm >= 9
- **Database:** PostgreSQL >= 15
- **Mobile Development:** Expo Go / Android Studio / Xcode
- **Machine Learning (ML Workspace):** Python >= 3.10, virtual environment (`venv`)

---

## Monorepo Setup Commands

```bash
# Install all dependencies across monorepo
pnpm install

# Run strict type checking across all apps and packages
pnpm run type-check

# Run linter
pnpm run lint

# Build all apps and packages
pnpm run build
```

---

## Running Applications

```bash
# Start NestJS API (Port 3001)
pnpm --filter @fit-odyssey/api dev

# Start Next.js Web Command Center (Port 3000)
pnpm --filter @fit-odyssey/web dev

# Start Expo Mobile App (Port 8081)
pnpm --filter @fit-odyssey/mobile start
```

---

## Machine Learning Workspace (`ml/`)

The ML training workspace is an independent Python environment. It must not be mixed with `apps/mobile` or `apps/api`.

### Environment Setup
```bash
cd ml
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate

# Install ML requirements (Torch / TF / MediaPipe / Scikit-Learn)
pip install -r requirements.txt  # (Created when dataset inspection begins)
```

### ML Pipeline Workflow
```bash
# 1. Extract landmarks from video dataset
python -m ml.preprocessing.extract_landmarks

# 2. Run model training (subject-split leakage-free)
python -m ml.training.train

# 3. Evaluate model accuracy & confusion matrix
python -m ml.evaluation.evaluate

# 4. Export model with mandatory versioning metadata
python -m ml.export.export_model
```
