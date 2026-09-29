"""
Confusion matrix generation and plotting utilities.
"""

from typing import List, Dict


def build_confusion_matrix(y_true: List[int], y_pred: List[int], num_classes: int) -> List[List[int]]:
    matrix = [[0] * num_classes for _ in range(num_classes)]
    for yt, yp in zip(y_true, y_pred):
        if 0 <= yt < num_classes and 0 <= yp < num_classes:
            matrix[yt][yp] += 1
    return matrix


def print_confusion_matrix(matrix: List[List[int]], class_names: List[str]):
    print("\n--- Confusion Matrix ---")
    header = "True \\ Pred\t" + "\t".join(class_names)
    print(header)
    for idx, row in enumerate(matrix):
        cname = class_names[idx] if idx < len(class_names) else str(idx)
        print(f"{cname}\t\t" + "\t".join(str(val) for val in row))
