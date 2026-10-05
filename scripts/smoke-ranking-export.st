"Exactly one package, one class, one method. No neural server or LM needed.
Use a disposable image; this script does not save it."
| source fixture directory summaries |
source := FileLocator workingDirectory / 'src'.
(TonelReader on: source fileName: 'ExtendedHeuristicCompletion-Benchmarks') snapshot install.
fixture := (Object << #CooRankingSmokeFixture) package: 'CooRanking-Smoke'; install.
fixture compile: 'example
	| collection |
	collection := OrderedCollection new.
	^ collection size'.
directory := FileLocator workingDirectory / 'benchmark-ranking-smoke-results'.
directory ensureCreateDirectory.
summaries := OrderedCollection new.
{ CooBenchRunnerMessage. CooBenchRunnerVariables } do: [ :runnerClass |
	| runner baseline recall kind |
	kind := runnerClass = CooBenchRunnerMessage ifTrue: [ 'messages' ] ifFalse: [ 'variables' ].
	runner := runnerClass new package: fixture package;
		baseline: #heuristicsDependency; others: #(candidateRecall); run; yourself.
	baseline := runner results at: #heuristicsDependency.
	recall := runner results at: #candidateRecall.
	2 to: 8 do: [ :prefix |
		(baseline totalEntriesPerPrefixSize: prefix) = (recall totalEntriesPerPrefixSize: prefix)
			ifFalse: [ self error: 'Population changed' ].
		(baseline mmrForPrefixSize: prefix) = (recall mmrForPrefixSize: prefix)
			ifFalse: [ self error: 'Provenance changed dependency top-ten ranking' ] ].
	(recall records anySatisfy: [ :row | (row at: 'candidates') anySatisfy: [ :c |
		(c at: 'heuristicSource') = 'unknown' ] ]) ifTrue: [ self error: 'Lost heuristic provenance' ].
	recall exportTrainingTo: directory / (kind, '-training.jsonl').
	summaries add: (((Smalltalk globals at: #CooRankingReport) summaryFor: #candidateRecall runs: { runner }) at: #kind put: kind; yourself).
	Stdio stdout nextPutAll: kind; nextPutAll: ': '; print: recall records size; nextPutAll: ' observations; matching baseline'; lf ].
(directory / 'recall.json') writeStreamDo: [ :out | out truncate; nextPutAll: (STONJSON toString: summaries asArray) ].
Stdio stdout nextPutAll: 'SMOKE ONLY: one package, one class, one method; not research results'; lf.
