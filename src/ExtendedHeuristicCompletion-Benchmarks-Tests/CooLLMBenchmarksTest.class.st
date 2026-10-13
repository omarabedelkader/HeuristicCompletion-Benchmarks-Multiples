Class {
	#name : 'CooLLMBenchmarksTest',
	#superclass : 'TestCase',
	#instVars : [ 'transport', 'client' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooLLMBenchmarksTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	client := CooLLMClient new transport: transport; yourself
]

{ #category : 'helpers' }
CooLLMBenchmarksTest >> treeFor: source [
	^ (OCParser parseMethod: source) methodClass: self class; yourself
]

{ #category : 'helpers' }
CooLLMBenchmarksTest >> messageIn: source [
	^ (self treeFor: source) allChildren detect: [ :node | node isMessage ]
]

{ #category : 'helpers' }
CooLLMBenchmarksTest >> snapshot [
	^ CooLLMContextSnapshot
		for: (self messageIn: 'example ^ self size') prefix: 'si' kind: #messages
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testSnapshotUsesFollowingSourceAsFIMSuffix [
	| node snapshot prompt |
	node := self messageIn: 'example ^ self secretCompletion. HiddenAfterCursor new'.
	snapshot := CooLLMContextSnapshot for: node prefix: 'se' kind: #messages.
	prompt := client promptFor: snapshot.
	self assert: (snapshot at: #sourcePrefix) equals: 'example ^ self se'.
	self assert: (snapshot at: #contextPolicy) equals: 'fim-structural-v1'.
	self assert: (snapshot at: #suffix) equals: '. HiddenAfterCursor new'.
	self deny: (prompt includesSubstring: 'secretCompletion').
	self assert: (prompt includesSubstring:
		'<|fim_prefix|>example ^ self se<|fim_suffix|>. HiddenAfterCursor new<|fim_middle|>').
	self assert: node selector equals: #secretCompletion
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testKeywordSnapshotMatchesLegacySelectorPrefix [
	| node snapshot |
	node := self messageIn: 'example ^ self at: secretArgument put: HiddenAfterCursor. FollowingStatement new'.
	snapshot := CooLLMContextSnapshot for: node prefix: 'at:p' kind: #messages.
	self assert: (snapshot at: #sourcePrefix) equals: 'example ^ self at:p'.
	self assert: (snapshot at: #suffix) equals: '. FollowingStatement new'.
	self deny: ((client promptFor: snapshot) includesSubstring: 'secretArgument').
	self deny: ((client promptFor: snapshot) includesSubstring: 'HiddenAfterCursor').
	self assert: node selector equals: #at:put:
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testVariableSnapshotUsesExactSourceOffset [
	| tree node snapshot |
	tree := self treeFor: 'example | local | local := OrderedCollection new. ^ local'.
	node := tree allChildren detect: [ :each | each isVariable and: [ each name = 'OrderedCollection' ] ].
	snapshot := CooLLMContextSnapshot for: node prefix: 'Ord' kind: #variables.
	self assert: (snapshot at: #sourcePrefix) equals: 'example | local | local := Ord'.
	self assert: (snapshot at: #suffix) equals: ' new. ^ local'.
	self deny: ((client promptFor: snapshot) includesSubstring: 'OrderedCollection').
	self assert: node name equals: 'OrderedCollection'
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testClassSideContextAndLineEndings [
	| tree node snapshot |
	tree := (OCParser parseMethod: 'example', String crlf, '^ self size.', String crlf,
		'FollowingStatement new', String cr)
		methodClass: self class class; yourself.
	node := tree allChildren detect: #isMessage.
	snapshot := CooLLMContextSnapshot for: node prefix: 'si' kind: #messages.
	self assert: (snapshot at: #className) equals: self class class name.
	self assert: (snapshot at: #sourcePrefix) equals: 'example', String lf, '^ self si'.
	self assert: (snapshot at: #suffix) equals: '.', String lf, 'FollowingStatement new', String lf.
	self deny: ((client promptFor: snapshot) includes: Character cr)
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testRawFIMPayloadEnforcesOneToken [
	| payload options |
	payload := client payloadFor: self snapshot.
	options := payload at: 'options'.
	self assert: (payload at: 'raw').
	self deny: (payload at: 'stream').
	self assert: (options at: 'num_predict') equals: 1.
	self assert: (options at: 'temperature') equals: 0.
	self assert: ((payload at: 'prompt') endsWith: '<|fim_prefix|>example ^ self si<|fim_suffix|><|fim_middle|>')
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testCustomTemplateDoesNotReexpandSourcePlaceholders [
	| snapshot |
	snapshot := self snapshot.
	snapshot at: #sourcePrefix put: 'literal {{ .Suffix }}'.
	snapshot at: #suffix put: 'not substituted inside source'.
	client template: '{{ .Prompt }}--{{ .Suffix }}'.
	self assert: ((client promptFor: snapshot) endsWith:
		'literal {{ .Suffix }}--not substituted inside source').
	self assert: ((client promptFor: snapshot) beginsWith: (snapshot at: #context))
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testGenerationPreservesRequestAndResponse [
	| result |
	result := client generateFor: self snapshot.
	self assert: (result at: #content) equals: 'ze'.
	self assert: (result at: #request) equals: transport requests first.
	self assert: ((result at: #response) at: 'eval_count') equals: 1
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testMalformedOrMultiTokenResponseFails [
	#(
		'{"error":"missing model"}'
		'{"response":"ze","done":false}'
		'{"response":"ze","done":true,"eval_count":2}'
		'{"done":true}'
	) do: [ :json |
		transport responseBlock: [ :payload | STONJSON fromString: json ].
		self should: [ client generateFor: self snapshot ] raise: Error ]
]

{ #category : 'helpers' }
CooLLMBenchmarksTest >> namesFor: target [
	"Ten real names that continue every prefix of target, target first."
	^ { target }, ((1 to: 9) collect: [ :index | target, index printString ])
]

{ #category : 'helpers' }
CooLLMBenchmarksTest >> benchmarkCompleting: names [
	| benchmark |
	transport completeNames: names.
	benchmark := CooLLMBenchmarks new client: client; yourself.
	benchmark sampler vocabulary: names asSet.
	^ benchmark
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testTargetIsRankedAmongTenRealNames [
	| benchmark node |
	benchmark := self benchmarkCompleting: (self namesFor: 'size') reversed.
	node := self messageIn: 'example ^ self size'.
	benchmark benchCallsite: node atPosition: 0.
	self assert: benchmark records size equals: 3.
	benchmark records do: [ :record |
		self assert: (record at: #candidates) size equals: 10.
		self assert: (record at: #rank) equals: 10 ].
	self assert: (benchmark mmrForPrefixSize: 2) closeTo: 0.1.
	self assert: (benchmark totalEntriesPerPrefixSize: 4) equals: 1.
	self assert: benchmark skippedRecords isEmpty.
	self assert: node selector equals: #size.
	self assert: transport requests size equals: 30
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testCompleteSamplingWithoutTargetIsMiss [
	| benchmark |
	benchmark := self benchmarkCompleting: ((1 to: 10) collect: [ :index | 'size', index printString ]).
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	self assert: (benchmark mmrForPrefixSize: 2) equals: 0.
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 1.
	self assert: (benchmark records first at: #rank) equals: 0
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testFewerThanTenRealNamesSkipsPrefixAndKeepsRecord [
	| benchmark names |
	"'sin' only continues 'si'; 'siz' and 'size' have nine real names."
	names := #('sin'), ((self namesFor: 'size') allButLast).
	benchmark := self benchmarkCompleting: names.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 1.
	self assert: (benchmark totalEntriesPerPrefixSize: 3) equals: 0.
	self assert: (benchmark totalEntriesPerPrefixSize: 4) equals: 0.
	self assert: benchmark skippedRecords size equals: 2.
	benchmark skippedRecords do: [ :record |
		self deny: (record includesKey: #rank).
		self assert: (record at: #candidates) size equals: 9.
		self assert: (record at: #attempts) size equals: 20 ].
	self assert: transport requests size equals: 10 + 20 + 20
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testLegacyAndLLMUseSamePrefixPopulation [
	| legacy llm node |
	node := (self class >> #fixture) parseTree allChildren detect: #isMessage.
	legacy := CooStaticBenchmarksMessage new.
	legacy benchCallsite: node atPosition: node keywordsIntervals first.
	llm := self benchmarkCompleting: (self namesFor: 'yourself').
	llm benchCallsite: node atPosition: node start.
	2 to: 8 do: [ :prefix |
		self assert: (legacy totalEntriesPerPrefixSize: prefix)
			equals: (llm totalEntriesPerPrefixSize: prefix) ]
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testNetworkFailureIsRecordedAndDoesNotCountAsModelMiss [
	| benchmark node |
	transport responseBlock: [ :payload | self error: 'Connection unavailable' ].
	benchmark := CooLLMBenchmarks new client: client; yourself.
	node := self messageIn: 'example ^ self size'.
	self should: [ benchmark benchCallsite: node atPosition: 0 ] raise: Error.
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 0.
	self assert: (benchmark records first at: #error) equals: 'Connection unavailable'.
	self assert: node selector equals: #size
]

{ #category : 'fixtures' }
CooLLMBenchmarksTest >> fixture [
	^ self yourself
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testChartWeightsByCallsiteCountAndLeavesEmptyPrefixesMissing [
	| first second run1 run2 |
	first := CooStaticBenchmarksMessage new.
	first trackCompletionResultsFor: 'size' atIndex: 1 withPrefix: 'si'.
	second := CooStaticBenchmarksMessage new.
	3 timesRepeat: [ second trackCompletionResultsFor: 'size' atIndex: 0 withPrefix: 'si' ].
	run1 := CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #sample -> first }); yourself.
	run2 := CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #sample -> second }); yourself.
	self assert: (CooBenchmarkChart valueFor: #sample prefix: 2 runs: {run1. run2}) equals: 0.25.
	self assert: (CooBenchmarkChart valueFor: #sample prefix: 8 runs: {run1. run2}) isNil
]

{ #category : 'tests' }
CooLLMBenchmarksTest >> testChartRendersInHeadlessImage [
	| benchmark run form |
	benchmark := CooStaticBenchmarksMessage new.
	benchmark trackCompletionResultsFor: 'size' atIndex: 1 withPrefix: 'si'.
	run := CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: {
		#heuristicsBaseline -> benchmark. #heuristicsDependency -> benchmark.
		#llmCompletion -> benchmark }); yourself.
	form := CooBenchmarkChart formFor: { run } title: 'Messages'.
	self assert: form width equals: 900.
	self assert: form height equals: 1005
]
