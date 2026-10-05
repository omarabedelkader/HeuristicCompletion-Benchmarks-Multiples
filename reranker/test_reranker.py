import copy
import tempfile
import unittest
from pathlib import Path

import numpy as np
import torch
from features import encode, request_from_row, probabilities
from model import Ranker
from smoke_fixture import rows
from train import split_rows


class RankingTests(unittest.TestCase):
    def setUp(self):
        torch.set_num_threads(1)
        torch.manual_seed(42)
        self.rows = list(rows())

    def test_labels_and_audit_identity_do_not_change_features(self):
        a = self.rows[0]
        b = dict(a, target="secret", group="secret", snapshot={"expected": "secret"})
        for x, y in zip(encode(request_from_row(a)).values(), encode(request_from_row(b)).values()):
            np.testing.assert_array_equal(x, y)

    def test_group_split_keeps_all_prefixes_together(self):
        train, valid, test = split_rows(self.rows, ["smoke-validation"], ["smoke-test"])
        self.assertEqual({r["group"] for r in train}, {"smoke-train"})
        self.assertEqual({r["group"] for r in valid}, {"smoke-validation"})
        self.assertEqual({r["group"] for r in test}, {"smoke-test"})
        with self.assertRaises(ValueError):
            split_rows(self.rows, ["smoke-train"], ["smoke-train"])
        with self.assertRaises(ValueError):
            split_rows(train, [], [])

    def test_bad_candidates_are_rejected(self):
        row = copy.deepcopy(self.rows[0])
        row["candidates"].append(row["candidates"][0])
        with self.assertRaises(ValueError):
            encode(row)
        row = copy.deepcopy(self.rows[0])
        row["candidates"][0]["name"] = "differentPrefix"
        with self.assertRaises(ValueError):
            encode(row)

    def test_probabilities_are_stable_and_reject_nan(self):
        np.testing.assert_allclose(probabilities([10000, 10000]), [0.5, 0.5])
        self.assertEqual(len(probabilities([])), 0)
        with self.assertRaises(ValueError):
            probabilities([float("nan")])

    def test_listwise_training_learns_positive_not_at_rank_one(self):
        row = self.rows[0]
        inputs = tuple(torch.from_numpy(v) for v in encode(row).values())
        model = Ranker(16)
        optimizer = torch.optim.Adam(model.parameters(), lr=0.01)
        for _ in range(30):
            optimizer.zero_grad()
            loss = torch.nn.functional.cross_entropy(model(*inputs)[None, :], torch.tensor([3]))
            loss.backward()
            optimizer.step()
        self.assertEqual(int(model(*inputs).argmax()), 3)

    def test_onnx_dynamic_candidate_counts_match_torch(self):
        import onnxruntime as ort
        from features import INPUTS
        model = Ranker(16).eval()
        base = request_from_row(self.rows[0])
        inputs = encode(base)
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "ranker.onnx")
            torch.onnx.export(model, tuple(torch.from_numpy(v) for v in inputs.values()), path,
                              input_names=INPUTS, output_names=["logits"], dynamo=False, opset_version=17,
                              dynamic_axes={"candidate_ids": {0: "n"}, "features": {0: "n"}, "logits": {0: "n"}})
            session = ort.InferenceSession(path, providers=["CPUExecutionProvider"])
            for n in [1, 10, 20, 30, 50, 51]:
                request = copy.deepcopy(base)
                request["candidates"] = [dict(request["candidates"][0], name=f"size{i}", rank=min(i+1, 50)) for i in range(n)]
                values = encode(request)
                with torch.inference_mode():
                    expected = model(*(torch.from_numpy(v) for v in values.values())).numpy()
                np.testing.assert_allclose(session.run(None, values)[0], expected, rtol=1e-4, atol=1e-5)


if __name__ == "__main__":
    unittest.main()
