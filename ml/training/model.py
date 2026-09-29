"""
Model architectures for Layer 2 Exercise & Movement Classification.
Supports Lightweight MLP, 1D-CNN, and GRU based on dataset inspection.
"""

from typing import Dict, Any


def build_model(architecture: str, input_dim: int, num_classes: int, seq_len: int = 30) -> Dict[str, Any]:
    """
    Factory function returning model specifications.
    Actual PyTorch / TensorFlow modules will be compiled once dataset inspection is complete.
    """
    valid_architectures = ["mlp", "cnn1d", "gru", "lstm"]
    if architecture not in valid_architectures:
        raise ValueError(f"Unknown architecture: {architecture}. Supported: {valid_architectures}")

    model_spec = {
        "architecture": architecture,
        "input_dim": input_dim,
        "sequence_length": seq_len if architecture != "mlp" else 1,
        "num_classes": num_classes,
        "target_footprint": "< 2.5 MB (Mobile Optimized)",
    }

    if architecture == "mlp":
        model_spec["layers"] = [
            {"type": "Dense", "units": 64, "activation": "relu"},
            {"type": "Dropout", "rate": 0.2},
            {"type": "Dense", "units": 32, "activation": "relu"},
            {"type": "Dense", "units": num_classes, "activation": "softmax"}
        ]
    elif architecture == "cnn1d":
        model_spec["layers"] = [
            {"type": "Conv1D", "filters": 32, "kernel_size": 3, "activation": "relu"},
            {"type": "MaxPool1D", "pool_size": 2},
            {"type": "Conv1D", "filters": 64, "kernel_size": 3, "activation": "relu"},
            {"type": "GlobalAveragePooling1D"},
            {"type": "Dense", "units": num_classes, "activation": "softmax"}
        ]
    elif architecture in ["gru", "lstm"]:
        model_spec["layers"] = [
            {"type": architecture.upper(), "units": 48, "return_sequences": False},
            {"type": "Dropout", "rate": 0.2},
            {"type": "Dense", "units": 32, "activation": "relu"},
            {"type": "Dense", "units": num_classes, "activation": "softmax"}
        ]

    return model_spec
