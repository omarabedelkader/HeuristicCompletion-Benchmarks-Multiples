# HeuristicCompletion-Benchmarks

Compare **Baseline** and **Dependency** with four **one-token LLMs (0.5B, 1.5B, 3B and 7B)**, for message selectors (**Methods**) and class references (**Classes**). Each model also has a **deterministic hybrid** combining its independent prediction with the Dependency heuristic top ten. The heuristic candidate builders are unchanged; the Classes evaluation includes only uppercase globals whose resolved value is a class.

## Load

In the image where the existing benchmarks already work, load this checkout through Iceberg, or evaluate this to load the local production package:

```smalltalk
(TonelReader
    on: '/Users/omar/Desktop/HeuristicCompletion-Benchmarks-Multiples/src' asFileReference
    fileName: 'ExtendedHeuristicCompletion-Benchmarks') snapshot install.
```

The existing completion/dependency packages must already be installed, as before. The added client and PNG exporter use Zinc, STONJSON and Forms from Pharo; installing the Copilot UI or a plotting package is unnecessary.

Once these changes are published to GitHub, the usual load remains:

```smalltalk
Metacello new
    githubUser: 'omarabedelkader'
    project: 'HeuristicCompletion-Benchmarks-Multiples'
    commitish: 'main' path: 'src';
    baseline: 'ExtendedHeuristicCompletionBenchmarks';
    load.
```

## Run both benchmarks and export publication results

Start your existing Ollama server with all four models installed. The default connection is `http://localhost:11434`. `CooBenchRunner class >> llmModels` centralizes these identifiers, verified against the local installation:

| Strategy | Ollama model |
| --- | --- |
| `llm05B` | `pharo-llm/Qwen2.5-Coder-SFT:0.5B` |
| `llm15B` | `pharo-llm/Qwen2.5-Coder-SFT:1.5B` |
| `llm3B` | `pharo-llm/Qwen2.5-Coder-SFT:3b` |
| `llm7B` | `pharo-llm/Qwen2.5-Coder-SFT:7b` |

Change that method if your server uses different model names. Each strategy copies the default client and overrides only its model; it never changes the shared default client.

Evaluate in a Playground:

```smalltalk
| comparison files |
comparison := CooBenchRunner necTests.
files := CooBenchRunner
    export: comparison
    to: '/Users/omar/Desktop/HeuristicCompletion-Benchmarks-Multiples/benchmark-results'.
files inspect.
```

This runs ten strategies for each category, then writes exactly three publication artifacts:

- `results-table.tex`: twenty rows (Methods and Classes × ten strategies), with observation-weighted MRR for Average and prefixes 2–8. Include `\usepackage{multirow}` in the containing LaTeX document.
- `performance.png`: mean Pharo memory change per completion in MB on X and mean completion latency in milliseconds on Y. Strategy colors distinguish the ten strategies; circles represent Methods and triangles represent Classes. There are twenty points when every strategy/category has observations.
- `dataset-summary.tex`: unique packages, classes and methods in the analyzed corpus.

The Average column and each scatter point weight all completion observations across packages and prefixes 2–8, rather than averaging per-prefix means. Memory uses the sum of recorded byte deltas divided by the completion count and 1,000,000 (MB). These are changes in `Smalltalk vm memorySize`, not peak memory, allocation volume, or Ollama RAM/VRAM; zero and negative deltas are preserved. Latency uses existing benchmark timings, including request/context overhead and any model loading during a request. Missing observations are `--` in the table and omitted from the plot; they are not zero scores.

Re-exporting the retained `comparison` does not run inference or recount a changed image. The three files are replaced on re-export. After loading updated code, regenerate the memory-axis graph with `CooBenchRunner export: comparison to: aDirectory` using your retained comparison; no new benchmark run is needed. Use a fresh publication directory if it contains reports from the older exporter; unrelated or older files are not deleted automatically.

