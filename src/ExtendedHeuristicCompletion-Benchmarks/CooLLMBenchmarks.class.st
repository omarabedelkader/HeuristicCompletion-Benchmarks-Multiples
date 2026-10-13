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

With validating: false the completer answers what the model generates without
checking it against the image. Either way the benchmark counts, per prefix
size, the candidates answered and how many of them are real names.
"
Class {
	#name : 'CooLLMBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records', 'completer', 'validating', 'generated', 'valid' ],
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
	validating := true.
	generated := Dictionary new.
	valid := Dictionary new.
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
CooLLMBenchmarks >> validating: aBoolean [
	validating := aBoolean.
	name := aBoolean ifTrue: [ 'LLM (beam search)' ] ifFalse: [ 'LLM (beam search, not validated)' ].
	completer := nil
]

{ #category : 'metrics' }
CooLLMBenchmarks >> generatedForPrefixSize: size [
	"Candidates the completer answered."
	^ generated at: size ifAbsent: [ 0 ]
]

{ #category : 'metrics' }
CooLLMBenchmarks >> validForPrefixSize: size [
	"Answered candidates that are real names of the image."
	^ valid at: size ifAbsent: [ 0 ]
]

{ #category : 'accessing' }
CooLLMBenchmarks >> records [
	^ records
]

{ #category : 'accessing' }
CooLLMBenchmarks >> completer [
	^ completer ifNil: [ completer := CooLLMBeamCompleter new
		client: client; kind: kind; validating: validating; yourself ]
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
		#(request candidates scores valid requests steps complete) do: [ :key |
			record at: key put: (completion at: key) ].
		generated at: size put: (self generatedForPrefixSize: size) + (completion at: #candidates) size.
		valid at: size put: (self validForPrefixSize: size) + (completion at: #valid).
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
