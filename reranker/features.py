"""Versioned, target-blind preprocessing shared by training and serving."""
import hashlib
import math
import re

import numpy as np

SCHEMA = "coo-ranking-v1"
SOURCES = ["CoSelfMessageHeuristic", "CoSuperMessageHeuristic",
           "CoTypedReceiverMessageHeuristic", "CoInitializeInferencedMessageHeuristic",
           "CoLiteralMessageHeuristic", "CoGlobalVariableMessageHeuristic",
           "CoVariableWithTypeNameMessageHeuristic", "CoDependencyMessageHeuristics",
           "CoUnknownMessageHeuristic", "CoGlobalVariablesHeuristic", "llm", "unknown"]
RECEIVERS = ["self", "super", "variable", "literal", "global", "unknown"]
NUM_FEATURES = 9 + len(SOURCES) + len(RECEIVERS)
INPUTS = ["context_ids", "candidate_ids", "features"]


def tokens(source):
    return re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+|[^\w\s]", source)


def encode(request):
    if request.get("schema") != SCHEMA:
        raise ValueError("Unsupported feature schema")
    if request.get("kind") not in ("messages", "variables"):
        raise ValueError("Invalid completion kind")
    candidates = request["candidates"]
    if not isinstance(candidates, list) or len(candidates) > 51:
        raise ValueError("Expected at most 51 candidates")
    prefix = request["prefix"]
    if not isinstance(prefix, str) or not 2 <= len(prefix) <= 8:
        raise ValueError("Invalid prefix")
    names = [c["name"] for c in candidates]
    if any(not isinstance(n, str) or not n or not n.startswith(prefix) for n in names):
        raise ValueError("Candidates must be nonempty prefix matches")
    if len(set(names)) != len(names):
        raise ValueError("Duplicate candidates")
    source = request["sourcePrefix"]
    if not isinstance(source, str):
        raise ValueError("Invalid context")
    recent = tokens(source)[-64:]
    ids = [1 + int.from_bytes(hashlib.blake2b(t.encode(), digest_size=4).digest(), "big") % 4095
           for t in recent]
    context = np.array([ids + [0] * (64 - len(ids))], dtype=np.int64)
    chars = np.zeros((len(candidates), 64), dtype=np.int64)
    values = []
    for i, c in enumerate(candidates):
        name, rank = c["name"], c["rank"]
        if isinstance(rank, bool) or not isinstance(rank, int) or not 0 <= rank <= 50:
            raise ValueError("Invalid heuristic rank")
        raw = list(name.encode("utf-8")[:64])
        chars[i, :len(raw)] = [b + 1 for b in raw]
        values.append([
            1 / rank if rank else 0, len(prefix) / 8, min(len(name), 128) / 128,
            len(prefix) / len(name), float(prefix == name), float(c.get("lmAgreement", False)),
            float(request["kind"] == "variables"), math.log1p(source.count(name)),
            float(c.get("inferredType") is not None),
            *[float(c.get("heuristicSource", "unknown") == s) for s in SOURCES],
            *[float(request.get("receiverKind", "unknown") == r) for r in RECEIVERS],
        ])
    return dict(zip(INPUTS, [context, chars, np.array(values, dtype=np.float32).reshape(-1, NUM_FEATURES)]))


def request_from_row(row, k=None):
    """Allowlist: audit labels, suffix, class/package identity never reach the model."""
    request = {key: row[key] for key in
               ("schema", "kind", "prefix", "sourcePrefix", "receiverKind", "candidates")}
    if k is not None:
        request["candidates"] = [c for c in request["candidates"] if c["rank"] <= k]
    return request


def probabilities(logits):
    logits = np.asarray(logits, dtype=np.float64)
    if logits.ndim != 1 or not np.isfinite(logits).all():
        raise ValueError("Invalid model logits")
    if not len(logits):
        return logits
    exp = np.exp(logits - logits.max())
    return exp / exp.sum()
