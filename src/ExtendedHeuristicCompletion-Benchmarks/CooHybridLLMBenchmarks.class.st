"
Feeds ranked heuristic suggestions into the same FIM, one-token generation
and exact-match evaluation as CooLLMBenchmarks. The default inputs are the
top ten Dependency and Baseline candidates, merged without duplicate names.
The expected answer is never used to select, sort or repair the hints/output.
"
Class {
	#name : 'CooHybridLLMBenchmarks',
	#superclass : 'CooLLMBenchmarks',
	#instVars : [ 'heuristics' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'initialization' }
CooHybridLLMBenchmarks >> initialize [
	super initialize.
	name := 'Hybrid (heuristics + 1 token)'.
	self kind: #messages
]

{ #category : 'accessing' }
CooHybridLLMBenchmarks >> kind: aSymbol [
	| runner benchmarkClass |
	super kind: aSymbol.
	runner := kind = #messages
		ifTrue: [ CooBenchRunnerMessage new ]
		ifFalse: [ CooBenchRunnerVariables new ].
	benchmarkClass := kind = #messages
		ifTrue: [ CooStaticBenchmarksMessage ]
		ifFalse: [ CooStaticBenchmarksVariables ].
	heuristics := {
		#Dependency -> (benchmarkClass new builder: runner dependencyBuilder; yourself).
		#Baseline -> (benchmarkClass new builder: runner baselineBuilder; yourself) }
]

{ #category : 'accessing' }
CooHybridLLMBenchmarks >> heuristics: namedBenchmarks [
	"Ordered associations from a source label to a configured static benchmark.
	Set after #kind:, which installs the default sources."
	heuristics := namedBenchmarks
]

{ #category : 'benchmarks' }
CooHybridLLMBenchmarks >> enrichSnapshot: snapshot for: node [
	| candidates start |
	start := self startTimeMeasurement.
	candidates := self candidatesFor: node prefix: (snapshot at: #prefix).
	snapshot at: #heuristicMs put: self startTimeMeasurement - start.
	snapshot at: #contextPolicy put: 'prefix-only-structural-with-heuristics-v1';
		at: #heuristicSources put: (heuristics collect: [ :source | source key asString ]) asArray;
		at: #heuristicCandidates put: candidates;
		at: #context put: (snapshot at: #context) , (self contextForCandidates: candidates).
	^ snapshot
]

{ #category : 'benchmarks' }
CooHybridLLMBenchmarks >> candidatesFor: node prefix: prefix [
	"Use precisely the legacy prefix filter and top-ten fetch. Completion results
	are lazy: fetch them before restoring the AST, including when a source fails."
	| original position merged |
	original := node isMessage ifTrue: [ node selector ] ifFalse: [ node name ].
	position := node isMessage
		ifTrue: [ node keywordsIntervals first ]
		ifFalse: [ node start ].
	merged := OrderedCollection new.
	[
		node isMessage
			ifTrue: [ node selectorNode value: prefix ]
			ifFalse: [ node name: prefix ].
		heuristics do: [ :source |
			| completion entries |
			completion := source value buildCompletionFor: node atPosition: position.
			entries := source value fetchTopCandidatesFrom: completion usingPrefix: prefix.
			self merge: (entries collect: [ :entry | entry contents asString ])
				from: source key into: merged ]
	] ensure: [
		node isMessage
			ifTrue: [ node selectorNode value: original ]
			ifFalse: [ node name: original ] ].
	merged do: [ :hint | hint at: #ranks put: (hint at: #ranks) asArray ].
	^ merged asArray
]

{ #category : 'private' }
CooHybridLLMBenchmarks >> merge: names from: source into: merged [
	"Dependency order first, then previously unseen Baseline names. Retain each
	source's original rank, including shared candidates, for prompt/audit use."
	names withIndexDo: [ :candidate :rank |
		| hint |
		hint := merged detect: [ :each | (each at: #candidate) = candidate ]
			ifNone: [
				| newHint |
				newHint := Dictionary new
					at: #candidate put: candidate copy;
					at: #ranks put: OrderedCollection new;
					yourself.
				merged add: newHint.
				newHint ].
		(hint at: #ranks) add: (Dictionary new
			at: #source put: source asString;
			at: #rank put: rank;
			yourself) ]
]

{ #category : 'private' }
CooHybridLLMBenchmarks >> contextForCandidates: candidates [
	^ String streamContents: [ :out |
		out nextPutAll: '<|file_sep|>heuristic-candidates'; lf;
			nextPutAll: '"Ranked completion hints; suggestions may be incorrect.'; lf.
		candidates ifEmpty: [ out nextPutAll: 'No heuristic suggestions.'; lf ].
		candidates withIndexDo: [ :hint :index |
			out print: index; nextPutAll: '. ';
				nextPutAll: (hint at: #candidate); nextPutAll: ' ['.
			(hint at: #ranks) do: [ :rank |
				out nextPutAll: (rank at: #source); nextPutAll: ' rank '; print: (rank at: #rank) ]
				separatedBy: [ out nextPutAll: ', ' ].
			out nextPutAll: ']'; lf ].
		out nextPutAll: 'Continue the unfinished name at the cursor."'; lf ]
]

{ #category : 'accessing' }
CooHybridLLMBenchmarks >> completionLevel [
	super completionLevel.
	name := 'Hybrid (complete name)'
]
