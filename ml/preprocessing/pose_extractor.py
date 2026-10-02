"""
Pose Landmark Extractor using MediaPipe Tasks Vision PoseLandmarker.
Extracts 33 body pose landmarks per frame with temporal sampling at ~15 FPS.
"""

import os
from typing import Any, Dict, List, Optional, Tuple
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

# Default model path in workspace
DEFAULT_MODEL_PATH = os.path.join("ml", "models", "pose_landmarker_lite.task")

# Standard MediaPipe Pose connections for skeleton drawing
POSE_CONNECTIONS = [
    (11, 12),  # shoulders
    (11, 13), (13, 15),  # left arm
    (12, 14), (14, 16),  # right arm
    (11, 23), (12, 24),  # torso sides
    (23, 24),  # hips
    (23, 25), (25, 27), (27, 29), (29, 31),  # left leg & foot
    (24, 26), (26, 28), (28, 30), (30, 32),  # right leg & foot
    (0, 1), (1, 2), (2, 3), (3, 7),  # left face
    (0, 4), (4, 5), (5, 6), (6, 8),  # right face
    (9, 10),  # mouth
]


class PoseExtractor:
    """
    Encapsulates MediaPipe PoseLandmarker for video and frame extraction.
    """

    def __init__(self, model_asset_path: str = DEFAULT_MODEL_PATH):
        if not os.path.exists(model_asset_path):
            raise FileNotFoundError(f"MediaPipe PoseLandmarker model not found at: {model_asset_path}")

        self.model_path = model_asset_path
        self._options = vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=model_asset_path),
            running_mode=vision.RunningMode.IMAGE,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self._landmarker = vision.PoseLandmarker.create_from_options(self._options)

    def extract_frame_landmarks(
        self, frame_bgr: np.ndarray
    ) -> Tuple[bool, List[Dict[str, float]]]:
        """
        Extracts 33 pose landmarks from a single BGR frame.
        
        Returns:
            (detected: bool, landmarks: list of 33 dicts with x, y, z, visibility, presence)
        """
        rgb_frame = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        result = self._landmarker.detect(mp_image)

        if not result.pose_landmarks or len(result.pose_landmarks) == 0:
            empty_lms = [{"x": 0.0, "y": 0.0, "z": 0.0, "visibility": 0.0, "presence": 0.0} for _ in range(33)]
            return False, empty_lms

        first_pose = result.pose_landmarks[0]
        lms = []
        for lm in first_pose:
            lms.append({
                "x": float(lm.x),
                "y": float(lm.y),
                "z": float(lm.z),
                "visibility": float(getattr(lm, "visibility", 1.0)),
                "presence": float(getattr(lm, "presence", 1.0)),
            })

        return True, lms

    def extract_video(
        self,
        video_path: str,
        target_fps: float = 15.0
    ) -> Dict[str, Any]:
        """
        Extracts pose landmark sequence from a video file at ~target_fps.
        Preserves original FPS, duration, and exact frame timestamps.
        """
        if not os.path.exists(video_path):
            raise FileNotFoundError(f"Video file not found: {video_path}")

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise IOError(f"Could not open video file: {video_path}")

        source_fps = float(cap.get(cv2.CAP_PROP_FPS))
        total_source_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        # Guard against zero or corrupted FPS
        effective_fps = source_fps if (source_fps > 0 and not np.isnan(source_fps)) else 30.0
        duration = float(total_source_frames / effective_fps) if total_source_frames > 0 else 0.0

        # Frame step for sampling at target_fps
        # Example: source 30 fps, target 15 fps -> step = 2 (sample every 2nd frame)
        # Example: source 15 fps, target 15 fps -> step = 1 (sample every frame)
        step = max(1, round(effective_fps / target_fps))

        frame_records = []
        frame_idx = 0
        extracted_count = 0
        detected_count = 0

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx % step == 0:
                timestamp = float(frame_idx / effective_fps)
                detected, lms = self.extract_frame_landmarks(frame)
                if detected:
                    detected_count += 1

                frame_records.append({
                    "frame_index": frame_idx,
                    "timestamp": round(timestamp, 4),
                    "detected": detected,
                    "landmarks": lms,
                })
                extracted_count += 1

            frame_idx += 1

        cap.release()

        return {
            "source_fps": round(source_fps, 2),
            "effective_fps": round(effective_fps, 2),
            "total_source_frames": total_source_frames,
            "duration": round(duration, 2),
            "resolution": f"{width}x{height}",
            "step": step,
            "target_fps": target_fps,
            "extracted_frames": extracted_count,
            "detected_frames": detected_count,
            "detection_rate": round(detected_count / max(1, extracted_count), 4),
            "frame_records": frame_records,
        }

    @staticmethod
    def draw_skeleton_overlay(
        image_bgr: np.ndarray,
        landmarks: List[Dict[str, float]],
        color_pts=(0, 255, 0),
        color_lines=(0, 200, 255),
        thickness=2,
        radius=4
    ) -> np.ndarray:
        """
        Draws 33 pose landmarks and skeleton bones on a BGR image.
        Landmark coordinates are assumed to be normalized [0, 1] relative to image dimensions.
        """
        out_img = image_bgr.copy()
        h, w = out_img.shape[:2]

        pts_2d = {}
        for idx, lm in enumerate(landmarks):
            px = int(lm["x"] * w)
            py = int(lm["y"] * h)
            vis = lm.get("visibility", 1.0)
            pts_2d[idx] = (px, py, vis)

        # Draw connections
        for p1, p2 in POSE_CONNECTIONS:
            if p1 in pts_2d and p2 in pts_2d:
                x1, y1, v1 = pts_2d[p1]
                x2, y2, v2 = pts_2d[p2]
                if v1 > 0.3 and v2 > 0.3:
                    cv2.line(out_img, (x1, y1), (x2, y2), color_lines, thickness, cv2.LINE_AA)

        # Draw keypoints
        for idx, (px, py, vis) in pts_2d.items():
            if vis > 0.3:
                cv2.circle(out_img, (px, py), radius, color_pts, -1, cv2.LINE_AA)
                cv2.circle(out_img, (px, py), radius + 1, (255, 255, 255), 1, cv2.LINE_AA)

        return out_img
