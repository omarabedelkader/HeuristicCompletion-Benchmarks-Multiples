"
Uses the same callsites, prefixes (2..8), exact-match target and MRR accounting
as the heuristic benchmarks (class references for the variables category). The sole candidate is typed prefix + generated text.
One model token may be a subword, so an incomplete name is correctly a miss.
No AST mutation, autocomplete fallback, sampling loop or target-aware repair.
"
Class {
	#name : 'CooLLMBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records' ],
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
	client := aClient
]

{ #category : 'accessing' }
CooLLMBenchmarks >> kind: aSymbol [
	(#(messages variables) includes: aSymbol) ifFalse: [ self error: 'Unknown completion kind' ].
	kind := aSymbol
]

{ #category : 'accessing' }
CooLLMBenchmarks >> records [
	^ records
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
		| prefix snapshot startTime startMemory generation candidate rank record |
		startTime := self startTimeMeasurement.
		startMemory := self startMemoryMeasurement.
		prefix := target first: size.
		snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
		record := Dictionary new
			at: #snapshot put: snapshot;
			at: #expected put: target;
			yourself.
		records add: record.
		generation := [ client generateFor: snapshot ] on: Error do: [ :error |
			record at: #error put: error messageText.
			error pass ].
		"The response is an insertion at the cursor, not a replacement name.
		Do not trim whitespace or silently extract a word from generated code."
		candidate := prefix , (generation at: #content).
		rank := candidate = target ifTrue: [ 1 ] ifFalse: [ 0 ].
		record at: #generation put: generation;
			at: #candidate put: candidate;
			at: #rank put: rank.
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
