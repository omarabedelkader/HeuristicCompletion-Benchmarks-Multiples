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
	^ ((OCParser parseMethod: 'example OrderedCollection new. ^ HiddenAfterCursor new')
		methodClass: self class; yourself) allChildren
		detect: [ :node | node isVariable and: [ node name = 'OrderedCollection' ] ]
]

{ #category : 'helpers' }
CooHybridBenchmarksTest >> sizeTokens [
	"After the typed si: size -0.3, sizeInMemory -1.75, sign -2.1."
	^ Dictionary newFrom: {
		'' -> { 'ze' -> -0.1. 'gn' -> -2.0 }.
		'ze' -> { ' ' -> -0.2. 'In' -> -1.5 }.
		'gn' -> { '.' -> -0.1 }.
		'zeIn' -> { 'Memory' -> -0.1 }.
		'zeInMemory' -> { ' ' -> -0.05 } }
]

{ #category : 'helpers' }
CooHybridBenchmarksTest >> benchSizeWith: names [
	"Answers the record of prefix si."
	builder names: names.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	^ benchmark records at: benchmark records size - 2
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testModelPromotesTargetWithinHeuristicList [
	| record |
	transport nextTokens: self sizeTokens.
	record := self benchSizeWith: #('sizeInMemory' 'sign' 'size').
	self assert: (record at: #heuristicCandidates) equals: #('sizeInMemory' 'sign' 'size').
	self assert: (record at: #finalCandidates) equals: #('size' 'sizeInMemory' 'sign').
	self assert: (record at: #heuristicRank) equals: 3.
	self assert: (record at: #rank) equals: 1.
	self assert: (record at: #promoted).
	self deny: (record at: #demoted).
	self assert: ((record at: #scores) at: 'size') closeTo: -0.3.
	self assert: (record at: #requests) equals: #('' 'ze' 'gn' 'zeIn' 'zeInMemory').
	self assert: (benchmark mmrForPrefixSize: 2) equals: 1
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testModelCanDemoteTarget [
	| record |
	transport nextTokens: (Dictionary newFrom: {
		'' -> { 'gn' -> -0.1. 'ze' -> -2.0 }.
		'gn' -> { ' ' -> -0.1 }.
		'ze' -> { ' ' -> -0.1 } }).
	record := self benchSizeWith: #('size' 'sign').
	self assert: (record at: #finalCandidates) equals: #('sign' 'size').
	self assert: (record at: #rank) equals: 2.
	self assert: (record at: #demoted).
	self assert: (benchmark mmrForPrefixSize: 2) equals: 0.5
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testRerankingNeverAddsOrDropsCandidates [
	| record |
	transport nextTokens: self sizeTokens.
	record := self benchSizeWith: #('sign' 'sizeInMemory' 'sin' 'sizeInMemory').
	benchmark records do: [ :each |
		self assert: (each at: #finalCandidates) asSet equals: (each at: #heuristicCandidates) asSet ].
	self assert: (record at: #rank) equals: 0.
	self assert: (record at: #heuristicMiss).
	self assert: (record at: #unchanged).
	self assert: (benchmark diagnosticSummary at: #heuristicMiss) equals: 3
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testFinalListIsTruncatedToTen [
	| names |
	names := (1 to: 12) collect: [ :index | 'size', index printString ].
	builder names: names.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	self assert: (benchmark records last at: #finalCandidates) size equals: 10
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testMessagePromptListsCandidatesAndOmitsTarget [
	| node |
	node := self messageIn: 'example self secretCompletion. ^ HiddenAfterCursor new'.
	builder names: #('seHeuristicCandidate' 'seOther').
	benchmark benchCallsite: node atPosition: node start.
	self assert: transport requests notEmpty.
	transport requests do: [ :request |
		self deny: ((request at: 'prompt') includesSubstring: 'secretCompletion').
		self assert: ((request at: 'prompt') includesSubstring: '"Completion candidates: seHeuristicCandidate seOther"').
		self assert: ((request at: 'prompt') includesSubstring:
			'<|fim_suffix|>. ^ HiddenAfterCursor new<|fim_middle|>').
		self assert: (request at: 'logprobs').
		self assert: ((request at: 'options') at: 'num_predict') equals: 1.
		self assert: ((request at: 'options') at: 'temperature') equals: 0 ].
	self assert: ((benchmark records first at: #snapshot) at: #contextPolicy) equals: 'fim-structural-v1'.
	self assert: (benchmark records first at: #contextPolicy) equals: 'fim-structural-v1+candidates'.
	self assert: node selector equals: #secretCompletion
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testVariableSnapshotAndContextAndRestoration [
	| node |
	node := self variableNode.
	benchmark kind: #variables.
	builder names: #('OrSomething' 'OrdOther' 'OrderOther').
	builder buildBlock: [ :mutated :context |
		self assert: context class equals: CoBenchmarkVariableContext.
		self assert: mutated name size <= 8 ].
	benchmark benchCallsite: node atPosition: node start.
	self assert: transport requests notEmpty.
	transport requests do: [ :request |
		self deny: ((request at: 'prompt') includesSubstring: 'OrderedCollection').
		self assert: ((request at: 'prompt') includesSubstring:
			'<|fim_suffix|> new. ^ HiddenAfterCursor new<|fim_middle|>') ].
	self assert: node name equals: 'OrderedCollection'
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testKeywordSnapshotOmitsArgumentsAndRestoresSelector [
	| node |
	node := self messageIn: 'example ^ self at: secretArgument put: HiddenAfterCursor'.
	builder names: #('at:' 'at:put:' 'at:ifAbsent:').
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
			self assert: (localBenchmark totalEntriesPerPrefixSize: 2) equals: 0 ] ].
	self assert: transport requests isEmpty
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testModelFailureIsDiagnosticNotMissAndNeverMutatesEitherKind [
	transport responseBlock: [ :payload | self error: 'Connection unavailable' ].
	{ self messageIn: 'example ^ self size'. self variableNode } do: [ :node |
		| original |
		original := node isMessage ifTrue: [ node selector ] ifFalse: [ node name ].
		builder names: { original asString }.
		benchmark kind: (node isMessage ifTrue: [ #messages ] ifFalse: [ #variables ]).
		self should: [ benchmark benchCallsite: node atPosition: node start ] raise: Error.
		self assert: (node isMessage ifTrue: [ node selector ] ifFalse: [ node name ]) equals: original ].
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 0.
	self assert: (benchmark records first at: #error) equals: 'Connection unavailable'.
	self assert: (benchmark records first at: #heuristicCandidates) equals: #('size').
	self assert: (benchmark diagnosticSummary at: #errors) equals: 2.
	self assert: (benchmark diagnosticSummary at: #count) equals: 0
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testInvalidKindIsRejected [
	self should: [ benchmark kind: #unknown ] raise: Error
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testRecordsExportIncludesScoresAndRequests [
	| file exported |
	transport nextTokens: self sizeTokens.
	self benchSizeWith: #('sizeInMemory' 'sign' 'size').
	file := FileLocator temp / ('hybrid-', UUID new asString, '.jsonl').
	[
		benchmark exportRecordsTo: file.
		exported := STONJSON fromString: file contents lines first.
		self assert: (exported at: 'rank') equals: 1.
		self assert: (exported at: 'promoted').
		self assert: (exported at: 'finalCandidates') equals: #('size' 'sizeInMemory' 'sign').
		self assert: ((exported at: 'scores') at: 'sign') closeTo: -2.1.
		self assert: (exported at: 'requests') size equals: 5
	] ensure: [ file ensureDelete ]
]

{ #category : 'tests' }
CooHybridBenchmarksTest >> testSummaryAggregatesPopulationsAndExcludesFailures [
	| second failed runs summary |
	transport nextTokens: self sizeTokens.
	self benchSizeWith: #('sizeInMemory' 'sign' 'size').
	second := CooHybridBenchmarks new client: client;
		builder: (CooHybridTestBuilder new names: #('sign' 'super'); yourself); yourself.
	second benchCallsite: (self messageIn: 'example ^ self super') atPosition: 0.
	failed := CooHybridBenchmarks new client: (CooLLMClient new
			transport: (CooLLMTestTransport new responseBlock: [ :request | self error: 'Unavailable' ]; yourself);
			yourself);
		builder: (CooHybridTestBuilder new names: #('size'); yourself); yourself.
	self should: [ failed benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0 ] raise: Error.
	runs := { benchmark. second. failed } collect: [ :each |
		CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #hybrid05B -> each }); yourself ].
	summary := CooBenchmarkChart hybridSummaryFor: #hybrid05B runs: runs.
	"si: 3 -> 1 by probability. siz: no listed token continues e, so rank 3
	stays. size and super: once the prefix is the whole name, only the
	lowest-token bound scores it, which ranks it above the unreached names
	(size 3 -> 1, super 2 -> 1). su, sup and supe keep rank 2. The failed
	benchmark adds an error but no observation."
	self assert: (summary at: #count) equals: 7.
	self assert: (summary at: #errors) equals: 1.
	self assert: (summary at: #promoted) equals: 3.
	self assert: (summary at: #demoted) equals: 0.
	self assert: (summary at: #unchanged) equals: 4.
	self assert: (summary at: #heuristicMiss) equals: 0.
	self assert: (summary at: #requests) equals: 11.
	self assert: (summary at: #accuracyAt1) equals: (3 / 7.0).
	self assert: (summary at: #accuracyAt3) equals: 1.0
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
