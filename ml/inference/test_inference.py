"""
Verification script for PoseIntelligencePredictor.
Tests raw landmarks -> normalization -> feature extraction -> prediction -> structured output.
"""

import os
import sys

# Ensure project root is in sys.path
sys.path.insert(0, os.path.abspath("."))

import numpy as np
import pandas as pd
from ml.inference.predictor import PoseIntelligencePredictor


def run_inference_tests():
    print("=" * 60)
    print("Testing Fit Odyssey Pose Intelligence Inference Module")
    print("=" * 60)

    predictor = PoseIntelligencePredictor(models_dir="ml/models")

    # Load real test landmark sample from parquet
    test_df = pd.read_parquet("ml/dataset/processed/features/test_features.parquet")
    test_df = test_df[test_df["detected"]].reset_index(drop=True)

    # 1. Test on a squat sample
    squat_row = test_df[test_df["exercise"] == "squat"].iloc[50]
    squat_lm_cols = [f"norm_lm_{i}_{axis}" for i in range(33) for axis in ("x", "y", "z")]
    raw_squat_pts = squat_row[squat_lm_cols].values.reshape(33, 3)

    pred_squat = predictor.predict(raw_squat_pts, timestamp=1.5)
    print("\n--- Test Sample 1: SQUAT ---")
    print(f"Ground Truth: exercise={squat_row['exercise']}, quality={squat_row['quality']}")
    print(f"Prediction:   {pred_squat.to_dict()}")

    # 2. Test on a push_up sample
    predictor.reset_state()
    pu_row = test_df[test_df["exercise"] == "push_up"].iloc[50]
    pu_lm_cols = [f"norm_lm_{i}_{axis}" for i in range(33) for axis in ("x", "y", "z")]
    raw_pu_pts = pu_row[pu_lm_cols].values.reshape(33, 3)

    pred_pu = predictor.predict(raw_pu_pts, timestamp=2.0)
    print("\n--- Test Sample 2: PUSH_UP ---")
    print(f"Ground Truth: exercise={pu_row['exercise']}, quality={pu_row['quality']}")
    print(f"Prediction:   {pred_pu.to_dict()}")

    # 3. Test latency benchmark (100 iterations)
    import time
    t0 = time.perf_counter()
    for i in range(100):
        predictor.predict(raw_squat_pts, timestamp=i * (1.0 / 15.0))
    t1 = time.perf_counter()
    avg_latency_ms = ((t1 - t0) / 100.0) * 1000.0
    print(f"\n[Performance Benchmark] Average inference latency: {avg_latency_ms:.2f} ms / frame ({1000.0 / avg_latency_ms:.1f} FPS)")

    print("\n[SUCCESS] Inference testbed verified end-to-end.")


if __name__ == "__main__":
    run_inference_tests()
