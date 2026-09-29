"""
Landmark extraction pipeline using MediaPipe Pose Landmarker.
Converts raw video/image frames into structured 33-landmark sequences.
"""

from typing import List, Dict, Any, Optional
import os


class LandmarkExtractor:
    """
    Offline feature extractor that loads video frames and computes
    33 3D body landmarks (x, y, z, visibility) via MediaPipe.
    """

    def __init__(self, static_image_mode: bool = False, model_complexity: int = 1):
        self.static_image_mode = static_image_mode
        self.model_complexity = model_complexity

    def process_video(self, video_path: str) -> List[Dict[str, Any]]:
        """
        Extract landmark sequences from an exercise video.
        Returns a list of frame-level landmark dictionaries.
        """
        if not os.path.exists(video_path):
            raise FileNotFoundError(f"Video file not found: {video_path}")

        # Placeholder interface for offline batch extraction
        print(f"[ML-Pipeline] Extracting landmarks from: {video_path}")
        return []

    def process_frame(self, frame_bgr: Any) -> Optional[List[Dict[str, float]]]:
        """
        Extract 33 landmarks for a single video frame.
        """
        # Mirrors the output format of on-device MediaPipe
        return None