`comparison at: #messages` and `comparison at: #variables` retain the existing three-element format: `{ runners. text. latex }`. `comparison at: #corpus` captures package/class/method counts before benchmarking. Corpus counts follow `CoBenchmarkPackage >> methodsDo:` in the loaded image, excluding anything outside its traversal (in the validation image, traits, extension methods and class-side methods). They count source entities, not completion attempts.

Raw LLM records stay available in memory and can be explicitly exported outside the publication directory:

```smalltalk
(((comparison at: #messages) first first) results at: #llm3B) records inspect.
"Optional audit export:"
(((comparison at: #messages) first first) results at: #llm3B)
    exportRecordsTo: '/tmp/messages-3b.jsonl'.
```

`CooBenchRunnerMessage necTests` and `CooBenchRunnerVariables necTests` each run all ten strategies for their category. The base-class `CooBenchRunner necTests` runs both categories and captures the corpus metadata needed for export.

For a different set of packages:

```smalltalk
comparison := CooBenchRunner compareMessagesAndVariablesFor: #('NECompletion').
```

To benchmark a random number of packages, replace `necTests` with `randomPackages:`:

```smalltalk
| comparison files |
comparison := CooBenchRunner randomPackages: 10. "Change 10 to 20, etc."
files := CooBenchRunner
    export: comparison
    to: '/Users/omar/Desktop/HeuristicCompletion-Benchmarks-Multiples/benchmark-results'.
files inspect.
```

This selects exactly that many distinct loaded packages containing methods in the benchmark scope. The same selection is used for Methods, Classes and all ten strategies. Empty packages and packages containing only methods outside that scope are excluded. The count must be a positive integer no larger than the eligible pool; invalid counts fail before inference.

Inspect the selected names with `comparison at: #packageNames`, or see the available pool with `CooBenchRunner eligiblePackageNames`. For a repeatable selection on the same pool, use:

```smalltalk
comparison := CooBenchRunner randomPackages: 10 seed: 42.
```

The seed is retained as `#selectionSeed`. Re-exporting uses the saved results without selecting new packages. Calling `randomPackages:` again starts a new selection and benchmark run. Larger packages can take much longer to benchmark than small ones.

## Model and template configuration

Configuration is separate from your editor's completion settings:

```smalltalk
CooLLMClient default
    baseUrl: 'http://localhost:11434';
    timeout: 120.
```

To explicitly reuse an already loaded `pharo-copilot` connection (including its remote authentication) and FIM template:

```smalltalk
CooLLMClient default useCopilotConnection.
```

The four pure LM and four hybrid strategies always select their models from `CooBenchRunner llmModels`, even when reusing a Copilot connection. The legacy `llmCompletion` selector remains available for explicitly running only `CooLLMClient default model`.

