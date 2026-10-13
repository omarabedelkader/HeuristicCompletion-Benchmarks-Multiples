"
Dependency heuristics propose the candidates; the language model only
reorders them. The heuristic top ten, the code context and the list itself go
to CooLLMBeamReranker, which scores every name by beam search over the
model's next-token log-probabilities. The final list is a permutation of the
heuristic list, so the hybrid never gains or loses a candidate: it can only
promote or demote the target. Targets are used only for scoring and
post-ranking diagnostics.
"
Class {
	#name : 'CooHybridBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records', 'reranker' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Hybrid',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Hybrid'
}

{ #category : 'initialization' }
CooHybridBenchmarks >> initialize [
	super initialize.
	name := 'Hybrid (Dependency reranked by LLM)'.
	client := CooLLMClient default copy.
	records := OrderedCollection new.
	self kind: #messages
]

{ #category : 'accessing' }
CooHybridBenchmarks >> client: aClient [
	client := aClient.
	reranker := nil
]

{ #category : 'accessing' }
CooHybridBenchmarks >> kind: aSymbol [
	(#(messages variables) includes: aSymbol) ifFalse: [ self error: 'Unknown completion kind' ].
	kind := aSymbol.
	reranker := nil
]

{ #category : 'accessing' }
CooHybridBenchmarks >> reranker [
	^ reranker ifNil: [ reranker := CooLLMBeamReranker new client: client; kind: kind; yourself ]
]

{ #category : 'accessing' }
CooHybridBenchmarks >> reranker: aReranker [
	reranker := aReranker
]

{ #category : 'accessing' }
CooHybridBenchmarks >> records [
	^ records
]

{ #category : 'running' }
CooHybridBenchmarks >> run [
	scope methodsDo: [ :method |
		method parseTree nodesDo: [ :node |
			(kind = #messages
				ifTrue: [ node isMessage ]
				ifFalse: [ CooStaticBenchmarksVariables isClassCompletionNode: node ])
				ifTrue: [ self benchCallsite: node atPosition: (node isMessage
					ifTrue: [ node keywordsIntervals first ]
					ifFalse: [ node start ]) ] ] ]
]

{ #category : 'benchmarks' }
CooHybridBenchmarks >> buildCompletionFor: node atPosition: position [
	^ builder
		node: node;
		completionContext: ((node isMessage
			ifTrue: [ CoBenchmarkContext new ]
			ifFalse: [ CoBenchmarkVariableContext new ])
			callsite: node; position: position; yourself);
		buildCompletion
]

{ #category : 'benchmarks' }
CooHybridBenchmarks >> heuristicCandidatesFor: node atPosition: position prefix: prefix [
	| original |
	original := node isMessage ifTrue: [ node selectorNode value ] ifFalse: [ node name ].
	[
		node isMessage
			ifTrue: [ node selectorNode value: prefix ]
			ifFalse: [ node name: prefix ].
		^ ((self fetchTopCandidatesFrom: (self buildCompletionFor: node atPosition: position)
			usingPrefix: prefix) collect: [ :each | each contents asString ]) asArray
	] ensure: [
		node isMessage
			ifTrue: [ node selectorNode value: original ]
			ifFalse: [ node name: original ] ]
]

{ #category : 'benchmarks' }
CooHybridBenchmarks >> benchCallsite: node atPosition: position [
	| target |
	target := node isMessage ifTrue: [ node selector asString ] ifFalse: [ node name ].
	2 to: (target size min: 8) do: [ :size |
		| prefix snapshot startTime startMemory heuristics rerank final rank record |
		startTime := self startTimeMeasurement.
		startMemory := self startMemoryMeasurement.
		prefix := target first: size.
		snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
		record := Dictionary new
			at: #snapshot put: snapshot; at: #expected put: target;
			at: #prefix put: prefix; yourself.
		records add: record.
		[
			heuristics := self heuristicCandidatesFor: node atPosition: position prefix: prefix.
			record at: #heuristicCandidates put: heuristics.
			rerank := self reranker rerank: heuristics prefix: prefix snapshot: snapshot.
			final := (rerank at: #ranking) first: (10 min: (rerank at: #ranking) size)
		] on: Error do: [ :error |
			record at: #error put: error messageText.
			error pass ].
		rank := final indexOf: target.
		record
			at: #finalCandidates put: final;
			at: #scores put: (rerank at: #scores);
			at: #requests put: (rerank at: #requests);
			at: #steps put: (rerank at: #steps);
			at: #endsWithoutLogprobs put: (rerank at: #endsWithoutLogprobs);
			at: #contextPolicy put: (rerank at: #contextPolicy);
			at: #rank put: rank; at: #hybridRank put: rank;
			at: #heuristicRank put: (heuristics indexOf: target).
		self addDiagnosticsTo: record.
		self trackCompletionResultsFor: target atIndex: rank withPrefix: prefix.
		self logMemoryUsageSince: startMemory forPrefixSize: size.
		self logExecutionTimeSince: startTime forPrefixSize: size ]
]

{ #category : 'diagnostics' }
CooHybridBenchmarks >> addDiagnosticsTo: record [
	"Reranking keeps the candidate set, so a heuristic miss stays a miss."
	| heuristicRank hybridRank |
	heuristicRank := record at: #heuristicRank.
	hybridRank := record at: #hybridRank.
	record
		at: #promoted put: (heuristicRank > 0 and: [ hybridRank < heuristicRank ]);
		at: #demoted put: (heuristicRank > 0 and: [ hybridRank > heuristicRank ]);
		at: #unchanged put: heuristicRank = hybridRank;
		at: #heuristicMiss put: heuristicRank = 0
]

{ #category : 'diagnostics' }
CooHybridBenchmarks >> diagnosticSummary [
	"Failed operations are excluded from scored observations."
	| completed summary |
	completed := records select: [ :record | record includesKey: #rank ].
	summary := Dictionary new
		at: #count put: completed size;
		at: #errors put: (records count: [ :record | record includesKey: #error ]);
		at: #requests put: (completed inject: 0 into: [ :sum :record | sum + (record at: #requests) size ]);
		yourself.
	#(promoted demoted unchanged heuristicMiss)
		do: [ :key | summary at: key put: (completed count: [ :record | record at: key ]) ].
	^ summary
]

{ #category : 'exporting' }
CooHybridBenchmarks >> exportRecordsTo: aPath [
	| file |
	file := aPath asFileReference.
	file writeStreamDo: [ :out |
		out truncate.
		records do: [ :record | out nextPutAll: (STONJSON toString: record); lf ] ].
	^ file
]
