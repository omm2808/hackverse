"""
Fit Odyssey — Complete ML Training and Evaluation Pipeline.

Trains and evaluates:
1. Primary Exercise Classifier (squat vs push_up)
2. Specialized Squat Form Classifier (good vs bad)
3. Specialized Push-up Form Classifier (good vs bad)
4. Unified 4-Class Classifier (squat_good, squat_bad, push_up_good, push_up_bad)

Saves trained model artifacts to ml/models/ and generates evaluation metrics.
"""

import os
import json
import joblib
import numpy as np
import pandas as pd
from typing import Dict, Any, List

from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report
)

os.environ["LOKY_MAX_CPU_COUNT"] = "4"


def load_dataset_splits(base_dir: str = "ml/dataset/processed/features"):
    """
    Loads parquet splits and filters to detected pose frames.
    """
    train_path = os.path.join(base_dir, "train_features.parquet")
    val_path = os.path.join(base_dir, "val_features.parquet")
    test_path = os.path.join(base_dir, "test_features.parquet")

    train_df = pd.read_parquet(train_path)
    val_df = pd.read_parquet(val_path)
    test_df = pd.read_parquet(test_path)

    # Filter only frames where pose was successfully detected
    train_df = train_df[train_df["detected"]].reset_index(drop=True)
    val_df = val_df[val_df["detected"]].reset_index(drop=True)
    test_df = test_df[test_df["detected"]].reset_index(drop=True)

    feature_cols = [
        c for c in train_df.columns
        if c.startswith(("norm_lm_", "angle_", "dist_", "vel_", "d_angle_"))
    ]

    print(f"[Dataset] Train frames: {len(train_df):,}")
    print(f"[Dataset] Val frames:   {len(val_df):,}")
    print(f"[Dataset] Test frames:  {len(test_df):,}")
    print(f"[Dataset] Feature dim:  {len(feature_cols)}")

    return train_df, val_df, test_df, feature_cols


def evaluate_classifier(name: str, model: Any, X_tr, y_tr, X_val, y_val, X_te, y_te, labels: List[str]) -> Dict[str, Any]:
    """
    Computes accuracy, precision, recall, f1, and confusion matrix across splits.
    """
    preds_tr = model.predict(X_tr)
    preds_val = model.predict(X_val)
    preds_te = model.predict(X_te)

    tr_acc = float(accuracy_score(y_tr, preds_tr))
    val_acc = float(accuracy_score(y_val, preds_val))
    te_acc = float(accuracy_score(y_te, preds_te))

    is_binary = len(labels) == 2
    avg_mode = "binary" if is_binary else "weighted"
    pos_label = labels[1] if is_binary else None

    metric_kwargs = {"pos_label": pos_label} if is_binary else {"average": "weighted"}

    te_prec = float(precision_score(y_te, preds_te, **metric_kwargs))
    te_rec = float(recall_score(y_te, preds_te, **metric_kwargs))
    te_f1 = float(f1_score(y_te, preds_te, **metric_kwargs))

    cm = confusion_matrix(y_te, preds_te, labels=labels).tolist()
    clf_rep = classification_report(y_te, preds_te, labels=labels, output_dict=True)

    print(f"--- {name} ---")
    print(f"  Train Acc: {tr_acc:.4f} | Val Acc: {val_acc:.4f} | Test Acc: {te_acc:.4f}")
    print(f"  Test Precision: {te_prec:.4f} | Recall: {te_rec:.4f} | F1: {te_f1:.4f}")
    print(f"  Confusion Matrix (labels={labels}):\n  {cm}")

    return {
        "name": name,
        "labels": labels,
        "train_accuracy": tr_acc,
        "val_accuracy": val_acc,
        "test_accuracy": te_acc,
        "test_precision": te_prec,
        "test_recall": te_rec,
        "test_f1": te_f1,
        "confusion_matrix": cm,
        "classification_report": clf_rep,
    }


