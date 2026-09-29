"""
Dataset loader with strict Subject/Session-level data splitting.
Prevents frame-level data leakage between training and validation/test sets.
"""

from typing import List, Tuple, Dict, Any
import random


class ExerciseDataset:
    """
    Manages loading, normalization, and leakage-free dataset splitting.
    """

    def __init__(self, data_samples: List[Dict[str, Any]]):
        """
        Each sample contains:
        - 'subject_id': str (Identifier of individual user/participant)
        - 'session_id': str (Unique recording session)
        - 'exercise': str (Label e.g. 'squat', 'pushup', 'plank')
        - 'features': List[float] or List[List[float]]
        """
        self.samples = data_samples

    def split_by_subject(
        self,
        train_ratio: float = 0.7,
        val_ratio: float = 0.15,
        test_ratio: float = 0.15,
        seed: int = 42
    ) -> Tuple['ExerciseDataset', 'ExerciseDataset', 'ExerciseDataset']:
        """
        Partitions data by subject_id so no subject's frames appear across multiple splits.
        """
        random.seed(seed)
        all_subjects = list({s['subject_id'] for s in self.samples})
        random.shuffle(all_subjects)

        n = len(all_subjects)
        n_train = int(n * train_ratio)
        n_val = int(n * val_ratio)

        train_subs = set(all_subjects[:n_train])
        val_subs = set(all_subjects[n_train:n_train + n_val])
        test_subs = set(all_subjects[n_train + n_val:])

        train_samples = [s for s in self.samples if s['subject_id'] in train_subs]
        val_samples = [s for s in self.samples if s['subject_id'] in val_subs]
        test_samples = [s for s in self.samples if s['subject_id'] in test_subs]

        print(f"[Split] Total subjects: {n} -> Train: {len(train_subs)}, Val: {len(val_subs)}, Test: {len(test_subs)}")
        print(f"[Split] Samples -> Train: {len(train_samples)}, Val: {len(val_samples)}, Test: {len(test_samples)}")

        return (
            ExerciseDataset(train_samples),
            ExerciseDataset(val_samples),
            ExerciseDataset(test_samples)
        )

    def __len__(self) -> int:
        return len(self.samples)
