import copy
import json
from pathlib import Path
import tempfile
import unittest

from package_split import load_split, validate_training_rows


class PackageSplitTests(unittest.TestCase):
    def setUp(self):
        self.split = dict(schema="coo-package-split-v1", seed=42,
                          eligible=["Core", "Core-Tests", "Tools"],
                          benchmark=["Core"], train=["Core-Tests", "Tools"])

    def load(self, split):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "split.json"
            path.write_text(json.dumps(split))
            return load_split(path)

    def test_complete_partition_preserves_package_siblings(self):
        self.assertEqual(self.load(self.split), self.split)
        validate_training_rows([{"group": "Core-Tests"}, {"group": "Tools"}], self.split)

    def test_rejects_overlap_missing_extra_duplicate_and_empty_packages(self):
        for names in (["Core", "Core-Tests", "Tools"], ["Tools"],
                      ["Core-Tests", "Tools", "Unknown"], ["Tools", "Tools"], []):
            with self.subTest(names=names):
                split = copy.deepcopy(self.split)
                split["train"] = names
                with self.assertRaises(ValueError):
                    self.load(split)

    def test_benchmark_unknown_or_disguised_rows_fail_before_training(self):
        for row in ({"group": "Core"}, {"group": "Unknown"}, {},
                    {"group": "Tools", "package": "Core"}):
            with self.subTest(row=row), self.assertRaises(ValueError):
                validate_training_rows([row], self.split)


if __name__ == "__main__":
    unittest.main()
