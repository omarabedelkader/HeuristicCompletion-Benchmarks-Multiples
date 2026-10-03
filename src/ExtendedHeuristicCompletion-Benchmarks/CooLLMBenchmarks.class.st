"
Uses the same callsites, prefixes (2..8), exact-match target and MRR accounting
as the legacy benchmarks. The sole candidate is typed prefix + generated text.
One model token may be a subword, so an incomplete name is correctly a miss.
No AST mutation, autocomplete fallback, sampling loop or target-aware repair.
"
Class {
	#name : 'CooLLMBenchmarks',
	#superclass : 'CooStaticBenchmarksMessage',
	#instVars : [ 'client', 'kind', 'records', 'experiment', 'latencyCondition', 'prepared', 'completionTokenLimit' ],
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
	records := OrderedCollection new.
	experiment := #oneToken.
	latencyCondition := #uncontrolled.
	prepared := false.
	completionTokenLimit := 64
]

{ #category : 'accessing' }
CooLLMBenchmarks >> client: aClient [
	client := aClient.
	prepared := false
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
				ifFalse: [ node isVariable and: [ node name first isUppercase ] ])
				ifTrue: [ self benchCallsite: node atPosition: node start ] ] ]
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> benchCallsite: node atPosition: ignoredPosition [
	| target |
	target := node isMessage ifTrue: [ node selector asString ] ifFalse: [ node name ].
	2 to: (target size min: 8) do: [ :size |
		| prefix snapshot startTime startMemory generation candidates rank record preparation elapsed |
		preparation := self prepareRequest.
		startTime := self startTimeMeasurement.
		startMemory := self startMemoryMeasurement.
		prefix := target first: size.
		snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
		record := Dictionary newFrom: {
			#snapshot -> snapshot. #expected -> target. #prefix -> prefix.
			#model -> self modelName. #experiment -> self experiment.
			#latencyCondition -> latencyCondition. #preparation -> preparation }.
		records add: record.
		[
			self enrichSnapshot: snapshot for: node.
			generation := self generationFor: snapshot.
			record at: #generation put: generation;
				at: #truncated put: ((generation at: #response) at: 'done_reason' ifAbsent: [ '' ]) = 'length'.
			self addTimingsFrom: generation to: record.
			candidates := self candidatesFrom: generation snapshot: snapshot record: record
		] on: Error do: [ :error |
			record at: #error put: error messageText;
				at: #wallTimeMs put: self startTimeMeasurement - startTime.
			error pass ].
		elapsed := self startTimeMeasurement - startTime.
		rank := candidates indexOf: target ifAbsent: [ 0 ].
		record at: #candidates put: candidates; at: #rank put: rank; at: #wallTimeMs put: elapsed.
		self trackCompletionResultsFor: target atIndex: rank withPrefix: prefix.
		self logMemoryUsageSince: startMemory forPrefixSize: size.
		self logTime: elapsed forPrefix: size ]
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> enrichSnapshot: snapshot for: node [
	"Extension point for model inputs; the plain LLM uses only source context."
	^ snapshot
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

{ #category : 'accessing' }
CooLLMBenchmarks >> modelName [
	^ client model
]

{ #category : 'accessing' }
CooLLMBenchmarks >> experiment [
	^ experiment
]

{ #category : 'accessing' }
CooLLMBenchmarks >> observations [
	^ records
]

{ #category : 'accessing' }
CooLLMBenchmarks >> completionLevel [
	experiment := #completion.
	name := 'LLM (complete name)'
]

{ #category : 'accessing' }
CooLLMBenchmarks >> completionTokenLimit: limit [
	(limit isInteger and: [ limit > 0 ]) ifFalse: [ self error: 'Expected a positive token limit' ].
	completionTokenLimit := limit
]

{ #category : 'accessing' }
CooLLMBenchmarks >> latencyCondition [
	^ latencyCondition
]

{ #category : 'accessing' }
CooLLMBenchmarks >> latencyCondition: condition [
	(#(uncontrolled warm cold) includes: condition) ifFalse: [ self error: 'Unknown latency condition' ].
	latencyCondition := condition.
	prepared := false
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> prepareRequest [
	| preparation |
	(latencyCondition = #cold or: [ prepared not ]) ifTrue: [
		preparation := client prepareFor: latencyCondition.
		prepared := true ].
	^ preparation
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> generationFor: snapshot [
	^ experiment = #oneToken
		ifTrue: [ client generateFor: snapshot ]
		ifFalse: [ client generateNameFor: snapshot maxTokens: completionTokenLimit ]
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> candidatesFrom: generation snapshot: snapshot record: record [
	| content prefix candidate |
	content := generation at: #content.
	prefix := snapshot at: #prefix.
	experiment = #completion ifTrue: [ content := self nameContinuationIn: content ].
	candidate := prefix , content.
	record at: #candidate put: candidate.
	^ { candidate }
]

{ #category : 'benchmarks' }
CooLLMBenchmarks >> nameContinuationIn: content [
	"The legacy population consists of alphanumeric names and concatenated
	keyword selectors. A colon is part of a selector, not a stopping delimiter.
	Leading whitespace produces no continuation; never trim or repair output."
	^ String streamContents: [ :out |
		| stream |
		stream := content readStream.
		[ stream atEnd not and: [
			stream peek isAlphaNumeric or: [ stream peek = $_ or: [
				kind = #messages and: [ stream peek = $: ] ] ] ] ]
			whileTrue: [ out nextPut: stream next ] ]
]

{ #category : 'metrics' }
CooLLMBenchmarks >> addTimingsFrom: generation to: record [
	| response |
	response := generation at: #response.
	{ #ollamaTotalNs -> 'total_duration'. #ollamaLoadNs -> 'load_duration'.
		#promptEvalNs -> 'prompt_eval_duration'. #promptTokens -> 'prompt_eval_count'.
		#generationNs -> 'eval_duration'. #generatedTokens -> 'eval_count' } do: [ :field |
		record at: field key put: (response at: field value ifAbsent: [ nil ]) ].
	{ #ollamaTotalMs -> #ollamaTotalNs. #ollamaLoadMs -> #ollamaLoadNs.
		#promptEvalMs -> #promptEvalNs. #generationMs -> #generationNs } do: [ :field |
		record at: field key put: ((record at: field value)
			ifNotNil: [ :ns | ns / 1000000.0 ]) ].
	record at: #heuristicMs put: ((record at: #snapshot) at: #heuristicMs ifAbsent: [ 0 ])
]
