"""
Inference Predictor module.
Mirrors on-device pre-processing and model inference interface.
"""

from typing import List, Dict, Any, Tuple
from ml.preprocessing.normalize import normalize_landmarks_to_hip
from ml.preprocessing.feature_engineering import extract_features


class ExercisePredictor:
    """
    Simulates on-device inference given raw MediaPipe landmarks.
    """

    def __init__(self, model_metadata: Dict[str, Any]):
        self.metadata = model_metadata
        self.classes = model_metadata.get("classes", ["squat", "pushup", "plank", "idle"])

    def predict(self, raw_landmarks: List[Dict[str, float]]) -> Tuple[str, float, Dict[str, float]]:
        """
        1. Normalize landmarks
        2. Extract features
        3. Forward pass
        Returns (predicted_class, confidence, class_probabilities)
        """
        normalized = normalize_landmarks_to_hip(raw_landmarks)
        features = extract_features(normalized)

        # Baseline heuristic / placeholder prior to model weights availability
        probs = {c: 1.0 / len(self.classes) for c in self.classes}
        pred_class = self.classes[0]
        confidence = probs[pred_class]

        return pred_class, confidence, probs
