# HeuristicCompletion-Benchmarks

Compare **Baseline** and **Dependency** with four **one-token LLMs (0.5B, 1.5B, 3B and 7B)**, for message selectors (**Methods**) and class references (**Classes**). The heuristic candidate builders are unchanged; the Classes evaluation includes only uppercase globals whose resolved value is a class.

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

This runs six strategies for each category, then writes exactly three publication artifacts:

- `results-table.tex`: twelve rows (Methods and Classes × six strategies), with observation-weighted MRR for Average and prefixes 2–8. Include `\usepackage{multirow}` in the containing LaTeX document.
- `performance.png`: mean Pharo memory change per completion in MB on X and mean completion latency in milliseconds on Y. Strategy colors distinguish the six strategies; circles represent Methods and triangles represent Classes. There are twelve points when every strategy/category has observations.
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

`CooBenchRunnerMessage necTests` and `CooBenchRunnerVariables necTests` each run all six strategies for their category. The base-class `CooBenchRunner necTests` runs both categories and captures the corpus metadata needed for export.

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

This selects exactly that many distinct loaded packages containing methods in the benchmark scope. The same selection is used for Methods, Classes and all six strategies. Empty packages and packages containing only methods outside that scope are excluded. The count must be a positive integer no larger than the eligible pool; invalid counts fail before inference.

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

The four comparison strategies always select their models from `CooBenchRunner llmModels`, even when reusing a Copilot connection. The legacy `llmCompletion` selector remains available for explicitly running only `CooLLMClient default model`.

The raw FIM protocol follows `CoPCOllamaClient` in the reference project. Each request sets `stream: false`, `raw: true`, `num_predict: 1`, `temperature: 0`, `seed: 42`, `num_ctx: 8192`, and the FIM stop sequences. No model is downloaded, editor setting changed, or heuristic fallback invoked. See the [Ollama generation API](https://docs.ollama.com/api/generate) and [generation parameters](https://docs.ollama.com/modelfile).

The default template is:

```text
{{ .Context }}<|fim_prefix|>{{ .Prompt }}<|fim_suffix|>{{ .Suffix }}<|fim_middle|>
```

To change it, use `CooLLMClient default template: aString`. The supported literal placeholders are `{{ .Prompt }}`, `{{ .Suffix }}` and `{{ .Context }}`; this is not a Go template interpreter. The prompt slot is required. If the context slot is absent, context is prepended, as in Copilot. Substitution is a single pass, so placeholder-looking text inside source is preserved literally. Models with different special tokens need an appropriate template.

## Context snapshots and scoring

For every callsite and prefix, `CooLLMContextSnapshot` captures class name, superclass, instance/class variable declarations, and the method source **before the completion**, followed by the typed prefix. Line endings are normalized to LF. The suffix is empty to model left-to-right typing. It sends neither the untyped target, subsequent source, nor the enclosing method body through a second context channel. Legitimate earlier source/declarations can naturally contain the same name. Snapshots contain no mutable AST references and the LLM never modifies the AST.

Each audit record retains the snapshot, exact rendered prompt, model/options/template, raw response and token counts, candidate, expected answer and rank. The expected answer and method identity are audit metadata only, not prompt inputs. Records are retained in memory; long runs can consume substantial memory.

**One model token is not necessarily one complete Smalltalk name.** A token can contain only a subword, or whitespace/punctuation. The only candidate is `typedPrefix , generatedText`. It scores rank 1 only if it exactly matches the entire original selector/name; otherwise rank 0. There is no trimming, word extraction, resampling or hidden completion of the generated fragment. Consequently the LLM's MRR equals exact-match accuracy, while the heuristics can score at ranks 1–10.

Evaluation population:

- Prefix sizes are 2 through `min(name size, 8)`, including already complete short names. A model that keeps generating after a complete name can miss these cases.
- The internal `#variables` category now means uppercase global references bound to classes. Other globals such as `Smalltalk` and `Transcript`, uppercase locals, and class variables are excluded. Both heuristics and all four LLMs use this same predicate. This is narrower than the previous uppercase-variable benchmark; rerun it before reporting Classes results.
- Keyword-message targets are full concatenated selectors, e.g. `at:put:`. The simulated prefix can be `at:p`; the held-out arguments and later keywords are not copied into the prompt. This is the legacy selector-prefix task, not arbitrary code infilling.
- Across multiple packages, per-prefix MRR is weighted by callsite count. Prefixes with no observations are shown as `--`.

HTTP errors, missing models, malformed responses or a reported token count above one raise an error rather than becoming misleading accuracy misses. A runner retains its completed heuristic results and partial LLM diagnostics when interrupted; retain an explicit runner if you need to inspect it after an error:

```smalltalk
runner := CooBenchRunnerMessage new
    package: (PackageOrganizer default packageNamed: 'NECompletion-Tests');
    baseline: #heuristicsBaseline;
    others: #(heuristicsDependency llm05B llm15B llm3B llm7B);
    yourself.
runner run.
```

To run only the original strategies, use `others: #(heuristicsDependency)` in that example.

## Validation

Run in a **disposable copy** of your working Pharo image, from the repository root:

```sh
pharo --headless /path/to/copy.image st --quit scripts/test.st
pharo --headless /path/to/copy.image st --quit scripts/smoke-llm.st
```

`test.st` loads and runs the existing regression tests plus the new offline tests. `smoke-llm.st` calls all four real Ollama models on a tiny fixture package and exports the three artifacts to `benchmark-smoke-results`; those results are smoke-test measurements, not NECompletion results. Neither script saves the image. The baseline also exposes a `Tests` group.

A full run sends one request per eligible callsite/prefix **for each of the four models**. The total depends on the image contents. The full NECompletion experiment can take substantially longer than the tiny smoke test.
