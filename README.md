# HeuristicCompletion-Benchmarks

Compare the existing **Baseline** and **Dependency** strategies with **LLM (1 model token)**, for message selectors and uppercase variable/global names. The two heuristic implementations are unchanged.

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

This runs all three strategies for **messages and variables**, then creates `messages.png` and `variables.png`: black lines with distinct markers, a legend, prefix lengths 2–8, and Average MRR on a 0–1 axis, like the reference screenshot. It also exports CSV, text, LaTeX and LLM JSONL audit records. Re-exporting the retained `comparison` does not run inference again. Files in the chosen output directory are replaced on re-export.

`comparison at: #messages` and `comparison at: #variables` each contain the existing three-element result format: `{ runners. text. latex }`. For example:

```smalltalk
(((comparison at: #messages) first first) results at: #llmCompletion) records inspect.
```

The existing `CooBenchRunnerMessage necTests` and `CooBenchRunnerVariables necTests` entry points still work and now include the LLM strategy. Other package examples also include it. The base-class `CooBenchRunner necTests` is the new convenience entry point for both kinds.

For a different set of packages:

```smalltalk
comparison := CooBenchRunner compareMessagesAndVariablesFor: #('NECompletion').
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

For every callsite and prefix, `CooLLMContextSnapshot` captures class name, superclass, instance/class variable declarations, and the method source **before the completion**, followed by the typed prefix. Line endings are normalized to LF. The suffix is empty to model left-to-right typing. It sends neither the untyped target, subsequent source, nor the enclosing method body through a second context channel. Legitimate earlier source/declarations can naturally contain the same name. Snapshots contain no mutable AST references and the LLM never modifies the AST.

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
    others: #(heuristicsDependency llmCompletion);
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

A full run sends one request per eligible callsite/prefix. In the validation image, `NECompletion-Tests` requires **6,998 message requests and 136 variable requests**; the count depends on the image contents. Expect a substantially longer run than the heuristic benchmarks.
