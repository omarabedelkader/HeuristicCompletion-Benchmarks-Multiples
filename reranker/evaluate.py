"""Offline K sweep on held-out data. Timings exclude Pharo/HTTP; use Pharo reports for UX."""
import argparse
import json
import time
from pathlib import Path

import numpy as np
from features import request_from_row
from serve import Runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path)
    parser.add_argument("data", type=Path)
    args = parser.parse_args()
    runtime = Runtime(args.model)
    rows = [json.loads(s) for s in args.data.read_text().splitlines() if s.strip()]
    forbidden = set(runtime.metadata["trainGroups"] + runtime.metadata["validationGroups"])
    if not rows or any(r["group"] in forbidden for r in rows):
        raise ValueError("Evaluation requires nonempty data disjoint from train/validation groups")
    if "packageSplit" in runtime.metadata:
        benchmark = set(runtime.metadata["packageSplit"]["benchmark"])
        if any(r["group"] not in benchmark for r in rows):
            raise ValueError("Evaluation rows must belong to the saved benchmark packages")
    summaries = []
    for k in [10, 20, 30, 50]:
        if any(r.get("candidateLimit", 0) < k for r in rows):
            continue  # Unmeasured recall is never reported as a measured ceiling.
        ranks, recall, union_recall, elapsed, inference = [], [], [], [], []
        for row in rows:
            request = request_from_row(row, k)
            start = time.perf_counter()
            result = runtime.rank(request)
            elapsed.append((time.perf_counter() - start) * 1000)
            inference.append(result["inference_ms"])
            union_recall.append(row["target"] in [c["name"] for c in request["candidates"]])
            names = [c["name"] for c in request["candidates"] if c["rank"] > 0]
            recall.append(row["target"] in names)
            names = [c[0] for c in result["scores"][:10]]
            ranks.append(names.index(row["target"]) + 1 if row["target"] in names else 0)
        summaries.append(dict(k=k, count=len(rows), modelId=runtime.model_id,
                              timingScope="Python preprocessing + ONNX; no Pharo or HTTP",
                              candidateRecall=float(np.mean(recall)),
                              unionCandidateRecall=float(np.mean(union_recall)),
                              mrr=float(np.mean([1 / r if r else 0 for r in ranks])),
                              **{f"accuracyAt{n}": float(np.mean([0 < r <= n for r in ranks])) for n in [1, 3, 10]},
                              meanMs=float(np.mean(elapsed)), inferenceMeanMs=float(np.mean(inference)),
                              **{f"p{p}Ms": float(np.percentile(elapsed, p, method="inverted_cdf")) for p in [50, 95, 99]}))
    print(json.dumps(summaries, indent=2))


if __name__ == "__main__":
    main()
