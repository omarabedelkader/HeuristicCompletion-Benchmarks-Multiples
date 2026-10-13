"
Uses the same callsites, prefixes (2..8), exact-match target and MRR accounting
as the heuristic benchmarks (class references for the variables category).
Candidates come from CooLLMCandidateSampler: one-token samples, keeping the
leading name of prefix + token when it is a distinct real class or selector.
The target's rank among the ten candidates is scored. A prefix that yields
fewer than ten real names in twenty attempts is skipped, logged and kept in
records. Validation uses the image vocabulary only, never the target.
"
Class {
	#name : 'CooLLMBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records', 'sampler' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'logging' }
CooLLMBenchmarks class >> logSkipped: record by: benchmarkName [
	"Skipped prefixes are not scored, so say so where the run is watched."
	Transcript crShow: (String streamContents: [ :out |
		out nextPutAll: benchmarkName; nextPutAll: ': skipped prefix ';
			print: ((record at: #snapshot) at: #prefix);
			nextPutAll: ' of '; print: (record at: #expected);
			nextPutAll: ' ('; print: (record at: #candidates) size;
			nextPutAll: ' of '; print: CooLLMCandidateSampler candidateCount;
			nextPutAll: ' real names in '; print: (record at: #attempts) size;
			nextPutAll: ' attempts)' ])
]

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

{ #category : 'diagnostics' }
CooLLMBenchmarks >> skippedRecords [
	^ records select: [ :record | record at: #skipped ifAbsent: [ false ] ]
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
			at: #candidates put: (sample at: #candidates).
		(sample at: #complete)
			ifFalse: [
				record at: #skipped put: true.
				self class logSkipped: record by: name ]
			ifTrue: [
				rank := (sample at: #candidates) indexOf: target.
				record at: #rank put: rank.
				self trackCompletionResultsFor: target atIndex: rank withPrefix: prefix.
				self logMemoryUsageSince: startMemory forPrefixSize: size.
				self logExecutionTimeSince: startTime forPrefixSize: size ] ]
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
