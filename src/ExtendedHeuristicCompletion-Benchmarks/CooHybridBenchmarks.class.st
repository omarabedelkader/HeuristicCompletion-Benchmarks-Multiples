"
Independent one-token LM generation followed by dependency heuristic completion.
Fusion is target-blind: unique(LM + heuristic top ten), truncated to ten.
Empty generated text inserts nothing; all other text is preserved verbatim.
Targets are used only for scoring and post-prediction diagnostics.
"
Class {
	#name : 'CooHybridBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Hybrid',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Hybrid'
}

{ #category : 'initialization' }
CooHybridBenchmarks >> initialize [
	super initialize.
	name := 'Hybrid (Dependency + LLM)'.
	client := CooLLMClient default copy.
	records := OrderedCollection new.
	self kind: #messages
]

{ #category : 'accessing' }
CooHybridBenchmarks >> client: aClient [
	client := aClient
]

{ #category : 'accessing' }
CooHybridBenchmarks >> kind: aSymbol [
	(#(messages variables) includes: aSymbol) ifFalse: [ self error: 'Unknown completion kind' ].
	kind := aSymbol
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

{ #category : 'fusion' }
CooHybridBenchmarks >> fuseHeuristicCandidates: heuristicCandidates withLLMCandidate: lmCandidate [
	| merged |
	merged := OrderedCollection new.
	lmCandidate ifNotEmpty: [ merged add: lmCandidate ].
	heuristicCandidates do: [ :candidate |
		(merged includes: candidate) ifFalse: [ merged add: candidate ] ].
	^ (merged first: (10 min: merged size)) asArray
]

{ #category : 'benchmarks' }
CooHybridBenchmarks >> benchCallsite: node atPosition: position [
	| target |
	target := node isMessage ifTrue: [ node selector asString ] ifFalse: [ node name ].
	2 to: (target size min: 8) do: [ :size |
		| prefix snapshot startTime startMemory generation content lmCandidate heuristics final rank record |
		startTime := self startTimeMeasurement.
		startMemory := self startMemoryMeasurement.
		prefix := target first: size.
		snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
		record := Dictionary new
			at: #snapshot put: snapshot; at: #expected put: target;
			at: #prefix put: prefix; yourself.
		records add: record.
		[
			generation := client generateFor: snapshot.
			content := generation at: #content.
			lmCandidate := content ifEmpty: [ '' ] ifNotEmpty: [ prefix , content ].
			record at: #generation put: generation; at: #lmCandidate put: lmCandidate.
			heuristics := self heuristicCandidatesFor: node atPosition: position prefix: prefix.
			final := self fuseHeuristicCandidates: heuristics withLLMCandidate: lmCandidate
		] on: Error do: [ :error |
			record at: #error put: error messageText.
			error pass ].
		rank := final indexOf: target.
		record at: #heuristicCandidates put: heuristics;
			at: #finalCandidates put: final; at: #rank put: rank;
			at: #hybridRank put: rank; at: #heuristicRank put: (heuristics indexOf: target);
			at: #lmCorrect put: (lmCandidate = target).
		self addDiagnosticsTo: record.
		self trackCompletionResultsFor: target atIndex: rank withPrefix: prefix.
		self logMemoryUsageSince: startMemory forPrefixSize: size.
		self logExecutionTimeSince: startTime forPrefixSize: size ]
]

{ #category : 'diagnostics' }
CooHybridBenchmarks >> addDiagnosticsTo: record [
	"Overlapping flags, computed only after fusion. Rank zero is a miss,
	so losing rank ten to truncation is also harm."
	| heuristicRank hybridRank lmCorrect duplicate |
	heuristicRank := record at: #heuristicRank.
	hybridRank := record at: #hybridRank.
	lmCorrect := record at: #lmCorrect.
	duplicate := (record at: #lmCandidate) isNotEmpty and: [
		(record at: #heuristicCandidates) includes: (record at: #lmCandidate) ].
	record
		at: #lmRescues put: (heuristicRank = 0 and: [ lmCorrect ]);
		at: #lmPromotes put: (heuristicRank > 1 and: [ lmCorrect ]);
		at: #lmAgrees put: duplicate;
		at: #duplicateLM put: duplicate;
		at: #lmHarms put: (heuristicRank > 0 and: [ hybridRank = 0 or: [ hybridRank > heuristicRank ] ]);
		at: #bothMiss put: (heuristicRank = 0 and: [ lmCorrect not ]);
		at: #heuristicOnlySucceeds put: (heuristicRank > 0 and: [ lmCorrect not ]);
		at: #unchanged put: (heuristicRank = hybridRank);
		at: #unionHit put: (heuristicRank > 0 or: [ lmCorrect ])
]

{ #category : 'diagnostics' }
CooHybridBenchmarks >> diagnosticSummary [
	"Union is an analytical candidate-coverage upper bound, never a ranking policy.
	Failed operations are excluded from scored observations."
	| completed summary |
	completed := records select: [ :record | record includesKey: #rank ].
	summary := Dictionary new
		at: #count put: completed size;
		at: #errors put: (records count: [ :record | record includesKey: #error ]);
		yourself.
	#(lmRescues lmPromotes lmAgrees duplicateLM lmHarms bothMiss heuristicOnlySucceeds unchanged unionHit)
		do: [ :key | summary at: key put: (completed count: [ :record | record at: key ]) ].
	summary at: #unionAccuracy put: (completed ifEmpty: [ nil ] ifNotEmpty: [
		(summary at: #unionHit) / completed size asFloat ]).
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
