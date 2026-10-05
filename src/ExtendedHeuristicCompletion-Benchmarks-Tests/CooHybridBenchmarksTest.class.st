Class {
	#name : 'CooHybridBenchmarksTest',
	#superclass : 'TestCase',
	#instVars : [ 'transport', 'client', 'benchmark', 'builder' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooHybridBenchmarksTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	client := CooLLMClient new transport: transport; yourself.
	builder := CooHybridTestBuilder new.
	benchmark := CooHybridBenchmarks new client: client; builder: builder; yourself
]

{ #category : 'helpers' }
CooHybridBenchmarksTest >> messageIn: source [
	^ ((OCParser parseMethod: source) methodClass: self class; yourself)
		allChildren detect: #isMessage
]

{ #category : 'helpers' }
CooHybridBenchmarksTest >> variableNode [
	^ ((OCParser parseMethod: 'example ^ OrderedCollection new. HiddenAfterCursor new')
		methodClass: self class; yourself) allChildren
		detect: [ :node | node isVariable and: [ node name = 'OrderedCollection' ] ]
]

{ #category : 'helpers' }
CooHybridBenchmarksTest >> respondWith: text [
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> text. 'done' -> true. 'eval_count' -> (text ifEmpty: [ 0 ] ifNotEmpty: [ 1 ]) } ]
]

{ #category : 'helpers' }
CooHybridBenchmarksTest >> benchSizeWith: names response: text [
	builder names: names.
	self respondWith: text.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	^ benchmark records first
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testFusionInsertsLMFirstAndRemovesAllDuplicates [
	| result |
	result := benchmark fuseHeuristicCandidates: #('sizeInMemory' 'size' 'species' 'species') withLLMCandidate: 'size'.
	self assert: result asArray equals: #('size' 'sizeInMemory' 'species')
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testFusionIsBoundedAndDoesNotMutateInputs [
	| names result |
	names := (1 to: 10) collect: [ :index | 'candidate', index asString ].
	result := benchmark fuseHeuristicCandidates: names withLLMCandidate: 'other'.
	self assert: result size equals: 10.
	self assert: result first equals: 'other'.
	self assert: result last equals: 'candidate9'.
	self assert: names last equals: 'candidate10'.
	self assert: (benchmark fuseHeuristicCandidates: #() withLLMCandidate: '') isEmpty
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testCorrectLMPromotesTarget [
	| record |
	record := self benchSizeWith: #('signed' 'sin' 'sizeInMemory' 'size') response: 'ze'.
	self assert: (record at: #heuristicRank) equals: 4.
	self assert: (record at: #rank) equals: 1.
	self assert: (record at: #lmPromotes).
	self assert: (record at: #duplicateLM).
	self assert: (benchmark mmrForPrefixSize: 2) equals: 1
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testWrongLMDemotesTarget [
	| record |
	record := self benchSizeWith: #('size' 'sizeInMemory') response: 'gnedIntFromLong'.
	self assert: (record at: #rank) equals: 2.
	self assert: (record at: #lmHarms).
	self assert: (record at: #heuristicOnlySucceeds).
	self assert: (benchmark mmrForPrefixSize: 2) equals: 0.5
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testCorrectDuplicateDoesNotDemoteTarget [
	| record |
	record := self benchSizeWith: #('size' 'sizeInMemory') response: 'ze'.
	self assert: (record at: #rank) equals: 1.
	self assert: (record at: #lmAgrees).
	self assert: (record at: #unchanged).
	self deny: (record at: #lmHarms)
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testRankTenEvictionIsHarmAndUnionStillCountsIt [
	| names record |
	names := ((1 to: 9) collect: [ :index | 'size', index asString ]), #('size').
	record := self benchSizeWith: names response: 'gned'.
	self assert: (record at: #heuristicRank) equals: 10.
	self assert: (record at: #rank) equals: 0.
	self assert: (record at: #lmHarms).
	self assert: (record at: #unionHit)
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testLMRescueAndBothMiss [
	| record |
	record := self benchSizeWith: #() response: 'ze'.
	self assert: (record at: #lmRescues).
	self assert: (record at: #rank) equals: 1.
	self deny: (record at: #bothMiss).
	self assert: (benchmark records second at: #bothMiss).
	self assert: (benchmark diagnosticSummary at: #lmRescues) equals: 1.
	self assert: (benchmark diagnosticSummary at: #bothMiss) equals: 2.
	self assert: (benchmark diagnosticSummary at: #unionAccuracy) equals: (1 / 3.0)
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testEmptyGenerationPreservesHeuristicsEvenAtCompletePrefix [
	self benchSizeWith: #('sizeInMemory' 'size') response: ''.
	benchmark records do: [ :record |
		self assert: (record at: #lmCandidate) equals: ''.
		self assert: (record at: #finalCandidates) asArray equals: #('sizeInMemory' 'size').
		self assert: (record at: #rank) equals: 2 ].
	self assert: transport requests size equals: 3
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testWhitespaceAndExtraCodeAreInsertedVerbatim [
	#('ze ' 'ze. self new') do: [ :text |
		| record |
		self benchSizeWith: #('size') response: text.
		record := benchmark records at: benchmark records size - 2.
		self assert: (record at: #lmCandidate) equals: 'si', text.
		self assert: (record at: #finalCandidates) first equals: 'si', text.
		self assert: (record at: #rank) equals: 2 ]
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testMessageSnapshotUsesFIMSuffixAndOmitsTargetAndCandidates [
	| node |
	node := self messageIn: 'example ^ self secretCompletion. HiddenAfterCursor new'.
	builder names: #('secretHeuristicCandidate').
	benchmark benchCallsite: node atPosition: node start.
	transport requests do: [ :request |
		self deny: ((request at: 'prompt') includesSubstring: 'secretCompletion').
		self assert: ((request at: 'prompt') endsWith:
			'<|fim_suffix|>. HiddenAfterCursor new<|fim_middle|>').
		self deny: ((request at: 'prompt') includesSubstring: 'secretHeuristicCandidate').
		self assert: ((request at: 'options') at: 'num_predict') equals: 1.
		self assert: ((request at: 'options') at: 'temperature') equals: 0 ].
	self assert: node selector equals: #secretCompletion.
	self assert: transport requests size equals: 7
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testVariableSnapshotAndContextAndRestoration [
	| node |
	node := self variableNode.
	benchmark kind: #variables.
	builder buildBlock: [ :mutated :context |
		self assert: context class equals: CoBenchmarkVariableContext.
		self assert: mutated name size <= 8 ].
	benchmark benchCallsite: node atPosition: node start.
	transport requests do: [ :request |
		self deny: ((request at: 'prompt') includesSubstring: 'OrderedCollection').
		self assert: ((request at: 'prompt') endsWith:
			'<|fim_suffix|> new. HiddenAfterCursor new<|fim_middle|>') ].
	self assert: node name equals: 'OrderedCollection' 
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testKeywordSnapshotOmitsArgumentsAndRestoresSelector [
	| node |
	node := self messageIn: 'example ^ self at: secretArgument put: HiddenAfterCursor'.
	builder buildBlock: [ :mutated :context | self assert: context class equals: CoBenchmarkContext ].
	benchmark benchCallsite: node atPosition: node keywordsIntervals first.
	self assert: ((benchmark records third at: #snapshot) at: #sourcePrefix) equals: 'example ^ self at:p'.
	transport requests do: [ :request |
		self deny: ((request at: 'prompt') includesSubstring: 'secretArgument').
		self deny: ((request at: 'prompt') includesSubstring: 'HiddenAfterCursor') ].
	self assert: node selector equals: #at:put:
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testBuilderAndFetchFailuresRestoreBothNodeKinds [
	{ self messageIn: 'example ^ self size'. self variableNode } do: [ :node |
		#(build fetch) do: [ :stage |
			| localBuilder localBenchmark original |
			original := node isMessage ifTrue: [ node selector ] ifFalse: [ node name ].
			localBuilder := CooHybridTestBuilder new.
			stage = #build
				ifTrue: [ localBuilder buildBlock: [ :mutated :context |
					self assert: (mutated isMessage ifTrue: [ mutated selector asString ] ifFalse: [ mutated name ]) size equals: 2.
					self error: 'Builder failed' ] ]
				ifFalse: [ localBuilder fetchBlock: [ self error: 'Fetch failed' ] ].
			localBenchmark := CooHybridBenchmarks new client: client;
				kind: (node isMessage ifTrue: [ #messages ] ifFalse: [ #variables ]);
				builder: localBuilder; yourself.
			self should: [ localBenchmark benchCallsite: node atPosition: node start ] raise: Error.
			self assert: (node isMessage ifTrue: [ node selector ] ifFalse: [ node name ]) equals: original.
			self assert: (localBenchmark records first includesKey: #error).
			self assert: (localBenchmark totalEntriesPerPrefixSize: 2) equals: 0 ] ]
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testModelFailureIsDiagnosticNotMissAndNeverMutatesEitherKind [
	transport responseBlock: [ :payload | self error: 'Connection unavailable' ].
	{ self messageIn: 'example ^ self size'. self variableNode } do: [ :node |
		| original |
		original := node isMessage ifTrue: [ node selector ] ifFalse: [ node name ].
		benchmark kind: (node isMessage ifTrue: [ #messages ] ifFalse: [ #variables ]).
		self should: [ benchmark benchCallsite: node atPosition: node start ] raise: Error.
		self assert: (node isMessage ifTrue: [ node selector ] ifFalse: [ node name ]) equals: original ].
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 0.
	self assert: (benchmark records first at: #error) equals: 'Connection unavailable'.
	self assert: (benchmark diagnosticSummary at: #errors) equals: 2.
	self assert: (benchmark diagnosticSummary at: #count) equals: 0.
	self assert: (benchmark diagnosticSummary at: #unionAccuracy) isNil
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testInvalidKindIsRejected [
	self should: [ benchmark kind: #unknown ] raise: Error
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testRecordsExportIncludesDiagnosticsAndRawGeneration [
	| file exported |
	self benchSizeWith: #('size') response: 'ze'.
	file := FileLocator temp / ('hybrid-', UUID new asString, '.jsonl').
	[
		benchmark exportRecordsTo: file.
		exported := STONJSON fromString: file contents lines first.
		self assert: (exported at: 'rank') equals: 1.
		self assert: (exported at: 'duplicateLM').
		self assert: ((exported at: 'generation') at: 'content') equals: 'ze'
	] ensure: [ file ensureDelete ]
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testSummaryAggregatesUnequalPopulationsAndExcludesFailures [
	| second failed runs summary |
	self benchSizeWith: #() response: 'ze'.
	second := CooHybridBenchmarks new client: client;
		builder: (CooHybridTestBuilder new names: #('super'); yourself); yourself.
	second benchCallsite: (self messageIn: 'example ^ self super') atPosition: 0.
	failed := CooHybridBenchmarks new client: client; yourself.
	transport responseBlock: [ :request | self error: 'Unavailable' ].
	self should: [ failed benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0 ] raise: Error.
	runs := { benchmark. second. failed } collect: [ :each |
		CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #hybrid05B -> each }); yourself ].
	summary := CooBenchmarkChart hybridSummaryFor: #hybrid05B runs: runs.
	self assert: (summary at: #count) equals: 7.
	self assert: (summary at: #errors) equals: 1.
	self assert: (summary at: #lmRescues) equals: 1.
	self assert: (summary at: #lmHarms) equals: 4.
	self assert: (summary at: #bothMiss) equals: 2.
	self assert: (summary at: #unionAccuracy) equals: (5 / 7.0).
	self assert: (summary at: #accuracyAt1) equals: (1 / 7.0).
	self assert: (summary at: #accuracyAt3) equals: (5 / 7.0).
	self assert: (summary at: #accuracyAt10) equals: (5 / 7.0).
	self assert: (summary at: #mrr) closeTo: (3 / 7.0)
]

{ #category : 'fixtures' }
CooHybridBenchmarksTest >> fixture [
	^ OrderedCollection new
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testRealHeuristicCandidatesMatchLegacyForBothKinds [
	| tree message variable |
	tree := (self class >> #fixture) parseTree.
	message := tree allChildren detect: #isMessage.
	variable := tree allChildren detect: [ :node | CooStaticBenchmarksVariables isClassCompletionNode: node ].
	{ message. variable } do: [ :node |
		| original prefix position legacy expected actual runner |
		original := node isMessage ifTrue: [ node selectorNode value ] ifFalse: [ node name ].
		prefix := original first: 2.
		position := node isMessage ifTrue: [ node keywordsIntervals first ] ifFalse: [ node start ].
		runner := node isMessage ifTrue: [ CooBenchRunnerMessage new ] ifFalse: [ CooBenchRunnerVariables new ].
		legacy := node isMessage ifTrue: [ CooStaticBenchmarksMessage new ] ifFalse: [ CooStaticBenchmarksVariables new ].
		legacy builder: runner dependencyBuilder.
		[
			node isMessage ifTrue: [ node selectorNode value: prefix ] ifFalse: [ node name: prefix ].
			expected := ((legacy fetchTopCandidatesFrom: (legacy buildCompletionFor: node atPosition: position)
				usingPrefix: prefix) collect: [ :each | each contents asString ]) asArray
		] ensure: [ node isMessage ifTrue: [ node selectorNode value: original ] ifFalse: [ node name: original ] ].
		benchmark builder: runner dependencyBuilder.
		actual := benchmark heuristicCandidatesFor: node atPosition: position prefix: prefix.
		self assert: actual equals: expected.
		self assert: (actual allSatisfy: [ :candidate | candidate beginsWith: prefix ]).
		self assert: (node isMessage ifTrue: [ node selectorNode value ] ifFalse: [ node name ]) equals: original ]
]
