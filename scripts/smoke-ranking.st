"Run smoke-ranking-export.st first. Requires the local ONNX service.
Set COO_SMOKE_LM=1 to also call the real 0.5B FIM model on this tiny corpus."
| source fixture directory summaries strategies |
source := FileLocator workingDirectory / 'src'.
(TonelReader on: source fileName: 'ExtendedHeuristicCompletion-Benchmarks') snapshot install.
fixture := (Object << #CooRankingSmokeFixture) package: 'CooRanking-Smoke'; install.
fixture compile: 'example
	| collection |
	collection := OrderedCollection new.
	^ collection size'.
directory := FileLocator workingDirectory / 'benchmark-ranking-smoke-results'.
directory ensureCreateDirectory.
strategies := #(neuralRank10 neuralRank20 neuralRank30 neuralRank50).
(Smalltalk os environment at: 'COO_SMOKE_LM' ifAbsent: [ '' ]) = '1' ifTrue: [
	strategies := strategies , #(adaptiveRank05B) ].
summaries := OrderedCollection new.
{ CooBenchRunnerMessage. CooBenchRunnerVariables } do: [ :runnerClass |
	| runner baseline kind |
	kind := runnerClass = CooBenchRunnerMessage ifTrue: [ 'messages' ] ifFalse: [ 'variables' ].
	runner := runnerClass new package: fixture package;
		baseline: #heuristicsDependency; others: strategies; run; yourself.
	baseline := runner results at: #heuristicsDependency.
	({ #heuristicsDependency } , strategies) do: [ :strategy |
		| benchmark summary |
		benchmark := runner results at: strategy.
		2 to: 8 do: [ :prefix |
			(baseline totalEntriesPerPrefixSize: prefix) = (benchmark totalEntriesPerPrefixSize: prefix)
				ifFalse: [ self error: 'Population changed' ] ].
		summary := (Smalltalk globals at: #CooRankingReport) summaryFor: strategy runs: { runner }.
		summary at: #kind put: kind.
		summaries add: summary.
		(benchmark isKindOf: (Smalltalk globals at: #CooNeuralRerankBenchmarks)) ifTrue: [
			benchmark exportRecordsTo: directory / (kind, '-', strategy asString, '.jsonl') ].
		Stdio stdout nextPutAll: kind; nextPutAll: ' / '; print: strategy;
			nextPutAll: ': '; print: (summary at: #count); nextPutAll: ' observations; matching baseline'; lf ] ].
(directory / 'results.json') writeStreamDo: [ :out | out truncate; nextPutAll: (STONJSON toString: summaries asArray) ].
Stdio stdout nextPutAll: 'SMOKE ONLY: one package, one class, one method; no quality claim'; lf.
