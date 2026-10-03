# HeuristicCompletion-Benchmarks

Compare Baseline, Dependency, prompt-based LLM/hybrid completion, and a **candidate-constrained neural reranker**, for message selectors and uppercase variable/global names. The original heuristic builders and candidate ordering are preserved.

## Load

Use a Pharo image with the existing completion/dependency packages installed. Load this checkout through Iceberg, or evaluate:

```smalltalk
(TonelReader
    on: '/Users/omar/Desktop/HeuristicCompletion-Benchmarks-Multiples/src' asFileReference
    fileName: 'ExtendedHeuristicCompletion-Benchmarks') snapshot install.
```

The production package uses Zinc, STONJSON and Pharo Forms. Copilot and Python are not needed to run benchmarks or export CSV/JSONL and prefix-MRR PNGs. Python/Matplotlib is used only for the additional publication figures.

## Quick comparison

Start Ollama with your chosen model installed. The default remains `http://localhost:11434`, model `pharo-llm/Qwen2.5-Coder-SFT:q4_K_M`.

```smalltalk
| comparison files |
comparison := CooBenchRunner necTests.
files := CooBenchRunner export: comparison to: 'benchmark-results'.
files inspect.
```

This runs **Baseline, Dependency, one-token LLM, one-token prompt hybrid, and candidate reranking** for both messages and variables in `NECompletion-Tests`. Single-model convenience runs use `uncontrolled` residency: they do not claim the first request is warm. Use the model matrix below for explicitly conditioned runs.

Each comparison contains `#messages` and `#variables`, with the existing `{ runners. text. latex }` format. Exporting retained results makes no inference requests. Re-export replaces files. Records remain in memory until exported; large runs can use substantial memory.

## Three separate experiments

| Experiment | Strategy selectors | Output and quality |
| --- | --- | --- |
| Ranking | `heuristicsBaseline`, `heuristicsDependency`, `rerankingCompletion` | Up to 10 complete names; MRR and Recall@1/3/5/10 |
| Complete-name generation | `llmNameCompletion`, `hybridNameCompletion` | One name; exact match (equals MRR and Recall@1) |
| One-token generation | `llmCompletion`, `hybridCompletion` | Prefix plus at most one tokenizer token; exact match |

`llmCompletion` and `hybridCompletion` preserve the original one-token protocol: no trimming, extraction, fallback or repair. A model token may be only part of a name. These results measure a single decoding step, not unrestricted name completion.

Complete-name generation allows up to **64 model tokens** with server stop sequences for whitespace and source delimiters. It additionally extracts only the initial name continuation from the response, without trimming leading whitespace. Colons remain valid for concatenated message selectors (`at:put:`); they stop variable-name generation. A standalone benchmark can change the cap with `completionTokenLimit:` after `completionLevel`. The raw response and `truncated` flag retain evidence of reaching the cap; this is bounded generation, not a guarantee that every identifier finishes.

All neural requests use temperature 0, seed 42 and context limit 8192. Model tags, prompts, options, snapshots and raw responses are audited.

## Candidate reranking

`CooRerankingHybridBenchmarks` reuses the hybrid candidate extraction:

1. Fetch Dependency's top 10 and Baseline's top 10, using the legacy case-sensitive prefix filter.
2. Deduplicate names, keeping Dependency order first and retaining both source ranks.
3. Ask Qwen to return a JSON permutation of candidate IDs, constrained by an Ollama JSON schema.
4. Validate that every ID occurs exactly once. Blend reciprocal ranks and return the top 10 names.

The default score is:

```text
score(c) = alpha / neural_rank(c)
         + beta  / dependency_rank(c)
         + gamma / baseline_rank(c)
```

Default weights are `#(1 1 1)`. Missing heuristic ranks contribute zero. Ties preserve original candidate-union order. `weights:` accepts three nonnegative numbers with positive sum. **The neural score is reciprocal model-returned rank, not a token probability.** The ranking prompt contains source context and candidate IDs/names, not heuristic rank labels or the expected answer. Candidate presentation order can still influence the model.

