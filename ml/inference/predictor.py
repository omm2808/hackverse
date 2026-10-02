"""
Fit Odyssey — Pose Intelligence Inference Module.

Provides real-time inference given 33 BlazePose landmarks:
Camera → BlazePose (33 Landmarks) → Normalization → Feature Extraction → Custom ML Model → PredictionResult

Output schema:
{
    "predictedClass": "squat",
    "confidence": 0.98,
    "exercise": "squat",
    "formStatus": "good",
    "formConfidence": 0.85,
    "biomechanics": {
        "kneeAngleLeft": 94.2,
        "kneeAngleRight": 96.5,
        "elbowAngleLeft": 165.1,
        "elbowAngleRight": 163.4,
        "trunkInclination": 58.2
    },
    "feedback": "Good Form — Keep it up!"
}
"""

import os
import json
import joblib
import numpy as np
from dataclasses import dataclass, asdict
from typing import Dict, List, Any, Optional, Union, Tuple

from ml.preprocessing.normalize import calculate_torso_reference, normalize_landmarks_numpy
from ml.preprocessing.feature_engineering import (
    compute_static_features_for_frame,
    FEATURE_GROUPS,
    LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE,
    LEFT_ANKLE, RIGHT_ANKLE, LEFT_SHOULDER, RIGHT_SHOULDER,
    LEFT_ELBOW, RIGHT_ELBOW, LEFT_WRIST, RIGHT_WRIST
)


