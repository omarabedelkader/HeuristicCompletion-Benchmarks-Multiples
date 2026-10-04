# HeuristicCompletion-Benchmarks

Compare **Baseline**, **Dependency**, **LLM (1 model token)** and **Hybrid (heuristics + LLM)**, for message selectors and uppercase variable/global names. The original heuristic algorithms and their ordering are preserved; the hybrid reuses their builder configurations.

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

## Run both benchmarks and generate the images

Start your existing Ollama server with the model installed. The default connection is `http://localhost:11434`, using `pharo-llm/Qwen2.5-Coder-SFT:q4_K_M`, matching the Copilot reference project.

Evaluate in a Playground:

```smalltalk
| comparison files |
comparison := CooBenchRunner necTests.
files := CooBenchRunner
    export: comparison
    to: '/Users/omar/Desktop/HeuristicCompletion-Benchmarks-Multiples/benchmark-results'.
files inspect.
```

This runs all four strategies for **messages and variables**, then creates `messages.png` and `variables.png`: black lines with distinct markers, a legend, prefix lengths 2–8, and Average MRR on a 0–1 axis, like the reference screenshot. The hybrid uses an X marker. It also exports CSV, text, LaTeX and separate plain-LLM/hybrid JSONL audit records. Re-exporting the retained `comparison` does not run inference again. Files in the chosen output directory are replaced on re-export. Previously computed three-strategy results must be rerun to measure the hybrid.

`comparison at: #messages` and `comparison at: #variables` each contain the existing three-element result format: `{ runners. text. latex }`. For example:

```smalltalk
(((comparison at: #messages) first first) results at: #llmCompletion) records inspect.
```

The existing `CooBenchRunnerMessage necTests` and `CooBenchRunnerVariables necTests` entry points still work and now include the LLM and hybrid strategies. Other package examples also include both. The base-class `CooBenchRunner necTests` is the convenience entry point for both kinds.

For a different set of packages:

```smalltalk
comparison := CooBenchRunner compareMessagesAndVariablesFor: #('NECompletion').
```

## Hybrid: give heuristic information to the model

For every prefix, `CooHybridLLMBenchmarks` fetches the top 10 **Dependency** suggestions and the top 10 **Baseline** suggestions using the same builders and case-sensitive prefix filter as the original benchmarks. It keeps Dependency order first, appends previously unseen Baseline names, and retains both source ranks for shared names. There are at most 20 unique hints. No expected answer is used to choose or reorder them.

The merged hints become an additional context section **before the FIM prompt**, for example:

```text
<|file_sep|>heuristic-candidates
"Ranked completion hints; suggestions may be incorrect.
1. yourself [Dependency rank 1, Baseline rank 3]
2. yourOtherMethod [Baseline rank 4]
Continue the unfinished name at the cursor."
```

The rank values above are illustrative. Actual hints and ranks are saved in each snapshot's `heuristicCandidates` field and in the exact request prompt. The context slot is already supported by the default and custom templates, so hybrid hints reach the model even when a template relies on prepended context.

The model then generates at most **one model token**, with the same options and exact-match scoring as the plain LLM. A hint containing the correct answer does not itself earn a successful score; the model must produce the correct continuation. Empty hint sets still make one model request. There is no reranking-only shortcut or heuristic fallback.

Candidate fetching temporarily assigns the typed prefix to the AST node, just as the legacy benchmarks do, and restores it with `ensure:` even if fetching fails. It runs against the existing heuristic AST/environment; no method bodies are added to the model prompt. A correct name may legitimately appear among the hints. Heuristic failures are recorded and raised before contacting the model, rather than silently becoming an empty list.

Inspect the hybrid's audit records with:

```smalltalk
(((comparison at: #messages) first first) results at: #hybridCompletion) records inspect.
```

Exports include `messages-1-hybrid.jsonl` and `variables-1-hybrid.jsonl` (the number identifies the package in a multi-package run). CSV, text, LaTeX and both PNGs include the hybrid as a separate strategy.

An explicit runner can select the desired strategies with `others: #(heuristicsDependency llmCompletion hybridCompletion)`. To customize the hint sources on a standalone hybrid benchmark, send `heuristics:` **after** `kind:` with ordered associations from a label to a configured `CooStaticBenchmarksMessage` or `CooStaticBenchmarksVariables` instance. For example, to supply only Dependency hints:

