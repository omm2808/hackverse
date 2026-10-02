"""
Feature Engineering Module for Fit Odyssey ML Pipeline.

Computes 4 distinct feature groups from normalized landmarks:
- Group A: Normalized 3D landmark coordinates (33 x 3 = 99 features)
- Group B: Biomechanical joint angles (12 features)
- Group C: Relative anatomical distances (12 features)
- Group D: Temporal / dynamic velocities and angular rates (17 features)

Total Engineered Feature Dimensions: 99 + 12 + 12 + 17 = 140 features.
Enables ablation experiments comparing:
1. Landmark-only model (Group A)
2. Static engineered-feature model (Groups A + B + C)
3. Full spatio-temporal feature model (Groups A + B + C + D)
"""

import math
from typing import Dict, List, Optional, Tuple
import numpy as np

# Landmark Indices from MediaPipe Pose
NOSE = 0
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28
LEFT_FOOT_INDEX = 31
RIGHT_FOOT_INDEX = 32

FEATURE_GROUPS = {
    "group_a": [f"norm_lm_{i}_{axis}" for i in range(33) for axis in ("x", "y", "z")],
    "group_b": [
        "angle_left_knee", "angle_right_knee",
        "angle_left_hip", "angle_right_hip",
        "angle_left_elbow", "angle_right_elbow",
        "angle_left_shoulder", "angle_right_shoulder",
        "angle_left_ankle", "angle_right_ankle",
        "angle_trunk_inclination", "angle_neck",
    ],
    "group_c": [
        "dist_left_ankle_to_hip", "dist_right_ankle_to_hip",
        "dist_left_wrist_to_shoulder", "dist_right_wrist_to_shoulder",
        "dist_left_wrist_to_hip", "dist_right_wrist_to_hip",
        "dist_left_knee_to_hip", "dist_right_knee_to_hip",
        "dist_ankle_spread", "dist_wrist_spread",
        "dist_hip_width", "dist_shoulder_width",
    ],
    "group_d": [
        "vel_left_ankle", "vel_right_ankle",
        "vel_left_knee", "vel_right_knee",
        "vel_left_hip", "vel_right_hip",
        "vel_left_wrist", "vel_right_wrist",
        "vel_mid_hip_y", "vel_mid_shoulder_y",
        "d_angle_left_knee", "d_angle_right_knee",
        "d_angle_left_hip", "d_angle_right_hip",
        "d_angle_left_elbow", "d_angle_right_elbow",
        "d_angle_trunk",
    ],
}


def calculate_3d_angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """
    Computes angle ABC in degrees with vertex at b in 3D space.
    Returns angle in range [0.0, 180.0].
    """
    ba = a - b
    bc = c - b
    norm_ba = np.linalg.norm(ba)
    norm_bc = np.linalg.norm(bc)

    if norm_ba < 1e-6 or norm_bc < 1e-6:
        return 0.0

    cosine = np.dot(ba, bc) / (norm_ba * norm_bc)
    cosine = np.clip(cosine, -1.0, 1.0)
    return float(np.degrees(np.arccos(cosine)))