The raw FIM protocol follows `CoPCOllamaClient` in the reference project. Each request sets `stream: false`, `raw: true`, `num_predict: 1`, `temperature: 0`, `seed: 42`, `num_ctx: 8192`, and the FIM stop sequences. No model is downloaded, editor setting changed, or heuristic fallback invoked. See the [Ollama generation API](https://docs.ollama.com/api/generate) and [generation parameters](https://docs.ollama.com/modelfile).

The default template is:

```text
{{ .Context }}<|fim_prefix|>{{ .Prompt }}<|fim_suffix|>{{ .Suffix }}<|fim_middle|>
```

To change it, use `CooLLMClient default template: aString`. The supported literal placeholders are `{{ .Prompt }}`, `{{ .Suffix }}` and `{{ .Context }}`; this is not a Go template interpreter. The prompt slot is required. If the context slot is absent, context is prepended, as in Copilot. Substitution is a single pass, so placeholder-looking text inside source is preserved literally. Models with different special tokens need an appropriate template.

## Context snapshots and scoring

For every callsite and prefix, `CooLLMContextSnapshot` captures class name, superclass, instance/class variable declarations, and the method source **before the completion**, followed by the typed prefix. The FIM suffix starts **after the original completion node**, excluding the held-out target text while preserving subsequent source. Both source parts are normalized to LF. Structural context contains no second copy of the enclosing method body. Legitimate surrounding source/declarations can naturally contain the same name. Snapshots use the `fim-structural-v1` context policy, contain no mutable AST references, and the LLM never modifies the AST. Rerun LM and hybrid benchmarks to measure this policy; existing prefix-only results are unchanged.

Each audit record retains the snapshot, exact rendered prompt, model/options/template, raw response and token counts, candidate, expected answer and rank. The expected answer and method identity are audit metadata only, not prompt inputs. Records are retained in memory; long runs can consume substantial memory.

**One model token is not necessarily one complete Smalltalk name.** A token can contain only a subword, or whitespace/punctuation. The only candidate is `typedPrefix , generatedText`. It scores rank 1 only if it exactly matches the entire original selector/name; otherwise rank 0. There is no trimming, word extraction, resampling or hidden completion of the generated fragment. Consequently the LLM's MRR equals exact-match accuracy, while the heuristics can score at ranks 1–10.

Evaluation population:

- Prefix sizes are 2 through `min(name size, 8)`, including already complete short names. A model that keeps generating after a complete name can miss these cases.
- The internal `#variables` category now means uppercase global references bound to classes. Other globals such as `Smalltalk` and `Transcript`, uppercase locals, and class variables are excluded. Both heuristics, all four LLMs and all four hybrids use this same predicate. This is narrower than the previous uppercase-variable benchmark; rerun it before reporting Classes results.
- Keyword-message targets are full concatenated selectors, e.g. `at:put:`. The simulated prefix can be `at:p`; the held-out arguments and later keywords are not copied into the prompt. The suffix starts after the entire message node, including its arguments. This preserves the legacy selector-prefix task; faithful editor-style FIM would require an independent cursor offset and masking of held-out completion text.
- Across multiple packages, per-prefix MRR is weighted by callsite count. Prefixes with no observations are shown as `--`.

HTTP errors, missing models, malformed responses or a reported token count above one raise an error rather than becoming misleading accuracy misses. A runner retains its completed heuristic results and partial LM/hybrid diagnostics when interrupted; retain an explicit runner if you need to inspect it after an error:

```smalltalk
runner := CooBenchRunnerMessage new
    package: (PackageOrganizer default packageNamed: 'NECompletion-Tests');
    baseline: #heuristicsBaseline;
    others: #(heuristicsDependency llm05B llm15B llm3B llm7B hybrid05B hybrid15B hybrid3B hybrid7B);
    yourself.
runner run.
```

To run only the original strategies, use `others: #(heuristicsDependency)` in that example.

## Deterministic hybrid and diagnostics

`CooHybridBenchmarks` reuses the runners' `dependencyBuilder` configurations. For each original callsite and prefix it constructs the same `CooLLMContextSnapshot`, requests exactly one token, then temporarily changes the AST name to generate the heuristic top ten. `ensure:` restores the original name even if building or enumerating completions fails. The LM receives neither heuristic candidates nor the expected answer.

Fusion is `unique([lmCandidate] + heuristicCandidates)[:10]`, preserving order. Nonempty generation becomes exactly `prefix , content`, including whitespace or extra code. **Empty generated text inserts nothing**, even when the prefix already equals the target. This is an explicit fusion abstention policy: the unchanged pure LM baseline still scores `prefix , ''` against the target. There is no validation, repair, retry, learned weighting or target-aware fallback.

The additional strategies, in publication order after the pure LMs, are `hybrid05B`, `hybrid15B`, `hybrid3B`, and `hybrid7B`, labeled “Hybrid Dependency + [size]”. Each uses the corresponding entry in `CooBenchRunner llmModels`. Hybrid time and Pharo memory deltas cover the entire operation, including context creation, inference, heuristics, fusion and recordkeeping. External Ollama RAM/VRAM is not measured.

Records include `expected`, `prefix`, `snapshot`, `generation`, `lmCandidate`, `heuristicCandidates`, `finalCandidates`, `heuristicRank`, `hybridRank`, `rank`, and `lmCorrect`. Failed operations retain an `error` and propagate the exception without scoring a miss. JSONL export works like the pure LM export:

```smalltalk
| runs hybrid summary |
runs := (comparison at: #messages) first.
hybrid := runs first results at: #hybrid05B.
hybrid exportRecordsTo: '/tmp/hybrid-messages-05b.jsonl'.
summary := CooBenchmarkChart hybridSummaryFor: #hybrid05B runs: runs.
summary inspect.
```

The summary reports observation-weighted MRR, Accuracy@1/@3/@10, and these **overlapping diagnostic counts**:

- `lmRescues`: heuristic miss, inserted LM candidate correct.
- `lmPromotes`: heuristic target below rank one, LM correct.
- `lmAgrees` / `duplicateLM`: the inserted LM candidate was already in the heuristic list (whether correct or wrong).
- `lmHarms`: the target moves down, including eviction from rank ten to a miss.
- `bothMiss`: neither candidate source contains the target.
- `heuristicOnlySucceeds`: heuristics contain the target and the LM candidate is not correct.
- `unchanged`: target rank is unchanged.
- `unionHit` / `unionAccuracy`: target present in either candidate source **before truncation**. This is an analytical coverage upper bound, not a deployable strategy or an MRR score. Empty generation supplies no candidate under this fusion policy.

Counts describe the target rank or candidate overlap; they are not mutually exclusive categories. Summaries exclude failed events from accuracy denominators and count them separately as `errors`. Missing accuracy is `nil`, not zero.

For any strategy, including both baselines, use `CooBenchmarkChart accuracyAt: 3 for: #heuristicsDependency runs: runs`. Per-prefix top-k accuracy remains available through `accuracyForCompletionIndex: (1 to: 3) withPrefixSize: 2`. `CooBenchmarkChart performancePointFor: #hybrid05B runs: runs` supplies weighted mean latency and memory; compare with `#heuristicsDependency` to compute the added cost. The three default publication artifacts remain MRR, memory/latency, and corpus counts; diagnostic exports are explicit.

## Validation

Run in a **disposable copy** of your working Pharo image, from the repository root:

```sh
pharo --headless /path/to/copy.image st --quit scripts/test.st
pharo --headless /path/to/copy.image st --quit scripts/smoke-llm.st
```

`test.st` loads and runs the existing regression tests plus the new offline tests. `smoke-llm.st` calls all four real Ollama models for both pure LM and hybrid on a tiny fixture package and exports the three artifacts to `benchmark-smoke-results`; those results are smoke-test measurements, not NECompletion results. Neither script saves the image. The baseline also exposes a `Tests` group.

A full run sends one request per eligible callsite/prefix **for each of the four models, once for pure LM and once for hybrid**. The total depends on the image contents. The full NECompletion experiment can take substantially longer than the tiny smoke test.

## Opt-in neural reranking and adaptive completion

The original ten strategies and three publication artifacts remain the default.
The new strategies are explicit: `candidateRecall`, `neuralRank10`,
`neuralRank20`, `neuralRank30`, `neuralRank50`, and `adaptiveRank05B`, available
on both message and class-reference runners. None is added to `necTests` or
`randomPackages:` automatically. The original LM-first hybrids remain useful
comparison baselines; their fusion semantics have not changed.

The new path is dependency candidates → tiny neural scores → top ten. The
adaptive variant calls the existing one-token 0.5B FIM client only when the
normalized softmax entropy exceeds 0.8 or the top-two margin is below 0.2.
Empty candidate sets trigger fallback. These thresholds are experimental and
must be tuned on validation packages; softmax confidence is not calibrated
probability of correctness. A confident path makes no generative request.
A fallback result enters the union with rank zero and an `lmAgreement` feature;
the same ranker scores the union, with stable ties preserving input order.
Empty generation abstains. It never automatically inserts the LM at rank one.

**Preserving the benchmark:** prefixes 2–8, message/class-reference predicates,
exact-match scoring, and final top-ten MRR use the existing accounting. AST
changes are restored with `ensure:`. Model/transport errors are retained and
raised, not scored as misses. Candidate retrieval expands in batches of ten:
some Pharo images sort *each fetched batch*, so fetching fifty in one operation
would change the existing top ten. Batched expansion preserves that first ten
and produces nested pools for K=10/20/30/50. Provenance decorates a fresh runner
builder, retaining the first-producing heuristic by entry identity without
modifying completion entry classes or global heuristic settings.

### Experiment zero: recall and training export

No Python service or LM is needed for this step:

```smalltalk
| runner recall |
runner := CooBenchRunnerMessage new
    package: (PackageOrganizer default packageNamed: 'NECompletion');
    baseline: #heuristicsDependency;
    others: #(candidateRecall);
    run; yourself.
recall := runner results at: #candidateRecall.
(CooRankingReport summaryFor: #candidateRecall runs: { runner }) inspect.
recall exportTrainingTo: '/tmp/necompletion-messages.jsonl'.
```

Use `CooBenchRunnerVariables` for class references. Export each chosen package
separately, then concatenate JSONL files. Every row retains its package `group`,
masked source prefix, candidate names/ranks/provenance, candidate limit, and
training target. Candidate misses and empty lists are retained. Inference
requests use a strict allowlist and contain no target, package identity, audit
snapshot, method identity field, or FIM suffix. Only source **before the simulated
cursor**, including the typed prefix, becomes neural context.

The initial feature schema includes reciprocal rank, prefix/name lengths and
ratio, exact-prefix match, producing heuristic, receiver kind, completion kind,
LM agreement, preceding-source occurrence count, context subtokens and candidate
UTF-8 bytes. Unavailable inferred types are explicitly `nil`; project/package
usage-frequency indexes and richer type evidence are not fabricated. The
context encoder retains the last 64 subtokens, the candidate encoder the first
64 bytes; both use small embeddings and CNNs, followed by a 64-unit scoring MLP.
Widths 16/32/64 are supported.

### Train and serve

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r reranker/requirements.txt
.venv/bin/python reranker/train.py /tmp/corpus.jsonl ranking-models/rank32 \
  --validation-groups ValidationPackage --test-groups TestPackage \
  --epochs 10 --width 32
.venv/bin/python reranker/evaluate.py ranking-models/rank32 ranking-models/rank32/test.jsonl
.venv/bin/python reranker/serve.py ranking-models/rank32
```

Supply real group names from the exports. At least three distinct package/project
groups are required: training, validation and untouched test. There is no random
row split. If multiple packages belong to one project, assign their `group` to
that project **before splitting**. Listwise softmax training skips candidate
misses only for the loss, reports their count, and includes them as zero scores
in validation/evaluation. Recall is printed before training. Recall above the
exported candidate limit is unavailable, not inferred. Checkpoints are selected
using validation MRR; test rows are exported untouched. Model metadata records
groups, seed, feature schema, corpus SHA-256, parameter count and fusion-data
availability. Export checks compare PyTorch and ONNX scores.

The loopback service listens on `127.0.0.1:8765/rank` and uses ONNX Runtime CPU
with one inference thread. It returns every supplied candidate exactly once,
with softmax scores and a SHA-256 model identifier. Pharo rejects missing,
invented, duplicate or malformed candidates and invalid probabilities. No
model is silently downloaded or initialized by the benchmark. For another
endpoint, construct `CooNeuralRankerClient new baseUrl: ...`, pass it to
`CooNeuralRanker new client: ...`, and set the benchmark's `ranker:` explicitly.
The deployment interfaces follow the [PyTorch ONNX exporter](https://docs.pytorch.org/docs/stable/onnx.html)
and [ONNX Runtime API](https://onnxruntime.ai/docs/api/python/api_summary.html).

### Fusion data and adaptive evaluation

A dependency-only model has not learned how to interpret generated candidates.
Adaptive fallback therefore requires a model trained on LM union observations.
Bootstrap those observations using the explicit data collector (it calls 0.5B
for every row and does not require an existing neural model):

```smalltalk
| collector |
collector := CooFusionTrainingBenchmarks new
    kind: #messages;
    scope: (CoBenchmarkPackage on: (PackageOrganizer default packageNamed: 'TrainingPackage'));
    builder: CooBenchRunnerMessage new dependencyBuilder;
    run; yourself.
collector exportTrainingTo: '/tmp/dependency-training.jsonl'.
collector exportFusionTrainingTo: '/tmp/fusion-training.jsonl'.
```

Combine dependency and union rows from the selected packages before training;
their identical package groups keep both forms on the same side of the split.
Do not use collector timing as neural/adaptive performance. Already-run adaptive
benchmarks also support `exportFusionTrainingTo:` for later experiments.
To try a 1.5B fallback, configure a `CooAdaptiveHybridBenchmarks` instance with
`client: (CooLLMClient default copy model: (CooBenchRunner llmModels at: #llm15B); yourself)`.
Train/evaluate fusion against the same fallback model. The initial gate uses
margin/entropy; a learned acceptance or expected-utility gate is a subsequent
experiment, not claimed by this implementation.

With the appropriate service running:

```smalltalk
| runner strategies summaries best |
strategies := #(heuristicsDependency neuralRank10 neuralRank20 neuralRank30 neuralRank50 adaptiveRank05B).
runner := CooBenchRunnerMessage new
    package: (PackageOrganizer default packageNamed: 'HeldOutPackage');
    baseline: strategies first; others: strategies allButFirst;
    run; yourself.
summaries := strategies collect: [ :strategy |
    CooRankingReport summaryFor: strategy runs: { runner } ].
CooRankingReport exportStrategies: strategies runs: { runner } to: '/tmp/ranking-results.json'.
(CooRankingReport frontier: summaries) inspect.
best := CooRankingReport bestIn: summaries p95Budget: 100 memoryBudget: nil.
best inspect.
```

Aggregate multiple package runners in `runs:`; compare the same kind and matched
populations. Add `llm05B`/`hybrid05B` to the explicit strategy list to compare
always-on generation. Repeat with model widths 16/32/64 to sweep model size.
The standard publication exporter now includes recognized neural/adaptive rows
when those results are present. Its table retains Average and prefixes 2–8;
Methods/Classes multirow counts and the performance-plot legend expand
automatically. The ranking JSON exporter supplies the additional latency,
recall and gating diagnostics.

Summaries report observation-weighted MRR, Accuracy@1/@3/@10, mean latency,
nearest-rank P50/P95/P99, mean Pharo memory delta, measured candidate recall,
errors and fallback rate. Raw latency retention is the only change to shared
benchmark instrumentation; existing time totals/means are unchanged. Historical
runs without complete raw samples have `nil` percentiles. Memory delta is **not
process RAM**: a non-nil memory budget requires an independently measured
`processMemoryMB` in each summary, otherwise the strategy is ineligible. The
Pareto frontier maximizes MRR and minimizes mean end-to-end latency; budget
selection maximizes MRR subject to P95. `utilityFor:lambda:` supplies the optional
`MRR - lambda * ln(1 + meanLatencyMs)` score. Failed runs are ineligible.

Audit JSONL separates `candidateGenerationMs`, Pharo `featureExtractionMs`,
client `serializationMs`, `requestRoundTripMs`, server `feature_ms` and
`inference_ms`, plus optional `generationMs`, union construction `fusionMs`,
`fusionRanking` and end-to-end `totalMs`. The round trip **includes** server work;
do not add it to server inference again. `transportAndServerOverheadMs` is the
nonnegative residual after reported server feature/inference time, including
server JSON/scheduling overhead, not a pure network measurement. Python-only
evaluation explicitly excludes Pharo and HTTP; use Pharo total latency for UX
budgets. Service/model startup occurs before requests; first-inference effects
remain in the measured samples.

### One-package, one-class, one-method validation

Run from this checkout in a disposable image, without saving it:

```sh
pharo --headless /path/to/copy.image st --quit scripts/test.st
.venv/bin/python -m unittest discover -s reranker -v
pharo --headless /path/to/copy.image st --quit scripts/smoke-ranking-export.st
```

For an end-to-end plumbing check before a real corpus/model exists, train the
explicitly **synthetic smoke fixture** (never use it to claim completion quality):

```sh
.venv/bin/python reranker/smoke_fixture.py /tmp/ranking-synthetic.jsonl
.venv/bin/python reranker/train.py /tmp/ranking-synthetic.jsonl ranking-models/smoke \
  --validation-groups smoke-validation --test-groups smoke-test --epochs 3 --width 16
.venv/bin/python reranker/serve.py ranking-models/smoke
# In another terminal:
COO_SMOKE_LM=1 pharo --headless /path/to/copy.image st --quit scripts/smoke-ranking.st
```

Omit `COO_SMOKE_LM=1` to test only the four neural K values. Both smoke scripts
create exactly one fixture package, containing one class with one method. They
assert matching per-prefix populations; recall/export additionally asserts
baseline top-ten MRR and captured provenance. The fixture supplies five message
and seven class-reference observations per strategy. Results go into
`benchmark-ranking-smoke-results/`, separately from publication results. These
smoke measurements establish integration, not a quality gain or general recall
ceiling. Training a useful model and selecting thresholds requires the grouped
real corpus experiment described above.

### Shared package holdout: normal benchmarks and re-ranking

Load the `neural-ranking` branch as usual:

```smalltalk
Metacello new
  githubUser: 'omarabedelkader' project: 'HeuristicCompletion-Benchmarks-Multiples' commitish: 'neural-ranking' path: 'src';
  baseline: 'ExtendedHeuristicCompletionBenchmarks';
  load.
```

Select **once, before any benchmarks or training**, and save the split:

```smalltalk
| split |
split := CooBenchmarkSplit benchmarkPackages: 50 seed: 42.
split writeTo: 'experiment/split.json'.
```

The split contains exactly 50 benchmark packages and **every other eligible
package in the image** as training packages. Empty packages and packages without
methods in the benchmark traversal cannot produce examples and are not eligible.
This is a package holdout, not a project-family holdout. No families or remaining
packages are discarded. At least one eligible package must remain for training.
An existing split file cannot be overwritten; read it again for subsequent steps.

Run the normal baseline, dependency, LLM completion and LLM hybrid benchmarks:

```smalltalk
| split comparison |
split := CooBenchmarkSplit readFrom: 'experiment/split.json'.
comparison := CooBenchRunner normalBenchmarksForSplit: split.
CooBenchRunner export: comparison to: 'experiment/results'.
```

Export training data from the remaining packages, for both completion kinds:

```smalltalk
| split |
split := CooBenchmarkSplit readFrom: 'experiment/split.json'.
CooBenchRunner exportTrainingForSplit: split to: 'experiment/training.jsonl'.
```

From the repository directory, train and start the service (adjust paths if the
Pharo working directory differs):

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r reranker/requirements.txt
.venv/bin/python reranker/train.py experiment/training.jsonl experiment/model \
  --package-split experiment/split.json --epochs 10 --width 32 --seed 42
.venv/bin/python reranker/serve.py experiment/model
```

This mode trains for fixed epochs on all remaining packages. It does not read
benchmark examples or use them for validation/model selection. It rejects any
training row whose package is outside the saved training partition. The model
metadata retains the complete split and identifies packages producing no rows.
Candidate misses remain in the corpus, while only positive candidate examples
can contribute to the ranking loss. The earlier explicit train/validation/test
CLI mode remains available for other experiments.

With the service running, benchmark the **same saved packages**:

```smalltalk
| split comparison |
split := CooBenchmarkSplit readFrom: 'experiment/split.json'.
comparison := CooBenchRunner rerankerBenchmarksForSplit: split.
CooBenchRunner exportReranker: comparison to: 'experiment/results'.
```

The runner checks the serving model's split before inference. All split-based
operations also reject changes to the eligible package pool: use the original
image throughout, or create a new experiment after changing loaded packages.
The four pure neural strategies (`neuralRank10`, `neuralRank20`, `neuralRank30`,
`neuralRank50`) write `results-table-re-ranker.tex`; normal exports retain their
existing names.

For optional offline evaluation, collect test examples **after training** into
another file with `CooBenchRunner exportTestForSplit: split to:
'experiment/test.jsonl'`, then run:

```bash
.venv/bin/python reranker/evaluate.py experiment/model experiment/test.jsonl
```

The sibling `heuristics-vs-llm` repository automates this workflow:

```bash
BENCHMARK_PACKAGE_COUNT=50 ./pipeline-normal-bench.sh
./pipeline-re-ranker-bench.sh
```

Both scripts share `experiment/split.json`, the image, and a frozen source
snapshot. Choose a new `EXPERIMENT_DIR` for a new selection. The normal models
must already be available in Ollama; the re-ranker service is managed by its
pipeline. These scripts use the local benchmark checkout when present, otherwise
the GitHub `neural-ranking` branch (which must contain these changes).

The older `randomPackages:` and `randomPackagesForReranker:` methods remain
available for independent exploratory runs. Each makes a fresh selection: do
**not** use them for the shared-holdout experiment; use the split-based methods
above instead.

### The same publication table, with additional rows

To keep exactly the six strategies in the original table and add the five new
ones, run this after starting a trained, fusion-capable ranker service:

```smalltalk
| comparison |
comparison := CooBenchRunner
    compareMessagesAndVariablesFor: #('HeldOutPackage')
    strategies: #(heuristicsBaseline heuristicsDependency
        llm05B llm15B llm3B llm7B
        neuralRank10 neuralRank20 neuralRank30 neuralRank50 adaptiveRank05B).
CooBenchRunner export: comparison to: 'benchmark-results'.
```

`results-table.tex` has **11 Methods rows and 11 Classes rows**, with the same
caption, columns, three-decimal MRR values, observation-weighted Average and
prefixes 2–8. The added labels are NeuralRank-10, NeuralRank-20, NeuralRank-30,
NeuralRank-50 and AdaptiveRank + 0.5B. `\multirow` and separator lines are generated
from the selected row count. Missing observations remain `--`.

To also retain the four always-on hybrids, pass
`CooBenchmarkChart publicationStrategies , CooBenchmarkChart rankingStrategies`
as the strategy list: that produces 15 rows per category. Existing calls without
an explicit strategy list still run the original ten strategies. The exporter
also automatically appends known ranking strategies found in retained comparison
results, so re-exporting does not trigger inference. An explicit
`#publicationStrategies` entry in a retained comparison controls its row order
and subset. Corpus summary and performance PNG retain the same filenames; the
PNG includes the additional strategies and expands its legend as needed.

To run **all 15 strategies together on exactly one package, one class and one
method**, start the ranker service and Ollama with all four configured models,
then run in a disposable Pharo image:

```sh
pharo --headless /path/to/copy.image st --quit scripts/smoke-all-strategies.st
```

This verifies the corpus size and every per-prefix population, runs both Methods
and Classes, and saves `results-table.tex` (30 rows), `performance.png`,
`dataset-summary.tex`, `metrics.json` and per-strategy audit JSONL in
`benchmark-all-strategies-smoke-results/`. Completed strategy metrics and audit
records are saved incrementally. The fixture has five message and seven class
observations per strategy; Methods prefixes 5–8 have no observations and show
`--`. If using the synthetic smoke ranker, the neural/adaptive measurements are
integration checks, not evidence of trained-model completion quality.
