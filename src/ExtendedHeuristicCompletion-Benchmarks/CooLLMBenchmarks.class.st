"
Uses the same callsites, prefixes (2..8), exact-match target and MRR accounting
as the heuristic benchmarks (class references for the variables category).
Candidates come from CooLLMCandidateSampler: one-token samples, keeping the
leading name of prefix + token when it is a distinct real class or selector.
The target's rank among the candidates is scored. A prefix that yields fewer
than ten real names in twenty attempts is scored on the names it did yield, so
every strategy measures the same callsites and prefixes. Validation uses the
image vocabulary only, never the target.
"
Class {
	#name : 'CooLLMBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records', 'sampler' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'initialization' }
CooLLMBenchmarks >> initialize [
	super initialize.
	name := 'LLM (1 token)'.
	client := CooLLMClient default copy.
	kind := #messages.
	records := OrderedCollection new
]

{ #category : 'accessing' }
CooLLMBenchmarks >> client: aClient [
	client := aClient.
	sampler := nil
]

{ #category : 'accessing' }
CooLLMBenchmarks >> kind: aSymbol [
	(#(messages variables) includes: aSymbol) ifFalse: [ self error: 'Unknown completion kind' ].
	kind := aSymbol.
	sampler := nil
]

{ #category : 'accessing' }
CooLLMBenchmarks >> records [
	^ records
]

{ #category : 'accessing' }
CooLLMBenchmarks >> sampler [
	^ sampler ifNil: [ sampler := CooLLMCandidateSampler new client: client; kind: kind; yourself ]
]

{ #category : 'accessing' }
CooLLMBenchmarks >> sampler: aSampler [
	sampler := aSampler
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
		| prefix snapshot startTime startMemory sample rank record |
		startTime := self startTimeMeasurement.
		startMemory := self startMemoryMeasurement.
		prefix := target first: size.
		snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
		record := Dictionary new
			at: #snapshot put: snapshot;
			at: #expected put: target;
			yourself.
		records add: record.
		sample := [ self sampler candidatesFor: snapshot ] on: Error do: [ :error |
			record at: #error put: error messageText.
			error pass ].
		record at: #request put: (sample at: #request);
			at: #attempts put: (sample at: #attempts);
			at: #candidates put: (sample at: #candidates);
			at: #complete put: (sample at: #complete).
		rank := (sample at: #candidates) indexOf: target.
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
