"
Uses the same callsites, prefixes (2..8), exact-match target and MRR accounting
as the heuristic benchmarks (class references for the variables category).
Candidates come from CooLLMBeamCompleter: a beam search over the model's
next-token log-probabilities that answers at most ten real class names or
selectors continuing the prefix, most probable first. The target's rank in
that list is scored, 0 when it is absent. A prefix with fewer than ten
reachable names is scored on the names found, so every strategy measures the
same callsites and prefixes. Validation uses the image vocabulary only, never
the target.
"
Class {
	#name : 'CooLLMBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records', 'completer' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'initialization' }
CooLLMBenchmarks >> initialize [
	super initialize.
	name := 'LLM (beam search)'.
	client := CooLLMClient default copy.
	kind := #messages.
	records := OrderedCollection new
]

{ #category : 'accessing' }
CooLLMBenchmarks >> client: aClient [
	client := aClient.
	completer := nil
]

{ #category : 'accessing' }
CooLLMBenchmarks >> kind: aSymbol [
	(#(messages variables) includes: aSymbol) ifFalse: [ self error: 'Unknown completion kind' ].
	kind := aSymbol.
	completer := nil
]

{ #category : 'accessing' }
CooLLMBenchmarks >> records [
	^ records
]

{ #category : 'accessing' }
CooLLMBenchmarks >> completer [
	^ completer ifNil: [ completer := CooLLMBeamCompleter new client: client; kind: kind; yourself ]
]

{ #category : 'accessing' }
CooLLMBenchmarks >> completer: aCompleter [
	completer := aCompleter
]

{ #category : 'running' }
CooLLMBenchmarks >> run [
	scope methodsDo: [ :method |
		method parseTree nodesDo: [ :node |
			(kind = #messages
				ifTrue: [ node isMessage ]
				ifFalse: [ CooStaticBenchmarksVariables isClassCompletionNode: node ])
				ifTrue: [ self benchCallsite: node atPosition: node start ] ] ]
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> benchCallsite: node atPosition: ignoredPosition [
	| target |
	target := node isMessage ifTrue: [ node selector asString ] ifFalse: [ node name ].
	2 to: (target size min: 8) do: [ :size |
		| prefix snapshot startTime startMemory completion rank record |
		startTime := self startTimeMeasurement.
		startMemory := self startMemoryMeasurement.
		prefix := target first: size.
		snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
		record := Dictionary new
			at: #snapshot put: snapshot;
			at: #expected put: target;
			yourself.
		records add: record.
		completion := [ self completer candidatesFor: snapshot ] on: Error do: [ :error |
			record at: #error put: error messageText.
			error pass ].
		#(request candidates scores requests steps complete) do: [ :key |
			record at: key put: (completion at: key) ].
		rank := (completion at: #candidates) indexOf: target.
		record at: #rank put: rank.
		self trackCompletionResultsFor: target atIndex: rank withPrefix: prefix.
		self logMemoryUsageSince: startMemory forPrefixSize: size.
		self logExecutionTimeSince: startTime forPrefixSize: size ]
]

{ #category : 'exporting' }
CooLLMBenchmarks >> exportRecordsTo: aPath [
	| file |
	file := aPath asFileReference.
	file writeStreamDo: [ :out |
		out truncate.
		records do: [ :record | out nextPutAll: (STONJSON toString: record); lf ] ].
	^ file
]
