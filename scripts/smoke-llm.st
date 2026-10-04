"Real Ollama smoke test on a tiny package. Run only in a disposable image:
pharo --headless /path/to/copy.image st --quit scripts/smoke-llm.st
Exports real measurements (not NECompletion results) to benchmark-smoke-results."
| source fixture comparison files |
source := FileLocator workingDirectory / 'src'.
(TonelReader on: source fileName: 'ExtendedHeuristicCompletion-Benchmarks') snapshot install.
fixture := (Object << #CooLLMSmokeFixture) package: 'CooLLM-Smoke'; install.
fixture compile: 'example
	| collection |
	collection := OrderedCollection new.
	collection add: 1.
	^ collection yourself'.
comparison := CooBenchRunner compareMessagesAndVariablesFor: #('CooLLM-Smoke').
files := CooBenchRunner export: comparison to: 'benchmark-smoke-results'.
files do: [ :file | Stdio stdout nextPutAll: file fullName; lf ].
#(messages variables) do: [ :kind |
	| runner llm baseline |
	runner := (comparison at: kind) first first.
	llm := runner results at: #llmCompletion.
	baseline := runner results at: #heuristicsBaseline.
	2 to: 8 do: [ :prefix |
		(llm totalEntriesPerPrefixSize: prefix) = (baseline totalEntriesPerPrefixSize: prefix)
			ifFalse: [ self error: 'LLM and baseline populations differ' ] ].
	Stdio stdout nextPutAll: kind asString; nextPutAll: ': ';
		print: llm records size; nextPutAll: ' real one-token requests'; lf ].