```smalltalk
hybrid := CooHybridLLMBenchmarks new
    kind: #messages;
    heuristics: { #Dependency -> (CooStaticBenchmarksMessage new
        builder: CooBenchRunnerMessage new dependencyBuilder;
        yourself) };
    scope: (CoBenchmarkPackage on:
        (PackageOrganizer default packageNamed: 'NECompletion-Tests'));
    run;
    yourself.
```

## Model and template configuration

Configuration is separate from your editor's completion settings:

```smalltalk
CooLLMClient default
    model: 'pharo-llm/Qwen2.5-Coder-SFT:3b-q4_K_M';
    baseUrl: 'http://localhost:11434';
    timeout: 120.
```

To explicitly reuse an already loaded `pharo-copilot` connection (including its remote authentication), model and FIM template:

```smalltalk
CooLLMClient default useCopilotConnection.
```

The raw FIM protocol follows `CoPCOllamaClient` in the reference project. Each request sets `stream: false`, `raw: true`, `num_predict: 1`, `temperature: 0`, `seed: 42`, `num_ctx: 8192`, and the FIM stop sequences. No model is downloaded, editor setting changed, or heuristic fallback invoked. See the [Ollama generation API](https://docs.ollama.com/api/generate) and [generation parameters](https://docs.ollama.com/modelfile).

The default template is:

```text
{{ .Context }}<|fim_prefix|>{{ .Prompt }}<|fim_suffix|>{{ .Suffix }}<|fim_middle|>
```

To change it, use `CooLLMClient default template: aString`. The supported literal placeholders are `{{ .Prompt }}`, `{{ .Suffix }}` and `{{ .Context }}`; this is not a Go template interpreter. The prompt slot is required. If the context slot is absent, context is prepended, as in Copilot. Substitution is a single pass, so placeholder-looking text inside source is preserved literally. Models with different special tokens need an appropriate template.

## Context snapshots and scoring

For every callsite and prefix, `CooLLMContextSnapshot` captures class name, superclass, instance/class variable declarations, and the method source **before the completion**, followed by the typed prefix. Line endings are normalized to LF. The suffix is empty to model left-to-right typing. The plain snapshot sends neither the untyped target, subsequent source, nor the enclosing method body through a second context channel. Legitimate earlier source/declarations can naturally contain the same name. Snapshots contain no mutable AST references. The hybrid adds only the ranked hints described above.

Each audit record retains the snapshot, exact rendered prompt, model/options/template, raw response and token counts, candidate, expected answer and rank. The expected answer and method identity are audit metadata only, not prompt inputs. Records are held in memory until export; long runs can consume substantial memory.

**One model token is not necessarily one complete Smalltalk name.** A token can contain only a subword, or whitespace/punctuation. The only candidate is `typedPrefix , generatedText`. It scores rank 1 only if it exactly matches the entire original selector/name; otherwise rank 0. There is no trimming, word extraction, resampling or hidden completion of the generated fragment. Consequently the LLM's MRR equals exact-match accuracy, while the heuristics can score at ranks 1–10.

The legacy evaluation population is deliberately preserved:

- Prefix sizes are 2 through `min(name size, 8)`, including already complete short names. A model that keeps generating after a complete name can miss these cases.
- Variables mean uppercase names (globals/classes), not all local variables.
- Keyword-message targets are full concatenated selectors, e.g. `at:put:`. The simulated prefix can be `at:p`; the held-out arguments and later keywords are not copied into the prompt. This is the legacy selector-prefix task, not arbitrary code infilling.
- Across multiple packages, chart MRR is weighted by callsite count at each prefix. Prefixes with no observations are gaps and blank CSV scores.

HTTP errors, missing models, malformed responses or a reported token count above one raise an error rather than becoming misleading accuracy misses. A runner retains its completed heuristic results and partial LLM diagnostics when interrupted; retain an explicit runner if you need to inspect it after an error:

```smalltalk
runner := CooBenchRunnerMessage new
    package: (PackageOrganizer default packageNamed: 'NECompletion-Tests');
    baseline: #heuristicsBaseline;
    others: #(heuristicsDependency llmCompletion hybridCompletion);
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

`test.st` loads and runs the existing regression tests plus the new offline tests. `smoke-llm.st` calls real Ollama on a tiny fixture package and exports to `benchmark-smoke-results`; those plots are smoke-test measurements, not NECompletion results. Neither script saves the image. The baseline also exposes a `Tests` group.

A full run sends one request per eligible callsite/prefix **for each model strategy**. In the validation image, `NECompletion-Tests` requires **6,998 message requests and 136 variable requests per strategy**, or **14,268 total** with both plain LLM and hybrid; the count depends on the image contents. Expect a substantially longer run than the heuristic benchmarks.
