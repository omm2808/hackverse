"""
Training pipeline orchestrator.
Executes training, validation tracking, checkpointing, and metric logging.
NOTE: Execution is triggered only after dataset inspection and approval.
"""

from ml.training.config import TrainingConfig
from ml.training.model import build_model


def run_training(config: TrainingConfig = TrainingConfig()):
    print("=" * 60)
    print(f"Fit Odyssey — Model Training Pipeline [{config.model_name}]")
    print(f"Version: {config.model_version} | Architecture: {config.model_architecture}")
    print("=" * 60)

    # 1. Build model spec
    model_spec = build_model(
        architecture=config.model_architecture,
        input_dim=config.input_feature_dim,
        num_classes=len(config.classes),
        seq_len=config.sequence_length
    )
    print(f"[Model Init] Spec initialized: {model_spec['architecture']} (Classes: {config.classes})")
    print(f"[Model Init] Target size: {model_spec['target_footprint']}")

    print("[Status] Training workspace initialized. Ready for dataset inspection.")


if __name__ == "__main__":
    run_training()