def compute_static_features_for_frame(pts: np.ndarray) -> Dict[str, float]:
    """
    Computes Group A (99), Group B (12), and Group C (12) features for a single frame.
    
    Args:
        pts: Normalized 3D landmarks array of shape (33, 3).
        
    Returns:
        dict of feature name to float value.
    """
    feats = {}

    # Group A: 99 Normalized landmark coordinates
    for i in range(33):
        feats[f"norm_lm_{i}_x"] = float(pts[i, 0])
        feats[f"norm_lm_{i}_y"] = float(pts[i, 1])
        feats[f"norm_lm_{i}_z"] = float(pts[i, 2])

    # Group B: 12 Joint angles
    feats["angle_left_knee"] = calculate_3d_angle(pts[LEFT_HIP], pts[LEFT_KNEE], pts[LEFT_ANKLE])
    feats["angle_right_knee"] = calculate_3d_angle(pts[RIGHT_HIP], pts[RIGHT_KNEE], pts[RIGHT_ANKLE])

    feats["angle_left_hip"] = calculate_3d_angle(pts[LEFT_SHOULDER], pts[LEFT_HIP], pts[LEFT_KNEE])
    feats["angle_right_hip"] = calculate_3d_angle(pts[RIGHT_SHOULDER], pts[RIGHT_HIP], pts[RIGHT_KNEE])

    feats["angle_left_elbow"] = calculate_3d_angle(pts[LEFT_SHOULDER], pts[LEFT_ELBOW], pts[LEFT_WRIST])
    feats["angle_right_elbow"] = calculate_3d_angle(pts[RIGHT_SHOULDER], pts[RIGHT_ELBOW], pts[RIGHT_WRIST])

    feats["angle_left_shoulder"] = calculate_3d_angle(pts[LEFT_ELBOW], pts[LEFT_SHOULDER], pts[LEFT_HIP])
    feats["angle_right_shoulder"] = calculate_3d_angle(pts[RIGHT_ELBOW], pts[RIGHT_SHOULDER], pts[RIGHT_HIP])

    feats["angle_left_ankle"] = calculate_3d_angle(pts[LEFT_KNEE], pts[LEFT_ANKLE], pts[LEFT_FOOT_INDEX])
    feats["angle_right_ankle"] = calculate_3d_angle(pts[RIGHT_KNEE], pts[RIGHT_ANKLE], pts[RIGHT_FOOT_INDEX])

    # Torso vector and vertical reference (up vector in MediaPipe is -y)
    mid_hip = (pts[LEFT_HIP] + pts[RIGHT_HIP]) / 2.0
    mid_shoulder = (pts[LEFT_SHOULDER] + pts[RIGHT_SHOULDER]) / 2.0
    torso_vec = mid_shoulder - mid_hip
    vertical_up = np.array([0.0, -1.0, 0.0], dtype=np.float32)

    norm_torso = np.linalg.norm(torso_vec)
    if norm_torso > 1e-6:
        cos_trunk = np.dot(torso_vec, vertical_up) / norm_torso
        feats["angle_trunk_inclination"] = float(np.degrees(np.arccos(np.clip(cos_trunk, -1.0, 1.0))))
    else:
        feats["angle_trunk_inclination"] = 0.0

    # Neck angle
    neck_vec = pts[NOSE] - mid_shoulder
    norm_neck = np.linalg.norm(neck_vec)
    if norm_torso > 1e-6 and norm_neck > 1e-6:
        cos_neck = np.dot(neck_vec, torso_vec) / (norm_neck * norm_torso)
        feats["angle_neck"] = float(np.degrees(np.arccos(np.clip(cos_neck, -1.0, 1.0))))
    else:
        feats["angle_neck"] = 0.0

    # Group C: 12 Relative distances (already torso-scale normalized)
    feats["dist_left_ankle_to_hip"] = float(np.linalg.norm(pts[LEFT_ANKLE] - pts[LEFT_HIP]))
    feats["dist_right_ankle_to_hip"] = float(np.linalg.norm(pts[RIGHT_ANKLE] - pts[RIGHT_HIP]))
    feats["dist_left_wrist_to_shoulder"] = float(np.linalg.norm(pts[LEFT_WRIST] - pts[LEFT_SHOULDER]))
    feats["dist_right_wrist_to_shoulder"] = float(np.linalg.norm(pts[RIGHT_WRIST] - pts[RIGHT_SHOULDER]))
    feats["dist_left_wrist_to_hip"] = float(np.linalg.norm(pts[LEFT_WRIST] - pts[LEFT_HIP]))
    feats["dist_right_wrist_to_hip"] = float(np.linalg.norm(pts[RIGHT_WRIST] - pts[RIGHT_HIP]))
    feats["dist_left_knee_to_hip"] = float(np.linalg.norm(pts[LEFT_KNEE] - pts[LEFT_HIP]))
    feats["dist_right_knee_to_hip"] = float(np.linalg.norm(pts[RIGHT_KNEE] - pts[RIGHT_HIP]))
    feats["dist_ankle_spread"] = float(np.linalg.norm(pts[LEFT_ANKLE] - pts[RIGHT_ANKLE]))
    feats["dist_wrist_spread"] = float(np.linalg.norm(pts[LEFT_WRIST] - pts[RIGHT_WRIST]))
    feats["dist_hip_width"] = float(np.linalg.norm(pts[LEFT_HIP] - pts[RIGHT_HIP]))
    feats["dist_shoulder_width"] = float(np.linalg.norm(pts[LEFT_SHOULDER] - pts[RIGHT_SHOULDER]))

    return feats


