Class {
	#name : 'CooHybridLLMBenchmarksTest',
	#superclass : 'TestCase',
	#instVars : [ 'hybrid', 'transport' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooHybridLLMBenchmarksTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	hybrid := CooHybridLLMBenchmarks new
		client: (CooLLMClient new transport: transport; yourself);
		yourself
]

{ #category : 'fixtures' }
CooHybridLLMBenchmarksTest >> messageFixture [
	^ self yourself
]

{ #category : 'fixtures' }
CooHybridLLMBenchmarksTest >> variableFixture [
	^ OrderedCollection new
]

{ #category : 'helpers' }
CooHybridLLMBenchmarksTest >> messageNode [
	^ (self class >> #messageFixture) parseTree allChildren detect: #isMessage
]

{ #category : 'helpers' }
CooHybridLLMBenchmarksTest >> variableNode [
	^ (self class >> #variableFixture) parseTree allChildren detect: [ :node |
		node isVariable and: [ node name = 'OrderedCollection' ] ]
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testMergeDeduplicatesAndPreservesBothRanks [
	| merged shared |
	merged := OrderedCollection new.
	hybrid merge: #('size' 'sizeHint') from: #Dependency into: merged.
	hybrid merge: #('sizeHint' 'size' 'sizeOther') from: #Baseline into: merged.
	self assert: (merged collect: [ :hint | hint at: #candidate ]) asArray
		equals: #('size' 'sizeHint' 'sizeOther').
	shared := merged first at: #ranks.
	self assert: (shared first at: #source) equals: 'Dependency'.
	self assert: (shared first at: #rank) equals: 1.
	self assert: (shared second at: #source) equals: 'Baseline'.
	self assert: (shared second at: #rank) equals: 2
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testRealMessageHintsArePrefixFilteredAndASTIsRestored [
	| node hints |
	node := self messageNode.
	hints := hybrid candidatesFor: node prefix: 'yours'.
	self assert: (hints anySatisfy: [ :hint | (hint at: #candidate) = 'yourself' ]).
	self assert: (hints allSatisfy: [ :hint | (hint at: #candidate) beginsWith: 'yours' ]).
	self assert: hints size <= 20.
	self assert: (hints allSatisfy: [ :hint |
		(hint at: #ranks) allSatisfy: [ :rank | (rank at: #rank) between: 1 and: 10 ] ]).
	self assert: node selector equals: #yourself
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testRealVariableHintsAreIncludedAndASTIsRestored [
	| node hints |
	hybrid kind: #variables.
	node := self variableNode.
	hints := hybrid candidatesFor: node prefix: 'OrderedC'.
	self assert: (hints anySatisfy: [ :hint | (hint at: #candidate) = 'OrderedCollection' ]).
	self assert: (hints allSatisfy: [ :hint | (hint at: #candidate) beginsWith: 'OrderedC' ]).
	self assert: node name equals: 'OrderedCollection'
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testHintsReachModelWithoutChangingOneTokenLimitOrSourcePrefix [
	| record snapshot request |
	hybrid benchCallsite: self messageNode atPosition: 0.
	record := hybrid records detect: [ :each | (each at: #snapshot at: #prefix) = 'yours' ].
	snapshot := record at: #snapshot.
	request := record at: #generation at: #request.
	self assert: ((request at: 'prompt') includesSubstring: '<|file_sep|>heuristic-candidates').
	self assert: ((request at: 'prompt') includesSubstring: 'yourself [').
	self assert: ((request at: 'prompt') includesSubstring: 'Dependency rank').
	self assert: ((snapshot at: #sourcePrefix) endsWith: '^ self yours').
	self assert: (snapshot at: #suffix) equals: ''.
	self assert: (request at: 'options' at: 'num_predict') equals: 1.
	self assert: transport requests size equals: 7
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testFailureDuringLazyFetchRestoresMessageAndVariable [
	| source |
	source := CooHybridTestHeuristics new fail: true; yourself.
	hybrid heuristics: { #Failing -> source }.
	{ self messageNode. self variableNode } do: [ :node |
		| original |
		original := node isMessage ifTrue: [ node selector ] ifFalse: [ node name ].
		self should: [ hybrid candidatesFor: node prefix: 'xx' ] raise: Error.
		self assert: source seenPrefix equals: 'xx'.
		self assert: (node isMessage ifTrue: [ node selector ] ifFalse: [ node name ]) equals: original ]
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testHeuristicFailureIsAuditedWithoutCallingModel [
	hybrid heuristics: { #Failing -> (CooHybridTestHeuristics new fail: true; yourself) }.
	self should: [ hybrid benchCallsite: self messageNode atPosition: 0 ] raise: Error.
	self assert: (hybrid records first at: #error) equals: 'Heuristic fetch failed'.
	self assert: transport requests isEmpty.
	self assert: (hybrid totalEntriesPerPrefixSize: 2) equals: 0
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testEmptyHintsDoNotInjectAnswerAndStillCallModel [
	| record prompt |
	hybrid heuristics: { #Empty -> CooHybridTestHeuristics new }.
	hybrid benchCallsite: self messageNode atPosition: 0.
	record := hybrid records first.
	prompt := ((record at: #generation) at: #request) at: 'prompt'.
	self assert: (prompt includesSubstring: 'No heuristic suggestions.').
	self deny: (prompt includesSubstring: 'yourself').
	self assert: transport requests size equals: 7.
	self assert: (record at: #rank) equals: 0
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testHintContainingAnswerDoesNotMakeWrongGenerationCorrect [
	hybrid benchCallsite: self messageNode atPosition: 0.
	self assert: (hybrid records anySatisfy: [ :record |
		(record at: #snapshot at: #heuristicCandidates) anySatisfy: [ :hint |
			(hint at: #candidate) = 'yourself' ] ]).
	self assert: hybrid mmr equals: 0
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testAuditRecordsAreJSONSerializableWithSourceRanks [
	| record decoded hints |
	hybrid benchCallsite: self messageNode atPosition: 0.
	record := hybrid records detect: [ :each | (each at: #snapshot at: #prefix) = 'yours' ].
	decoded := STONJSON fromString: (STONJSON toString: record).
	hints := (decoded at: 'snapshot') at: 'heuristicCandidates'.
	self assert: hints notEmpty.
	self assert: ((hints first at: 'ranks') first at: 'source') equals: 'Dependency'.
	self assert: (decoded at: 'candidate') equals: 'yoursze'
]

{ #category : 'tests' }
CooHybridLLMBenchmarksTest >> testChartAndCSVIncludeFourthStrategy [
	| run form package |
	package := CooBenchRunnerTestPackageStub new name: 'Example'; yourself.
	run := CooBenchRunnerTestBenchStub new
		package: package;
		results: (Dictionary newFrom: {
			#heuristicsBaseline -> hybrid. #heuristicsDependency -> hybrid.
			#llmCompletion -> hybrid. #hybridCompletion -> hybrid }); yourself.
	self assert: (CooBenchmarkChart strategiesFor: { run }) asArray
		equals: #(heuristicsBaseline heuristicsDependency llmCompletion hybridCompletion).
	form := CooBenchmarkChart formFor: { run } title: 'Variables'.
	self assert: form height equals: 1040.
	self assert: ((CooBenchmarkChart csvFor: { run }) includesSubstring: 'hybridCompletion').
	self assert: (CooBenchmarkChart labelFor: #hybridCompletion) equals: 'Hybrid (heuristics + LLM)'
]
