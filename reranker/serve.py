"""Loopback-only ONNX scoring service. Never generates candidates or reads targets."""
import argparse
import hashlib
import json
import math
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import numpy as np
import onnxruntime as ort
from features import SCHEMA, encode, probabilities


class Runtime:
    def __init__(self, directory):
        directory = Path(directory)
        self.metadata = json.loads((directory / "metadata.json").read_text())
        if self.metadata["schema"] != SCHEMA:
            raise ValueError("Unsupported model schema")
        self.model_id = hashlib.sha256((directory / "ranker.onnx").read_bytes()).hexdigest()
        options = ort.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        self.session = ort.InferenceSession(str(directory / "ranker.onnx"), sess_options=options,
                                           providers=["CPUExecutionProvider"])

    def rank(self, request):
        start = time.perf_counter()
        inputs = encode(request)
        feature_ms = (time.perf_counter() - start) * 1000
        start = time.perf_counter()
        logits = self.session.run(None, inputs)[0] if request["candidates"] else np.array([])
        p = probabilities(logits)
        inference_ms = (time.perf_counter() - start) * 1000
        order = np.argsort(-p, kind="stable")
        entropy = -sum(float(v) * math.log(float(v)) for v in p if v > 0)
        return {"schema": SCHEMA, "modelId": self.model_id,
                "scores": [[request["candidates"][i]["name"], float(p[i])] for i in order],
                "margin": float(p[order[0]] - p[order[1]]) if len(p) > 1 else float(bool(len(p))),
                "entropy": entropy / math.log(len(p)) if len(p) > 1 else 0.0,
                "inference_ms": inference_ms, "feature_ms": feature_ms,
                "fusionTrained": self.metadata.get("fusionTrained", False)}


def server(runtime, port):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/metadata":
                self.send_error(404)
                return
            body = json.dumps({"modelId": runtime.model_id,
                               "packageSplit": runtime.metadata.get("packageSplit")}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            try:
                if self.path != "/rank":
                    self.send_error(404)
                    return
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 1_000_000:
                    raise ValueError("Invalid request size")
                result = runtime.rank(json.loads(self.rfile.read(length)))
                body = json.dumps(result, allow_nan=False).encode()
                self.send_response(200)
            except (ValueError, KeyError, TypeError) as error:
                body = json.dumps({"error": str(error)}).encode()
                self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_):
            pass

    return HTTPServer(("127.0.0.1", port), Handler)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    runtime = Runtime(args.model)
    print(f"Serving {runtime.model_id} at http://127.0.0.1:{args.port}/rank", flush=True)
    server(runtime, args.port).serve_forever()