The request has a separate 256-token budget for the JSON permutation. An empty union returns no suggestions and skips inference. Missing/duplicate/out-of-range IDs, malformed JSON, truncated invalid rankings, HTTP errors, and missing models raise errors. They are audited and never silently converted into heuristic fallback or ordinary accuracy misses. A valid output can only contain supplied names. Heuristic candidates are structurally informed suggestions, not a guarantee of type validity.

The following ablations are available:

- `neuralRerankingCompletion`: same Dependency+Baseline union, weights `#(1 0 0)`.
- `dependencyRerankingCompletion`: Dependency-only candidate set, weights `#(1 1 0)`.
- `rerankingCompletion`: Dependency+Baseline union, weights `#(1 1 1)`.

The existing prompt hybrid continues to put heuristic hints before its FIM prompt. Having the correct answer among those hints earns no credit unless its generated continuation matches the target.

AST prefix mutations are restored with `ensure:`. Candidate extraction never uses the expected answer to reorder suggestions. Reranking records include the candidate pool, original source ranks, model order, score for each candidate, weights and final top 10.

## Run the four-model matrix

```smalltalk
| matrix |
matrix := CooBenchRunner
    compareModels: CooLLMClient benchmarkModels
    messagesAndVariablesFor: #('NECompletion-Tests').
CooBenchRunner exportModels: matrix to: 'benchmark-results'.
```

`benchmarkModels` provides the requested explicit tags:

```smalltalk
#('pharo-llm/Qwen2.5-Coder-SFT:0.5B'
  'pharo-llm/Qwen2.5-Coder-SFT:1.5B'
  'pharo-llm/Qwen2.5-Coder-SFT:3b'
  'pharo-llm/Qwen2.5-Coder-SFT:7b')
```

Tags must already exist in your Ollama installation. No model is downloaded or silently substituted. Tags alone do not ensure equal quantization; use matching quantization variants for a controlled size study and retain their Ollama metadata with your report. The matrix uses explicit client copies, preserves `CooLLMClient default`, and shares the same Baseline/Dependency result objects across models rather than measuring them repeatedly.

The default matrix runs both generation experiments and blended reranking in the **warm** condition. To select ablations or run cold measurements separately:

```smalltalk
matrix := CooBenchRunner
    compareModels: CooLLMClient benchmarkModels
    messagesAndVariablesFor: #('NECompletion-Tests')
    strategies: #(rerankingCompletion neuralRerankingCompletion dependencyRerankingCompletion)
    latencyCondition: #cold.
```

A run can be large: every neural strategy makes one request per eligible callsite/prefix (except empty reranking pools). Start with a small fixture/package.

## Latency, quality and exports

CSV begins with the requested columns:

```text
package,strategy,model,prefix,count,mrr,total_ms,avg_ms
```

Additional columns contain experiment, residency condition, median, nearest-rank P95, Recall@1/3/5/10, mean Ollama total/load/prompt/decode times, heuristic extraction time, and mean Pharo memory delta. Missing measurements are blank, not fabricated zeros. Static strategy model identity is `none`. Matrix-level CSV includes shared static observations only once.

All strategies retain individual wall-time observations in milliseconds, measured with Pharo's microsecond clock. Timing ends when candidates are available, before quality scoring and bookkeeping. Static JSONL records contain target, prefix, rank and wall time; neural records also contain model, experiment, condition, snapshot, exact request/response, preparation response, candidate(s) and timings. Failed neural requests retain an error and elapsed time but do not enter quality or latency aggregates.

Ollama timing fields are retained in nanoseconds and converted to milliseconds:

- `ollamaTotalNs` / `ollamaTotalMs`: server total duration.
- `ollamaLoadNs` / `ollamaLoadMs`: loading duration.
- `promptEvalNs` / `promptEvalMs`, plus `promptTokens`: prompt evaluation.
- `generationNs` / `generationMs`, plus `generatedTokens`: decoding.
- `wallTimeMs`: full client completion request, including heuristic extraction and prompt construction.
- `heuristicMs`: candidate extraction for hybrids.

Missing server fields remain `nil`. Decode duration means one-step cost only when exactly one output token was generated. Pharo memory deltas are **not model RAM/VRAM or process peak memory**; measure those externally if needed.

Residency policies:

