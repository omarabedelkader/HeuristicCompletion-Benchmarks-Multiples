"""Listwise training with explicit package/project holdouts and ONNX export."""
import argparse
import hashlib
import json
import random
from pathlib import Path

import numpy as np
import torch
from features import SCHEMA, INPUTS, encode, request_from_row
from model import Ranker
from package_split import load_split, validate_training_rows


def split_rows(rows, validation_groups, test_groups):
    if set(validation_groups) & set(test_groups):
        raise ValueError("Validation and test groups overlap")
    groups = {r["group"] for r in rows}
    if not set(validation_groups + test_groups) <= groups:
        raise ValueError("Requested holdout groups absent from data")
    train, validation, test = [], [], []
    for r in rows:
        (test if r["group"] in test_groups else validation if r["group"] in validation_groups else train).append(r)
    if not train or not validation or not test:
        raise ValueError("Use at least three groups: nonempty train, validation and untouched test")
    return train, validation, test


def tensors(row):
    return tuple(torch.from_numpy(v) for v in encode(request_from_row(row)).values())


def validation_mrr(model, rows):
    scores = []
    with torch.inference_mode():
        for row in rows:
            names = [c["name"] for c in row["candidates"]]
            if not names:
                scores.append(0)
                continue
            order = np.argsort(-model(*tensors(row)).numpy(), kind="stable")[:10]
            ranked = [names[i] for i in order]
            scores.append(1 / (ranked.index(row["target"]) + 1) if row["target"] in ranked else 0)
    return sum(scores) / len(scores)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--validation-groups", nargs="+")
    parser.add_argument("--test-groups", nargs="+")
    parser.add_argument("--package-split", type=Path,
                        help="Train on all non-benchmark packages for fixed epochs; no test rows allowed")
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--width", type=int, choices=[16, 32, 64], default=32)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if args.epochs < 1:
        parser.error("epochs must be positive")
    if args.package_split:
        if args.validation_groups or args.test_groups:
            parser.error("--package-split cannot be combined with holdout group options")
    elif not args.validation_groups or not args.test_groups:
        parser.error("Provide --package-split or both --validation-groups and --test-groups")
    torch.set_num_threads(1)
    torch.manual_seed(args.seed)
    rng = random.Random(args.seed)
    rows = [json.loads(line) for line in args.data.read_text().splitlines() if line.strip()]
    split = load_split(args.package_split) if args.package_split else None
    if split:
        validate_training_rows(rows, split)
    # Reject mixed/broken exports before computing recall or training.
    for row in rows:
        encode(request_from_row(row))
    if not rows:
        raise ValueError("Empty training corpus")
    recall = {str(k): (sum(r["target"] in [c["name"] for c in r["candidates"] if 0 < c["rank"] <= k]
                          for r in rows) / len(rows)
                       if all(r.get("candidateLimit", 0) >= k for r in rows) else None)
              for k in [10, 20, 30, 50]}
    print(json.dumps({"candidateRecall": recall, "count": len(rows)}), flush=True)
    if split:
        train, validation, test = rows, [], []
    else:
        train, validation, test = split_rows(rows, args.validation_groups, args.test_groups)
    usable = [r for r in train if r["target"] in [c["name"] for c in r["candidates"]]]
    if not usable:
        raise ValueError("No positive candidates in training partition")
    model = Ranker(args.width)
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.001)
    best_score, best = -1, None
    for epoch in range(args.epochs):
        model.train()
        rng.shuffle(usable)
        for row in usable:
            target = [c["name"] for c in row["candidates"]].index(row["target"])
            optimizer.zero_grad()
            loss = torch.nn.functional.cross_entropy(model(*tensors(row))[None, :], torch.tensor([target]))
            loss.backward()
            optimizer.step()
        model.eval()
        if split:
            print(json.dumps({"epoch": epoch + 1, "trainingRows": len(train)}), flush=True)
            continue
        score = validation_mrr(model, validation)
        if score > best_score:
            best_score = score
            best = {k: v.detach().clone() for k, v in model.state_dict().items()}
        print(json.dumps({"epoch": epoch + 1, "validationMRR": score}), flush=True)
    if best is not None:
        model.load_state_dict(best)
    model.eval()
    args.output.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(model, tensors(usable[0]), str(args.output / "ranker.onnx"),
                      input_names=INPUTS, output_names=["logits"], opset_version=17,
                      dynamic_axes={"candidate_ids": {0: "candidates"}, "features": {0: "candidates"},
                                    "logits": {0: "candidates"}}, dynamo=False)
    metadata = dict(schema=SCHEMA, width=args.width, seed=args.seed,
                    epochs=args.epochs, selection="fixed-epochs" if split else "validation-MRR",
                    validationMRR=best_score if validation else None,
                    parameters=sum(p.numel() for p in model.parameters()),
                    dataSHA256=hashlib.sha256(args.data.read_bytes()).hexdigest(),
                    trainGroups=split["train"] if split else sorted({r["group"] for r in train}),
                    validationGroups=args.validation_groups or [],
                    testGroups=split["benchmark"] if split else args.test_groups,
                    trainingRows=len(train), trainingMisses=len(train) - len(usable),
                    validationRows=len(validation), testRows=len(test), candidateRecall=recall,
                    fusionTrained=any(c.get("lmAgreement", False) for r in usable for c in r["candidates"]))
    if split:
        metadata["packageSplit"] = split
        metadata["packagesWithoutRows"] = sorted(set(split["train"]) - {r["group"] for r in train})
        (args.output / "split.json").write_text(json.dumps(split, indent=2) + "\n")
    (args.output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    if not split:
        (args.output / "test.jsonl").write_text("".join(json.dumps(r) + "\n" for r in test))
    # Check the actual deployment runtime against PyTorch, including dynamic K.
    from serve import Runtime
    runtime = Runtime(args.output)
    for row in usable[:5]:
        for k in [1, 10, 20, 30, 50]:
            request = request_from_row(row, k)
            inputs = encode(request)
            with torch.inference_mode():
                expected = model(*(torch.from_numpy(v) for v in inputs.values())).numpy()
            np.testing.assert_allclose(runtime.session.run(None, inputs)[0], expected, rtol=1e-4, atol=1e-5)
    print("ONNX parity passed; benchmark packages excluded from training" if split
          else "ONNX parity passed; untouched test rows exported")


if __name__ == "__main__":
    main()
