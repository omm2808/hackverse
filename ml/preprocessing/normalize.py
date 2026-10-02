"""
Landmark Normalization Module for Fit Odyssey ML Pipeline.

Implements deterministic body-relative normalization:
1. Translates coordinate frame so the origin (0, 0, 0) is at the mid-hip point:
   center = (left_hip + right_hip) / 2.
2. Scales coordinates by the torso length:
   torso_scale = Euclidean distance from mid-hip to mid-shoulder:
   scale = ||mid_shoulder - mid_hip||.
3. Fallback scale: If torso length is degenerate (< 1e-4), uses shoulder-to-shoulder
   distance or defaults to 1.0.

This eliminates dependence on:
- Camera resolution
- Subject's position in frame (2D translation)
- Distance from camera / zoom (scale)
- Subject's physical height / body proportion differences
"""

import math
from typing import Dict, List, Optional, Tuple, Union
import numpy as np

# Landmark Indices from MediaPipe Pose (33 points)
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_HIP = 23
RIGHT_HIP = 24


def calculate_torso_reference(
    landmarks: Union[List[Dict[str, float]], np.ndarray]
) -> Tuple[np.ndarray, float]:
    """
    Computes mid-hip center (origin) and torso scale factor.
    
    Args:
        landmarks: Either a list of 33 dicts [{'x':..., 'y':..., 'z':...}]
                   or a numpy array of shape (33, 3).
                   
    Returns:
        mid_hip: np.ndarray of shape (3,) [cx, cy, cz]
        scale: float torso length scale
    """
    if isinstance(landmarks, list):
        pts = np.zeros((33, 3), dtype=np.float32)
        for i in range(min(33, len(landmarks))):
            lm = landmarks[i]
            pts[i, 0] = lm.get("x", 0.0)
            pts[i, 1] = lm.get("y", 0.0)
            pts[i, 2] = lm.get("z", 0.0)
    else:
        pts = landmarks

    left_hip = pts[LEFT_HIP]
    right_hip = pts[RIGHT_HIP]
    left_shoulder = pts[LEFT_SHOULDER]
    right_shoulder = pts[RIGHT_SHOULDER]

    mid_hip = (left_hip + right_hip) / 2.0
    mid_shoulder = (left_shoulder + right_shoulder) / 2.0

    torso_len = float(np.linalg.norm(mid_shoulder - mid_hip))

    if torso_len > 1e-4:
        scale = torso_len
    else:
        # Fallback to shoulder width
        shoulder_width = float(np.linalg.norm(left_shoulder - right_shoulder))
        scale = shoulder_width if shoulder_width > 1e-4 else 1.0

    return mid_hip, scale


def normalize_landmarks_dict(
    landmarks: List[Dict[str, float]]
) -> List[Dict[str, float]]:
    """
    Normalizes a single frame of 33 landmarks represented as a list of dicts.
    Preserves visibility and presence attributes.
    """
    if len(landmarks) < 33:
        return landmarks

    mid_hip, scale = calculate_torso_reference(landmarks)

    normalized = []
    for lm in landmarks:
        norm_item = {
            "x": float((lm.get("x", 0.0) - mid_hip[0]) / scale),
            "y": float((lm.get("y", 0.0) - mid_hip[1]) / scale),
            "z": float((lm.get("z", 0.0) - mid_hip[2]) / scale),
        }
        if "visibility" in lm:
            norm_item["visibility"] = float(lm["visibility"])
        if "presence" in lm:
            norm_item["presence"] = float(lm["presence"])
        normalized.append(norm_item)

    return normalized


def normalize_landmarks_numpy(
    landmarks_xyz: np.ndarray
) -> Tuple[np.ndarray, np.ndarray, float]:
    """
    Normalizes an array of shape (N, 33, 3) or (33, 3).
    Returns (normalized_xyz, mid_hip, scale).
    """
    is_single = landmarks_xyz.ndim == 2
    pts = landmarks_xyz[np.newaxis, ...] if is_single else landmarks_xyz
    N = pts.shape[0]

    norm_pts = np.zeros_like(pts)
    mid_hips = np.zeros((N, 3), dtype=np.float32)
    scales = np.zeros((N,), dtype=np.float32)

    for i in range(N):
        mid_hip, scale = calculate_torso_reference(pts[i])
        norm_pts[i] = (pts[i] - mid_hip) / scale
        mid_hips[i] = mid_hip
        scales[i] = scale

    if is_single:
        return norm_pts[0], mid_hips[0], float(scales[0])
    return norm_pts, mid_hips, scales
