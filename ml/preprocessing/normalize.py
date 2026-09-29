"""
Landmark normalization module.
Makes landmarks invariant to user scale, camera distance, and 2D translation.
"""

from typing import List, Dict
import math


def normalize_landmarks_to_hip(landmarks: List[Dict[str, float]]) -> List[Dict[str, float]]:
    """
    Centers landmarks at the mid-hip point (landmarks 23 and 24)
    and scales by the torso height (mid-hip to mid-shoulder distance).
    """
    if len(landmarks) < 33:
        return landmarks

    left_hip = landmarks[23]
    right_hip = landmarks[24]
    left_shoulder = landmarks[11]
    right_shoulder = landmarks[12]

    # Midpoints
    mid_hip_x = (left_hip['x'] + right_hip['x']) / 2.0
    mid_hip_y = (left_hip['y'] + right_hip['y']) / 2.0
    mid_hip_z = (left_hip.get('z', 0.0) + right_hip.get('z', 0.0)) / 2.0

    mid_shoulder_x = (left_shoulder['x'] + right_shoulder['x']) / 2.0
    mid_shoulder_y = (left_shoulder['y'] + right_shoulder['y']) / 2.0
    mid_shoulder_z = (left_shoulder.get('z', 0.0) + right_shoulder.get('z', 0.0)) / 2.0

    # Torso length as reference scale factor
    torso_len = math.sqrt(
        (mid_shoulder_x - mid_hip_x) ** 2 +
        (mid_shoulder_y - mid_hip_y) ** 2 +
        (mid_shoulder_z - mid_hip_z) ** 2
    )

    scale = torso_len if torso_len > 1e-4 else 1.0

    normalized = []
    for lm in landmarks:
        normalized.append({
            'x': (lm['x'] - mid_hip_x) / scale,
            'y': (lm['y'] - mid_hip_y) / scale,
            'z': (lm.get('z', 0.0) - mid_hip_z) / scale,
            'visibility': lm.get('visibility', 1.0)
        })

    return normalized
