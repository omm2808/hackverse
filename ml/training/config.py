"""
ML Training Configuration.
Centralized hyperparameters, paths, and version metadata.
"""

from dataclasses import dataclass, field
from typing import List


@dataclass
class TrainingConfig:
    # Model Metadata
    model_name: str = "fit-odyssey-exercise-model"
    model_version: str = "0.1.0"
    dataset_version: str = "1.0.0"

    # Input/Output
    input_feature_dim: int = 16
    sequence_length: int = 30  # ~1-2 seconds at 15-30 FPS
    classes: List[str] = field(default_factory=lambda: ["squat", "pushup", "plank", "idle"])

    # Training Hyperparameters
    batch_size: int = 32
    learning_rate: float = 1e-3
    num_epochs: int = 50
    weight_decay: float = 1e-4

    # Architecture Options: "mlp", "cnn1d", "gru", "lstm"
    model_architecture: str = "mlp"

    # Paths
    dataset_dir: str = "ml/dataset"
    output_model_dir: str = "ml/models"
