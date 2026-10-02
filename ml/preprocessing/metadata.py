"""
Dataset Metadata, Split Management, and Leakage Verification.
Enforces subject-level splitting and duplicate protection.
"""

import os
import hashlib
import json
from typing import Dict, List, Set, Tuple

RAW_DIR = os.path.join("ml", "dataset", "raw", "Dataset Subject-wise")
PROCESSED_DIR = os.path.join("ml", "dataset", "processed")

# Approved Subject-Level Splits
TRAIN_SUBJECTS: Set[str] = {
    "subject_001", "subject_002", "subject_003", "subject_004", "subject_005",
    "subject_006", "subject_007", "subject_008", "subject_009", "subject_010",
    "subject_011", "subject_012", "subject_013", "subject_014", "subject_015",
    "subject_019", "subject_020", "subject_026"
}

VAL_SUBJECTS: Set[str] = {
    "subject_016", "subject_017", "subject_018", "subject_021"
}

TEST_SUBJECTS: Set[str] = {
    "subject_022", "subject_023", "subject_024", "subject_025"
}

TARGET_EXERCISES: Set[str] = {"squat", "push_up"}


def compute_file_hash(filepath: str) -> str:
    """Computes MD5 hash for binary duplicate checking."""
    hasher = hashlib.md5()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()


def scan_target_videos(raw_dir: str = RAW_DIR) -> List[Dict[str, str]]:
    """
    Scans raw directory specifically for target MVP exercises (squat, push_up).
    Parses metadata strictly from directory structure and filenames.
    """
    video_entries = []

    for root, _, files in os.walk(raw_dir):
        for f in files:
            if not f.endswith(".mp4"):
                continue
            
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, raw_dir)
            parts = rel_path.split(os.sep)

            # Structure: subject / exercise / quality / view / filename
            if len(parts) != 5:
                continue

            subject_id, exercise, quality, camera_view, filename = parts

            # Only process MVP target exercises
            if exercise not in TARGET_EXERCISES:
                continue

            # Determine split
            if subject_id in TRAIN_SUBJECTS:
                split = "train"
            elif subject_id in VAL_SUBJECTS:
                split = "val"
            elif subject_id in TEST_SUBJECTS:
                split = "test"
            else:
                raise ValueError(f"Unknown subject '{subject_id}' not assigned to any split!")

            video_id = os.path.splitext(filename)[0]

            video_entries.append({
                "video_id": video_id,
                "subject_id": subject_id,
                "exercise": exercise,
                "quality": quality,
                "camera_view": camera_view,
                "split": split,
                "source_path": full_path,
                "rel_path": rel_path,
                "filename": filename,
            })

    return video_entries


def verify_leakage_and_splits(video_entries: List[Dict[str, str]]) -> Dict[str, any]:
    """
    Executes automated assertions:
    1. No subject appears in multiple splits.
    2. No duplicate video hash crosses split boundaries.
    """
    split_subjects: Dict[str, Set[str]] = {"train": set(), "val": set(), "test": set()}
    split_hashes: Dict[str, Set[str]] = {"train": set(), "val": set(), "test": set()}
    hash_to_entries: Dict[str, List[Dict[str, str]]] = {}

    print(f"[Verification] Hashing and verifying {len(video_entries)} target videos...")
    for entry in video_entries:
        split = entry["split"]
        subj = entry["subject_id"]
        fhash = compute_file_hash(entry["source_path"])
        entry["file_hash"] = fhash

        split_subjects[split].add(subj)
        split_hashes[split].add(fhash)

        if fhash not in hash_to_entries:
            hash_to_entries[fhash] = []
        hash_to_entries[fhash].append(entry)

    # 1. Subject Leakage Assertions
    train_val_sub = split_subjects["train"] & split_subjects["val"]
    train_test_sub = split_subjects["train"] & split_subjects["test"]
    val_test_sub = split_subjects["val"] & split_subjects["test"]

    assert len(train_val_sub) == 0, f"Subject leakage between Train and Val: {train_val_sub}"
    assert len(train_test_sub) == 0, f"Subject leakage between Train and Test: {train_test_sub}"
    assert len(val_test_sub) == 0, f"Subject leakage between Val and Test: {val_test_sub}"

    # 2. Hash Duplicate Leakage Assertions
    train_val_hash = split_hashes["train"] & split_hashes["val"]
    train_test_hash = split_hashes["train"] & split_hashes["test"]
    val_test_hash = split_hashes["val"] & split_hashes["test"]

    assert len(train_val_hash) == 0, f"Hash duplicate leakage between Train and Val: {train_val_hash}"
    assert len(train_test_hash) == 0, f"Hash duplicate leakage between Train and Test: {train_test_hash}"
    assert len(val_test_hash) == 0, f"Hash duplicate leakage between Val and Test: {val_test_hash}"

    print("[Verification] ALL LEAKAGE ASSERTIONS PASSED:")
    print(f"  • Train Subjects: {len(split_subjects['train'])} ({len(split_hashes['train'])} unique hashes)")
    print(f"  • Val Subjects:   {len(split_subjects['val'])} ({len(split_hashes['val'])} unique hashes)")
    print(f"  • Test Subjects:  {len(split_subjects['test'])} ({len(split_hashes['test'])} unique hashes)")

    # Save verified splits to JSON
    splits_manifest = {
        "train": {
            "subjects": sorted(list(split_subjects["train"])),
            "video_count": sum(1 for e in video_entries if e["split"] == "train"),
        },
        "val": {
            "subjects": sorted(list(split_subjects["val"])),
            "video_count": sum(1 for e in video_entries if e["split"] == "val"),
        },
        "test": {
            "subjects": sorted(list(split_subjects["test"])),
            "video_count": sum(1 for e in video_entries if e["split"] == "test"),
        },
    }

    splits_path = os.path.join(PROCESSED_DIR, "splits", "splits.json")
    with open(splits_path, "w", encoding="utf-8") as f:
        json.dump(splits_manifest, f, indent=2)

    return {
        "splits_manifest": splits_manifest,
        "total_target_videos": len(video_entries),
    }


if __name__ == "__main__":
    entries = scan_target_videos()
    verify_leakage_and_splits(entries)
