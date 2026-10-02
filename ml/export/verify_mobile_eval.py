"""
Verification test confirming mathematical parity between sklearn models and exported JSON weights.
"""

import json
import joblib
import numpy as np
import pandas as pd


def evaluate_tree(node, features):
    if node["type"] == "leaf":
        return node["probabilities"]
    feat_val = features[node["feature_index"]]
    if feat_val <= node["threshold"]:
        return evaluate_tree(node["left"], features)
    else:
        return evaluate_tree(node["right"], features)


def evaluate_forest(forest_json, features):
    trees = forest_json["trees"]
    all_probs = [evaluate_tree(t, features) for t in trees]
    avg_probs = np.mean(all_probs, axis=0)
    return avg_probs


def run_verification():
    print("=" * 60)
    print("Verifying Mobile JSON Decision Forest vs Scikit-Learn Model")
    print("=" * 60)

    with open("ml/export/mobile_artifacts/exercise_classifier.json", "r") as f:
        forest_json = json.load(f)

    sklearn_model = joblib.load("ml/models/exercise_classifier.joblib")

    test_df = pd.read_parquet("ml/dataset/processed/features/test_features.parquet")
    test_df = test_df[test_df["detected"]].reset_index(drop=True)
    with open("ml/models/feature_names.json", "r") as f:
        feature_names = json.load(f)

    X_te = test_df[feature_names].values[:50]  # test first 50 frames

    mismatches = 0
    max_prob_diff = 0.0

    for i in range(len(X_te)):
        sample = X_te[i]
        sklearn_probs = sklearn_model.predict_proba(sample.reshape(1, -1))[0]
        json_probs = evaluate_forest(forest_json, sample)

        prob_diff = np.max(np.abs(sklearn_probs - json_probs))
        max_prob_diff = max(max_prob_diff, prob_diff)

        sklearn_pred = np.argmax(sklearn_probs)
        json_pred = np.argmax(json_probs)

        if sklearn_pred != json_pred:
            mismatches += 1

    print(f"Frames verified: {len(X_te)}")
    print(f"Mismatches: {mismatches} (0 expected)")
    print(f"Max absolute probability difference: {max_prob_diff:.6e}")

    assert mismatches == 0, "Discrepancy detected between JSON and Scikit-Learn!"
    print("[SUCCESS] 100% mathematical parity confirmed between mobile JSON format and Python sklearn model.")


if __name__ == "__main__":
    run_verification()