def run_pipeline():
    output_model_dir = "ml/models"
    os.makedirs(output_model_dir, exist_ok=True)

    train_df, val_df, test_df, feature_cols = load_dataset_splits()

    X_tr = train_df[feature_cols].values
    X_val = val_df[feature_cols].values
    X_te = test_df[feature_cols].values

    results = {}

    # ---------------------------------------------------------
    # 1. Primary Exercise Classifier (squat vs push_up)
    # ---------------------------------------------------------
    print("\n" + "=" * 60)
    print("1. TRAINING EXERCISE CLASSIFIER")
    print("=" * 60)
    y_tr_ex = train_df["exercise"].values
    y_val_ex = val_df["exercise"].values
    y_te_ex = test_df["exercise"].values
    ex_labels = ["push_up", "squat"]

    rf_exercise = RandomForestClassifier(
        n_estimators=50,
        max_depth=10,
        random_state=42,
        n_jobs=2
    )
    rf_exercise.fit(X_tr, y_tr_ex)

    results["exercise_classifier"] = evaluate_classifier(
        "RandomForest Exercise Classifier",
        rf_exercise,
        X_tr, y_tr_ex,
        X_val, y_val_ex,
        X_te, y_te_ex,
        labels=ex_labels
    )
    joblib.dump(rf_exercise, os.path.join(output_model_dir, "exercise_classifier.joblib"))

    # ---------------------------------------------------------
    # 2. Specialized Squat Form Classifier
    # ---------------------------------------------------------
    print("\n" + "=" * 60)
    print("2. TRAINING SQUAT FORM CLASSIFIER")
    print("=" * 60)
    sq_tr = train_df[train_df["exercise"] == "squat"]
    sq_val = val_df[val_df["exercise"] == "squat"]
    sq_te = test_df[test_df["exercise"] == "squat"]

    X_tr_sq, y_tr_sq = sq_tr[feature_cols].values, sq_tr["quality"].values
    X_val_sq, y_val_sq = sq_val[feature_cols].values, sq_val["quality"].values
    X_te_sq, y_te_sq = sq_te[feature_cols].values, sq_te["quality"].values
    form_labels = ["bad", "good"]

    rf_squat_form = RandomForestClassifier(
        n_estimators=50,
        max_depth=10,
        random_state=42,
        n_jobs=2
    )
    rf_squat_form.fit(X_tr_sq, y_tr_sq)

    results["squat_form_classifier"] = evaluate_classifier(
        "RandomForest Squat Form Classifier",
        rf_squat_form,
        X_tr_sq, y_tr_sq,
        X_val_sq, y_val_sq,
        X_te_sq, y_te_sq,
        labels=form_labels
    )
    joblib.dump(rf_squat_form, os.path.join(output_model_dir, "squat_form_classifier.joblib"))

    # ---------------------------------------------------------
    # 3. Specialized Push-up Form Classifier
    # ---------------------------------------------------------
    print("\n" + "=" * 60)
    print("3. TRAINING PUSH-UP FORM CLASSIFIER")
    print("=" * 60)
    pu_tr = train_df[train_df["exercise"] == "push_up"]
    pu_val = val_df[val_df["exercise"] == "push_up"]
    pu_te = test_df[test_df["exercise"] == "push_up"]

    X_tr_pu, y_tr_pu = pu_tr[feature_cols].values, pu_tr["quality"].values
    X_val_pu, y_val_pu = pu_val[feature_cols].values, pu_val["quality"].values
    X_te_pu, y_te_pu = pu_te[feature_cols].values, pu_te["quality"].values

    rf_pu_form = RandomForestClassifier(
        n_estimators=50,
        max_depth=10,
        random_state=42,
        n_jobs=2
    )
    rf_pu_form.fit(X_tr_pu, y_tr_pu)

    results["pushup_form_classifier"] = evaluate_classifier(
        "RandomForest Push-up Form Classifier",
        rf_pu_form,
        X_tr_pu, y_tr_pu,
        X_val_pu, y_val_pu,
        X_te_pu, y_te_pu,
        labels=form_labels
    )
    joblib.dump(rf_pu_form, os.path.join(output_model_dir, "pushup_form_classifier.joblib"))

    # ---------------------------------------------------------
    # 4. Unified 4-Class Joint Classifier
    # ---------------------------------------------------------
    print("\n" + "=" * 60)
    print("4. TRAINING UNIFIED 4-CLASS CLASSIFIER")
    print("=" * 60)
    y_tr_joint = (train_df["exercise"] + "_" + train_df["quality"]).values
    y_val_joint = (val_df["exercise"] + "_" + val_df["quality"]).values
    y_te_joint = (test_df["exercise"] + "_" + test_df["quality"]).values
    joint_labels = ["push_up_bad", "push_up_good", "squat_bad", "squat_good"]

    rf_joint = RandomForestClassifier(
        n_estimators=50,
        max_depth=12,
        random_state=42,
        n_jobs=2
    )
    rf_joint.fit(X_tr, y_tr_joint)

    results["joint_classifier"] = evaluate_classifier(
        "RandomForest 4-Class Joint Classifier",
        rf_joint,
        X_tr, y_tr_joint,
        X_val, y_val_joint,
        X_te, y_te_joint,
        labels=joint_labels
    )
    joblib.dump(rf_joint, os.path.join(output_model_dir, "joint_classifier.joblib"))

    # Save feature names
    with open(os.path.join(output_model_dir, "feature_names.json"), "w") as f:
        json.dump(feature_cols, f, indent=2)

    # Save metric evaluation results
    with open(os.path.join(output_model_dir, "evaluation_metrics.json"), "w") as f:
        json.dump(results, f, indent=2)

    print("\n[Complete] All models trained and saved to ml/models/")
    return results


if __name__ == "__main__":
    run_pipeline()
