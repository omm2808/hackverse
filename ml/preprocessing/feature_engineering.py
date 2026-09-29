"""
Feature engineering module.
Extracts joint angles, Euclidean distances, and velocities from normalized landmarks.
"""

from typing import List, Dict
import math


def calculate_angle(a: Dict[str, float], b: Dict[str, float], c: Dict[str, float]) -> float:
    """
    Computes angle ABC in degrees with vertex at point B.
    """
    ba = (a['x'] - b['x'], a['y'] - b['y'], a.get('z', 0.0) - b.get('z', 0.0))
    bc = (c['x'] - b['x'], c['y'] - b['y'], c.get('z', 0.0) - b.get('z', 0.0))

    dot = ba[0] * bc[0] + ba[1] * bc[1] + ba[2] * bc[2]
    mag_ba = math.sqrt(ba[0] ** 2 + ba[1] ** 2 + ba[2] ** 2)
    mag_bc = math.sqrt(bc[0] ** 2 + bc[1] ** 2 + bc[2] ** 2)

    if mag_ba * mag_bc == 0:
        return 0.0

    cos_val = max(-1.0, min(1.0, dot / (mag_ba * mag_bc)))
    return math.acos(cos_val) * (180.0 / math.pi)


def extract_features(landmarks: List[Dict[str, float]]) -> List[float]:
    """
    Extracts a feature vector of normalized key joint angles and coordinates:
    - Left & right knee angles
    - Left & right hip angles
    - Left & right elbow angles
    - Left & right shoulder angles
    - Spine / torso inclination
    """
    if len(landmarks) < 33:
        return [0.0] * 16

    left_knee_angle = calculate_angle(landmarks[23], landmarks[25], landmarks[27])
    right_knee_angle = calculate_angle(landmarks[24], landmarks[26], landmarks[28])

    left_hip_angle = calculate_angle(landmarks[11], landmarks[23], landmarks[25])
    right_hip_angle = calculate_angle(landmarks[12], landmarks[24], landmarks[26])

    left_elbow_angle = calculate_angle(landmarks[11], landmarks[13], landmarks[15])
    right_elbow_angle = calculate_angle(landmarks[12], landmarks[14], landmarks[16])

    left_shoulder_angle = calculate_angle(landmarks[13], landmarks[11], landmarks[23])
    right_shoulder_angle = calculate_angle(landmarks[14], landmarks[12], landmarks[24])

    features = [
        left_knee_angle / 180.0,
        right_knee_angle / 180.0,
        left_hip_angle / 180.0,
        right_hip_angle / 180.0,
        left_elbow_angle / 180.0,
        right_elbow_angle / 180.0,
        left_shoulder_angle / 180.0,
        right_shoulder_angle / 180.0,
        # Normalized key point coordinates
        landmarks[25]['y'],  # left knee y
        landmarks[26]['y'],  # right knee y
        landmarks[23]['y'],  # left hip y
        landmarks[24]['y'],  # right hip y
        landmarks[11]['y'],  # left shoulder y
        landmarks[12]['y'],  # right shoulder y
        landmarks[15]['y'],  # left wrist y
        landmarks[16]['y'],  # right wrist y
    ]
    return features