def compute_sequence_features(
    norm_landmarks_seq: np.ndarray,
    timestamps: List[float]
) -> List[Dict[str, float]]:
    """
    Computes Groups A, B, C, and D for an entire video sequence.
    
    Args:
        norm_landmarks_seq: Array of shape (T, 33, 3) normalized landmarks.
        timestamps: List of length T with timestamps in seconds.
        
    Returns:
        List of T feature dicts containing all 140 features per frame.
    """
    T = norm_landmarks_seq.shape[0]
    frame_features: List[Dict[str, float]] = []

    # First pass: static features
    for t in range(T):
        f = compute_static_features_for_frame(norm_landmarks_seq[t])
        frame_features.append(f)

    # Second pass: Group D (Temporal dynamics)
    for t in range(T):
        d_feats = {}
        if t == 0:
            for feat_name in FEATURE_GROUPS["group_d"]:
                d_feats[feat_name] = 0.0
        else:
            dt = timestamps[t] - timestamps[t - 1]
            if dt <= 1e-4:
                dt = 1.0 / 15.0  # fallback to nominal 15 fps dt

            prev_pts = norm_landmarks_seq[t - 1]
            curr_pts = norm_landmarks_seq[t]

            # Linear landmark velocities (norm displacement / dt)
            d_feats["vel_left_ankle"] = float(np.linalg.norm(curr_pts[LEFT_ANKLE] - prev_pts[LEFT_ANKLE]) / dt)
            d_feats["vel_right_ankle"] = float(np.linalg.norm(curr_pts[RIGHT_ANKLE] - prev_pts[RIGHT_ANKLE]) / dt)
            d_feats["vel_left_knee"] = float(np.linalg.norm(curr_pts[LEFT_KNEE] - prev_pts[LEFT_KNEE]) / dt)
            d_feats["vel_right_knee"] = float(np.linalg.norm(curr_pts[RIGHT_KNEE] - prev_pts[RIGHT_KNEE]) / dt)
            d_feats["vel_left_hip"] = float(np.linalg.norm(curr_pts[LEFT_HIP] - prev_pts[LEFT_HIP]) / dt)
            d_feats["vel_right_hip"] = float(np.linalg.norm(curr_pts[RIGHT_HIP] - prev_pts[RIGHT_HIP]) / dt)
            d_feats["vel_left_wrist"] = float(np.linalg.norm(curr_pts[LEFT_WRIST] - prev_pts[LEFT_WRIST]) / dt)
            d_feats["vel_right_wrist"] = float(np.linalg.norm(curr_pts[RIGHT_WRIST] - prev_pts[RIGHT_WRIST]) / dt)

            # Vertical center velocities
            prev_mid_hip_y = (prev_pts[LEFT_HIP, 1] + prev_pts[RIGHT_HIP, 1]) / 2.0
            curr_mid_hip_y = (curr_pts[LEFT_HIP, 1] + curr_pts[RIGHT_HIP, 1]) / 2.0
            d_feats["vel_mid_hip_y"] = float((curr_mid_hip_y - prev_mid_hip_y) / dt)

            prev_mid_sh_y = (prev_pts[LEFT_SHOULDER, 1] + prev_pts[RIGHT_SHOULDER, 1]) / 2.0
            curr_mid_sh_y = (curr_pts[LEFT_SHOULDER, 1] + curr_pts[RIGHT_SHOULDER, 1]) / 2.0
            d_feats["vel_mid_shoulder_y"] = float((curr_mid_sh_y - prev_mid_sh_y) / dt)

            # Angular velocities (deg / dt)
            for angle_key in ("angle_left_knee", "angle_right_knee", "angle_left_hip",
                              "angle_right_hip", "angle_left_elbow", "angle_right_elbow",
                              "angle_trunk_inclination"):
                d_key = "d_" + (angle_key if angle_key != "angle_trunk_inclination" else "angle_trunk")
                d_feats[d_key] = float((frame_features[t][angle_key] - frame_features[t - 1][angle_key]) / dt)

        frame_features[t].update(d_feats)

    return frame_features
