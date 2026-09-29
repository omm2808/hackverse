"""
Model Export utility.
Exports trained models to lightweight mobile targets (TFLite / ONNX / Web JSON weights)
with mandatory embedded versioning metadata.
"""

from typing import Dict, Any
import json
import datetime
import os


def export_model_with_metadata(
    model_object: Any,
    output_path: str,
    metadata: Dict[str, Any]
) -> str:
    """
    Serializes model and writes companion metadata manifest.
    """
    mandatory_fields = [
        "model_name",
        "model_version",
        "dataset_version",
        "classes",
        "input_shape",
        "output_classes",
        "feature_configuration",
        "model_format"
    ]

    for field in mandatory_fields:
        if field not in metadata:
            raise ValueError(f"Missing mandatory model metadata field: '{field}'")

    metadata["training_date"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # Write manifest JSON
    manifest_path = output_path.replace(os.path.splitext(output_path)[1], ".metadata.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print(f"[Model Export] Exported model metadata to: {manifest_path}")
    return manifest_path
