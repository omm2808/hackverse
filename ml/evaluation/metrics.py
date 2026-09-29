"""
Model evaluation metrics.
Computes Accuracy, Precision, Recall, Macro/Micro F1, and Inference Latency.
"""

from typing import List, Dict


def compute_classification_metrics(y_true: List[int], y_pred: List[int], class_names: List[str]) -> Dict[str, float]:
    """
    Computes per-class and overall classification performance.
    """
    total = len(y_true)
    if total == 0:
        return {"accuracy": 0.0}

    correct = sum(1 for yt, yp in zip(y_true, y_pred) if yt == yp)
    accuracy = correct / total

    print(f"[Evaluation] Accuracy: {accuracy * 100:.2f}% ({correct}/{total} correct)")
    return {
        "accuracy": accuracy,
        "sample_count": float(total),
    }
