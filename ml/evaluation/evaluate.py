"""
Model evaluation entrypoint.
Loads test splits, runs inferences, and produces diagnostic reports.
"""

from typing import List, Dict, Any
from ml.evaluation.metrics import compute_classification_metrics
from ml.evaluation.confusion_matrix import build_confusion_matrix, print_confusion_matrix


def evaluate_model(model_artifact_path: str, test_data: List[Dict[str, Any]], classes: List[str]):
    print(f"[Evaluation] Evaluating model: {model_artifact_path}")
    # Placeholder for test set forward passes
    y_true = [0, 1, 2]
    y_pred = [0, 1, 2]
    metrics = compute_classification_metrics(y_true, y_pred, classes)
    matrix = build_confusion_matrix(y_true, y_pred, len(classes))
    print_confusion_matrix(matrix, classes)
    return metrics