@dataclass
class PredictionResult:
    predictedClass: str
    confidence: float
    exercise: str
    formStatus: str
    formConfidence: float
    biomechanics: Dict[str, float]
    feedback: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class PoseIntelligencePredictor:
    """
    On-device compatible Python predictor testbed.
    Loads trained Random Forest classifiers and provides low-latency single-frame inference.
    """

    def __init__(self, models_dir: str = "ml/models"):
        self.models_dir = models_dir

        exercise_model_path = os.path.join(models_dir, "exercise_classifier.joblib")
        squat_form_path = os.path.join(models_dir, "squat_form_classifier.joblib")
        pushup_form_path = os.path.join(models_dir, "pushup_form_classifier.joblib")
        feature_names_path = os.path.join(models_dir, "feature_names.json")

        if not os.path.exists(exercise_model_path):
            raise FileNotFoundError(f"Exercise model not found at {exercise_model_path}. Run training pipeline first.")

        self.exercise_model = joblib.load(exercise_model_path)
        self.squat_form_model = joblib.load(squat_form_path) if os.path.exists(squat_form_path) else None
        self.pushup_form_model = joblib.load(pushup_form_path) if os.path.exists(pushup_form_path) else None

        if os.path.exists(feature_names_path):
            with open(feature_names_path, "r") as f:
                self.feature_names = json.load(f)
        else:
            self.feature_names = None

        # State tracking for delta features across consecutive video frames
        self.prev_norm_landmarks = None
        self.prev_timestamp = None
        self.prev_angles = {}

    def reset_state(self):
        """Resets temporal tracking between workout sets."""
        self.prev_norm_landmarks = None
        self.prev_timestamp = None
        self.prev_angles = {}

    def extract_features_from_raw_landmarks(
        self,
        raw_landmarks: Union[List[Dict[str, float]], np.ndarray],
        timestamp: Optional[float] = None
    ) -> Tuple[np.ndarray, Dict[str, float]]:
        """
        1. Normalizes landmarks relative to mid-hip and torso scale.
        2. Computes 140 biomechanical and spatio-temporal features.
        """
        if isinstance(raw_landmarks, list):
            pts = np.zeros((33, 3), dtype=np.float32)
            for i in range(min(33, len(raw_landmarks))):
                lm = raw_landmarks[i]
                pts[i, 0] = lm.get("x", 0.0)
                pts[i, 1] = lm.get("y", 0.0)
                pts[i, 2] = lm.get("z", 0.0)
        else:
            pts = raw_landmarks[:, :3].astype(np.float32)

        # Normalize relative to mid-hip and torso
        norm_pts, mid_hip, scale = normalize_landmarks_numpy(pts)

        # Compute static features (Groups A, B, C = 123 features)
        frame_feats = compute_static_features_for_frame(norm_pts)

        # Compute dynamic features (Group D = 17 features)
        d_feats = {}
        if self.prev_norm_landmarks is None or timestamp is None or self.prev_timestamp is None:
            for feat_name in FEATURE_GROUPS["group_d"]:
                d_feats[feat_name] = 0.0
        else:
            dt = max(1e-4, timestamp - self.prev_timestamp)
            prev_pts = self.prev_norm_landmarks

            # Landmark velocities
            d_feats["vel_left_ankle"] = float(np.linalg.norm(norm_pts[LEFT_ANKLE] - prev_pts[LEFT_ANKLE]) / dt)
            d_feats["vel_right_ankle"] = float(np.linalg.norm(norm_pts[RIGHT_ANKLE] - prev_pts[RIGHT_ANKLE]) / dt)
            d_feats["vel_left_knee"] = float(np.linalg.norm(norm_pts[LEFT_KNEE] - prev_pts[LEFT_KNEE]) / dt)
            d_feats["vel_right_knee"] = float(np.linalg.norm(norm_pts[RIGHT_KNEE] - prev_pts[RIGHT_KNEE]) / dt)
            d_feats["vel_left_hip"] = float(np.linalg.norm(norm_pts[LEFT_HIP] - prev_pts[LEFT_HIP]) / dt)
            d_feats["vel_right_hip"] = float(np.linalg.norm(norm_pts[RIGHT_HIP] - prev_pts[RIGHT_HIP]) / dt)
            d_feats["vel_left_wrist"] = float(np.linalg.norm(norm_pts[LEFT_WRIST] - prev_pts[LEFT_WRIST]) / dt)
            d_feats["vel_right_wrist"] = float(np.linalg.norm(norm_pts[RIGHT_WRIST] - prev_pts[RIGHT_WRIST]) / dt)

            prev_mid_hip_y = (prev_pts[LEFT_HIP, 1] + prev_pts[RIGHT_HIP, 1]) / 2.0
            curr_mid_hip_y = (norm_pts[LEFT_HIP, 1] + norm_pts[RIGHT_HIP, 1]) / 2.0
            d_feats["vel_mid_hip_y"] = float((curr_mid_hip_y - prev_mid_hip_y) / dt)

            prev_mid_sh_y = (prev_pts[LEFT_SHOULDER, 1] + prev_pts[RIGHT_SHOULDER, 1]) / 2.0
            curr_mid_sh_y = (norm_pts[LEFT_SHOULDER, 1] + norm_pts[RIGHT_SHOULDER, 1]) / 2.0
            d_feats["vel_mid_shoulder_y"] = float((curr_mid_sh_y - prev_mid_sh_y) / dt)

            # Angular velocities
            for angle_key in ("angle_left_knee", "angle_right_knee", "angle_left_hip",
                              "angle_right_hip", "angle_left_elbow", "angle_right_elbow",
                              "angle_trunk_inclination"):
                d_key = "d_" + (angle_key if angle_key != "angle_trunk_inclination" else "angle_trunk")
                prev_val = self.prev_angles.get(angle_key, frame_feats[angle_key])
                d_feats[d_key] = float((frame_feats[angle_key] - prev_val) / dt)

        # Update frame state
        frame_feats.update(d_feats)
        self.prev_norm_landmarks = norm_pts
        self.prev_timestamp = timestamp
        self.prev_angles = {k: frame_feats[k] for k in ("angle_left_knee", "angle_right_knee", "angle_left_hip",
                                                        "angle_right_hip", "angle_left_elbow", "angle_right_elbow",
                                                        "angle_trunk_inclination")}

        # Convert dictionary to ordered feature vector matching training feature names
        if self.feature_names:
            feature_vector = np.array([frame_feats.get(fn, 0.0) for fn in self.feature_names], dtype=np.float32)
        else:
            feature_vector = np.array(list(frame_feats.values()), dtype=np.float32)

        return feature_vector, frame_feats

    def predict(
        self,
        raw_landmarks: Union[List[Dict[str, float]], np.ndarray],
        timestamp: Optional[float] = None,
        enforce_exercise: Optional[str] = None
    ) -> PredictionResult:
        """
        Executes on-device inference pipeline:
        Landmarks → Features → Exercise Classifier → Form Quality Classifier → PredictionResult
        """
        feats_vec, raw_feats = self.extract_features_from_raw_landmarks(raw_landmarks, timestamp)
        X = feats_vec.reshape(1, -1)

        # 1. Exercise prediction
        if enforce_exercise:
            pred_exercise = enforce_exercise
            ex_conf = 1.0
        else:
            ex_probs = self.exercise_model.predict_proba(X)[0]
            ex_classes = self.exercise_model.classes_
            pred_idx = int(np.argmax(ex_probs))
            pred_exercise = str(ex_classes[pred_idx])
            ex_conf = float(ex_probs[pred_idx])

        # 2. Form prediction based on exercise
        form_status = "good"
        form_conf = 0.5
        if pred_exercise == "squat" and self.squat_form_model is not None:
            form_probs = self.squat_form_model.predict_proba(X)[0]
            form_idx = int(np.argmax(form_probs))
            form_status = str(self.squat_form_model.classes_[form_idx])
            form_conf = float(form_probs[form_idx])
        elif pred_exercise == "push_up" and self.pushup_form_model is not None:
            form_probs = self.pushup_form_model.predict_proba(X)[0]
            form_idx = int(np.argmax(form_probs))
            form_status = str(self.pushup_form_model.classes_[form_idx])
            form_conf = float(form_probs[form_idx])

        # 3. Biomechanical measurements for transparent coaching
        biomechanics = {
            "kneeAngleLeft": round(float(raw_feats.get("angle_left_knee", 0.0)), 1),
            "kneeAngleRight": round(float(raw_feats.get("angle_right_knee", 0.0)), 1),
            "hipAngleLeft": round(float(raw_feats.get("angle_left_hip", 0.0)), 1),
            "elbowAngleLeft": round(float(raw_feats.get("angle_left_elbow", 0.0)), 1),
            "elbowAngleRight": round(float(raw_feats.get("angle_right_elbow", 0.0)), 1),
            "trunkInclination": round(float(raw_feats.get("angle_trunk_inclination", 0.0)), 1),
        }

        # 4. Generate coaching feedback
        feedback = self._generate_coaching_feedback(pred_exercise, form_status, biomechanics)

        return PredictionResult(
            predictedClass=pred_exercise,
            confidence=round(ex_conf, 3),
            exercise=pred_exercise,
            formStatus=form_status,
            formConfidence=round(form_conf, 3),
            biomechanics=biomechanics,
            feedback=feedback
        )

    def _generate_coaching_feedback(self, exercise: str, form_status: str, bio: Dict[str, float]) -> str:
        """Synthesizes human-readable coaching cues based on predicted form and angles."""
        if form_status == "good":
            return "Good form — Maintain steady tempo!"

        if exercise == "squat":
            knee_avg = (bio["kneeAngleLeft"] + bio["kneeAngleRight"]) / 2.0
            if knee_avg > 110.0:
                return "Squat deeper — Strive to reach parallel thighs."
            if bio["trunkInclination"] < 40.0:
                return "Keep your chest up — Avoid leaning too far forward."
            return "Check squat stance and knee alignment."

        if exercise == "push_up":
            elbow_avg = (bio["elbowAngleLeft"] + bio["elbowAngleRight"]) / 2.0
            if elbow_avg > 105.0:
                return "Descend deeper — Aim for 90° elbow flexion."
            if bio["trunkInclination"] > 95.0 or bio["trunkInclination"] < 75.0:
                return "Keep your hips straight — Prevent sagging."
            return "Maintain solid plank core engagement."

        return "Adjust your posture for optimal form."
