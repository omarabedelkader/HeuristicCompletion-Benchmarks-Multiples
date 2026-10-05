"""Synthetic training fixture ONLY. Never use this model to report completion quality."""
import json
import sys
from features import SCHEMA


def rows():
    for group, names in [("smoke-train", ["size", "sin", "signed", "sizeInMemory"]),
                         ("smoke-validation", ["collect:", "copy", "copyFrom:to:"]),
                         ("smoke-test", ["detect:", "deepCopy", "default"])]:
        for target in names:
            for agreement in [False, True]:
                yield dict(schema=SCHEMA, group=group, candidateLimit=50, kind="messages", prefix=target[:2],
                           sourcePrefix="example ^ self " + target[:2], receiverKind="self", target=target,
                           candidates=[dict(name=n, rank=i + 1, heuristicSource="CoSelfMessageHeuristic",
                                            lmAgreement=agreement and n == names[-1], inferredType=None)
                                       for i, n in enumerate(names)])


if __name__ == "__main__":
    with open(sys.argv[1], "w") as stream:
        for row in rows():
            stream.write(json.dumps(row) + "\n")
