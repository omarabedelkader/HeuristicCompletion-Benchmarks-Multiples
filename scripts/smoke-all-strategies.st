"All 15 strategies on one package, one class, one method.
Requires Ollama's four configured models and a local ONNX ranker service.
Run in a disposable image; no image is saved."
| source fixture directory comparison strategies summaries corpus |
source := FileLocator workingDirectory / 'src'.
(TonelReader on: source fileName: 'ExtendedHeuristicCompletion-Benchmarks') snapshot install.
fixture := (Object << #CooAllStrategiesSmokeFixture) package: 'CooAllStrategies-Smoke'; install.
fixture compile: 'example
	| collection |
	collection := OrderedCollection new.
	^ collection size'.
directory := FileLocator workingDirectory / 'benchmark-all-strategies-smoke-results'.
directory ensureCreateDirectory.
strategies := (Smalltalk globals at: #CooBenchmarkChart) publicationStrategies ,
	(Smalltalk globals at: #CooBenchmarkChart) rankingStrategies.
corpus := CooBenchRunner corpusSummaryForPackageNames: #('CooAllStrategies-Smoke').
#(packages classes methods) do: [ :key |
	(corpus at: key) = 1 ifFalse: [ self error: 'Smoke corpus must contain exactly one ', key ] ].
comparison := Dictionary new
	at: #packageNames put: #('CooAllStrategies-Smoke');
	at: #publicationStrategies put: strategies;
	at: #corpus put: corpus; yourself.
summaries := OrderedCollection new.
{ #messages -> CooBenchRunnerMessage. #variables -> CooBenchRunnerVariables } do: [ :entry |
	| runner baseline results kind |
	kind := entry key.
	runner := entry value new package: fixture package; yourself.
	results := Dictionary new.
	strategies do: [ :strategy |
		| benchmark summary |
		Stdio stdout nextPutAll: 'RUN '; nextPutAll: kind asString;
			nextPutAll: ' / '; nextPutAll: strategy asString; lf.
		"Use the normal runner for each strategy and retain completed results.
		This exposes progress and saves audit records as each run finishes."
		runner baseline: strategy; others: #(); run.
		benchmark := runner results at: strategy.
		results at: strategy put: benchmark.
		strategy = #heuristicsBaseline ifTrue: [ baseline := benchmark ].
		2 to: 8 do: [ :prefix |
			(benchmark totalEntriesPerPrefixSize: prefix) = (baseline totalEntriesPerPrefixSize: prefix)
				ifFalse: [ self error: 'Strategy population differs from baseline' ] ].
		summary := (Smalltalk globals at: #CooRankingReport) summaryFor: strategy runs: { runner }.
		(summary at: #errors) = 0 ifFalse: [ self error: 'Benchmark contains errors' ].
		(summary at: #count) = (kind = #messages ifTrue: [ 5 ] ifFalse: [ 7 ])
			ifFalse: [ self error: 'Unexpected smoke observation count' ].
		summary at: #kind put: kind.
		summaries add: summary.
		(benchmark respondsTo: #exportRecordsTo:) ifTrue: [
			benchmark exportRecordsTo: directory / (kind asString, '-', strategy asString, '.jsonl') ].
		(directory / 'metrics.json') writeStreamDo: [ :out |
			out truncate; nextPutAll: (STONJSON toString: summaries asArray) ].
		Stdio stdout nextPutAll: 'PASS '; nextPutAll: kind asString;
			nextPutAll: ' / '; nextPutAll: strategy asString;
			nextPutAll: ': '; print: (summary at: #count); nextPutAll: ' matching observations'; lf ].
	runner results addAll: results.
	comparison at: kind put: { { runner }.
		CooBenchRunner stringResultForABenchCollection: { runner }.
		CooBenchRunner latexTableResultForABenchCollection: { runner } } ].
(CooBenchRunner export: comparison to: directory) do: [ :file |
	Stdio stdout nextPutAll: file fullName; lf ].
((directory / 'results-table.tex') contents lines count: [ :line | line beginsWith: '& ' ]) = 30
	ifFalse: [ self error: 'Expected 15 Methods and 15 Classes rows' ].
Stdio stdout nextPutAll: 'PASS: all 15 strategies; one package, one class, one method; 30 publication rows'; lf.
