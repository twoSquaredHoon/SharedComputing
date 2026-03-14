from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend_helpers import (
    compute_split_counts,
    count_dataset_images,
    parse_summary_text,
    resolve_dataset_path,
)


class BackendHelpersTests(unittest.TestCase):
    def test_compute_split_counts_matches_training_formula(self) -> None:
        self.assertEqual(compute_split_counts(606), (424, 90, 92))

    def test_resolve_dataset_path_blocks_parent_escape(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset = root / "sample"
            dataset.mkdir()
            self.assertEqual(resolve_dataset_path(root, "sample"), dataset.resolve())
            with self.assertRaises(ValueError):
                resolve_dataset_path(root, "../escape")

    def test_count_dataset_images_ignores_hidden_and_non_images(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset = Path(temp_dir)
            (dataset / "cats").mkdir()
            (dataset / "dogs").mkdir()
            (dataset / "cats" / "a.jpg").write_bytes(b"x")
            (dataset / "dogs" / "b.png").write_bytes(b"x")
            (dataset / "dogs" / "notes.txt").write_text("ignore", encoding="utf-8")
            (dataset / ".hidden").mkdir()
            (dataset / ".hidden" / "c.jpg").write_bytes(b"x")
            self.assertEqual(count_dataset_images(dataset), 2)

    def test_parse_summary_text_extracts_final_metrics(self) -> None:
        summary = """
        | Dataset | 606 images (train=424, val=90, test=92) |
        | Best val accuracy | 0.333 (round 5) |
        | Test accuracy | 0.272 |
        | Total training time | 271.9s |
        """
        parsed = parse_summary_text(summary)
        self.assertEqual(parsed["dataset_total_images"], 606)
        self.assertEqual(parsed["train_images"], 424)
        self.assertEqual(parsed["val_images"], 90)
        self.assertEqual(parsed["test_images"], 92)
        self.assertEqual(parsed["best_round"], 5)
        self.assertAlmostEqual(parsed["best_val_accuracy"], 0.333)
        self.assertAlmostEqual(parsed["test_accuracy"], 0.272)
        self.assertAlmostEqual(parsed["total_training_seconds"], 271.9)


if __name__ == "__main__":
    unittest.main()