- `warm`: load the model with an empty prompt before the first measured request of each benchmark, retain it with `keep_alive: '5m'`.
- `cold`: request unloading immediately before each measured completion; the measured generation includes model loading. Unloading itself is excluded.
- `uncontrolled`: no preload or unload; report observed load duration without claiming warmth.

Preparation responses are audited separately from measured completions. Warm preload does not warm the actual source prompt/KV cache. Concurrent Ollama clients or a long idle interval can still change residency; keep load measurements and run conditions in the report.

Exports include `messages.csv`, `variables.csv`, prefix-MRR PNGs, text/LaTeX summaries, and one JSONL file per package/strategy. Existing `*-llm.jsonl` and `*-hybrid.jsonl` names are retained. Other files use strategy names. Matrix exports add `model-1/`, `model-2/`, etc., and `models.json` mapping their order to tags.

## Quality–latency and decomposition figures

```sh
python3 -m venv .venv-plots
.venv-plots/bin/pip install -r scripts/requirements-plots.txt
.venv-plots/bin/python scripts/plot-results.py benchmark-results
```

The script exports PNG and PDF figures under `benchmark-results/figures`, separately by completion kind, experiment and latency condition. Each shows quality versus mean E2E latency, the observed Pareto frontier, and stacked mean latency components. Ranking uses MRR; generation uses Recall@1/exact match. Static results appear as labeled reference points. Package/prefix aggregates are weighted by observation count. Use `--prefix 3` to plot one prefix length.

Missing decomposition telemetry is displayed as total E2E latency, not a zero segment. The residual segment includes remaining client/server work. Median/P95 are exported per prefix from individual samples; the plotting script does not average percentiles across groups.

## Context and evaluation population

Snapshots contain class/superclass and variable declarations, plus source before the completion and the typed prefix. Suffix is empty. Neither the untyped target nor following source is supplied through another context channel. Earlier source and declarations may legitimately mention the same name. The expected answer and method identity are audit metadata, not model inputs.

The legacy population remains unchanged:

- Prefix lengths 2 through `min(name size, 8)`, including fully typed short names.
- Variables are uppercase names (globals/classes), not all local variables.
- Keyword targets are full concatenated selectors, such as `at:put:`. This is the legacy selector-prefix task, not arbitrary code infilling.
- MRR across packages is weighted by callsite count; empty prefixes are blank/missing.

For custom clients/templates:

```smalltalk
CooLLMClient default
    model: 'pharo-llm/Qwen2.5-Coder-SFT:3b-q4_K_M';
    baseUrl: 'http://localhost:11434';
    timeout: 120.
```

`useCopilotConnection` explicitly reuses an installed Copilot connection. FIM generation supports literal `{{ .Context }}`, `{{ .Prompt }}`, and `{{ .Suffix }}` placeholders; replacement is single-pass and context is prepended if its slot is absent. Reranking uses a separate raw ranking prompt with a JSON schema, independent of the FIM template.

An explicit runner retains partial results after errors:

```smalltalk
runner := CooBenchRunnerMessage new
    package: (PackageOrganizer default packageNamed: 'NECompletion-Tests');
    baseline: #heuristicsBaseline;
    others: #(heuristicsDependency rerankingCompletion);
    latencyCondition: #warm;
    yourself.
runner run.
```

For only the original static strategies, use `others: #(heuristicsDependency)`.

## Validation

Run from the repository root in a **disposable copy** of your working Pharo image, including its matching `.changes` and `.sources` files:

```sh
pharo --headless /path/to/copy.image st --quit scripts/test.st
pharo --headless /path/to/copy.image st --quit scripts/smoke-experiments.st
python3 scripts/test_plot_results.py
```

The offline smoke runs two fake model identities through all experiments/ablations and exports under `benchmark-smoke-results/experiments`. Its figures are synthetic validation artifacts, never research results. `scripts/smoke-llm.st` runs the default comparison against real Ollama on a tiny fixture. Neither script saves the image.

Protocol references: [Ollama generate API and timing units](https://docs.ollama.com/api/generate), [structured outputs](https://docs.ollama.com/capabilities/structured-outputs), and [generation parameters](https://docs.ollama.com/modelfile).
