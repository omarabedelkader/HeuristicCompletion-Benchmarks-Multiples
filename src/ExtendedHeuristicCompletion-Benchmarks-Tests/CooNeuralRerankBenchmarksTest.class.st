Class {
	#name : 'CooNeuralRerankBenchmarksTest',
	#superclass : 'TestCase',
	#instVars : [ 'transport', 'ranker', 'builder', 'benchmark' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	transport responseBlock: [ :request | self responseFor: request ].
	ranker := CooNeuralRanker new client: (CooNeuralRankerClient new transport: transport; yourself); yourself.
	builder := CooHybridTestBuilder new names: #('signed' 'sin' 'size'); yourself.
	benchmark := CooNeuralRerankBenchmarks new ranker: ranker; builder: builder; yourself
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> responseFor: request [
	| candidates |
	candidates := request at: 'candidates'.
	^ Dictionary newFrom: {
		'schema' -> 'coo-ranking-v1'. 'modelId' -> 'test-only'.
		'inference_ms' -> 0.5. 'feature_ms' -> 0.1. 'fusionTrained' -> true.
		'scores' -> (candidates collect: [ :c | { c at: 'name'. 1.0 / candidates size } ]) }
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> node [
	^ ((OCParser parseMethod: 'example ^ self size') methodClass: self class; yourself)
		allChildren detect: #isMessage
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testNoGenerationAndNoTargetInRequest [
	benchmark client: (CooLLMClient new transport: (CooLLMTestTransport new responseBlock: [ :r |
		self fail: 'Reranker generated text' ]; yourself); yourself).
	benchmark benchCallsite: self node atPosition: 0.
	self assert: transport requests size equals: 3.
	transport requests do: [ :request |
		self deny: (request includesKey: 'target').
		self deny: (request includesKey: 'group').
		self deny: (request includesKey: 'snapshot').
		self deny: (request includesKey: 'suffix') ].
	self assert: (transport requests first at: 'sourcePrefix') equals: 'example ^ self si'.
	self assert: (benchmark records first at: #rank) equals: 3
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testRerankingCanPromoteCandidateBeyondTen [
	builder names: ((1 to: 20) collect: [ :i | 'si', i asString ]) , #('size').
	transport responseBlock: [ :request |
		| result candidates |
		result := self responseFor: request.
		candidates := (request at: 'candidates') reversed.
		result at: 'scores' put: (candidates withIndexCollect: [ :c :i | { c at: 'name'. i = 1 ifTrue: [ 1.0 ] ifFalse: [ 0.0 ] } ]).
		result ].
	benchmark benchCallsite: self node atPosition: 0.
	self assert: (benchmark records first at: #candidateRank) equals: 21.
	self assert: (benchmark records first at: #rank) equals: 1.
	self assert: (benchmark records first at: #finalCandidates) size equals: 10
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testAstRestoredOnBuilderAndFetchFailure [
	#(build fetch) do: [ :stage |
		| node |
		node := self node.
		builder := CooHybridTestBuilder new.
		stage = #build
			ifTrue: [ builder buildBlock: [ :n :c | self error: 'broken' ] ]
			ifFalse: [ builder fetchBlock: [ self error: 'broken' ] ].
		benchmark builder: builder.
		self should: [ benchmark benchCallsite: node atPosition: 0 ] raise: Error.
		self assert: node selector equals: #size ].
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 0
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testServerFailureIsNotScoredAsMiss [
	transport responseBlock: [ :request | self error: 'offline' ].
	self should: [ benchmark benchCallsite: self node atPosition: 0 ] raise: Error.
	self assert: (benchmark records first at: #error) equals: 'offline'.
	self assert: benchmark completionBenchs isEmpty.
	self assert: benchmark latencySamples isEmpty
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testInvalidPermutationAndProbabilitiesAreRejected [
	{ #(#('invented' 1.0)). #(#('signed' 0.5) #('signed' 0.3) #('size' 0.2)).
		#(#('signed' 0.3) #('sin' 0.5) #('size' 0.2)).
		#(#('signed' 0.9) #('sin' 0.5) #('size' 0.2)) } do: [ :scores |
		transport responseBlock: [ :request | (self responseFor: request) at: 'scores' put: scores; yourself ].
		self should: [ benchmark benchCallsite: self node atPosition: 0 ] raise: Error ].
	self assert: benchmark completionBenchs isEmpty
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testEmptyCandidateSetIsARealMiss [
	builder names: #().
	benchmark benchCallsite: self node atPosition: 0.
	self assert: benchmark records size equals: 3.
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 1.
	self assert: (benchmark records first at: #rank) equals: 0
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testRecallNeedsNoServerAndExportsMisses [
	| file rows |
	benchmark := CooCandidateRecallBenchmarks new builder: builder; yourself.
	benchmark benchCallsite: self node atPosition: 0.
	file := FileLocator temp / ('ranking-', UUID new asString, '.jsonl').
	[ benchmark exportTrainingTo: file.
		rows := file contents lines collect: [ :line | STONJSON fromString: line ].
		self assert: rows size equals: 3.
		self assert: (rows first at: 'target') equals: 'size'.
		self assert: (rows first at: 'sourcePrefix') equals: 'example ^ self si'.
		self assert: (rows first at: 'group') equals: self class package name
	] ensure: [ file ensureDelete ].
	self assert: transport requests isEmpty
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testConfidentAdaptivePathSkipsLM [
	builder names: #('size').
	benchmark := CooAdaptiveHybridBenchmarks new ranker: ranker; builder: builder;
		client: (CooLLMClient new transport: (CooLLMTestTransport new responseBlock: [ :r | self fail ]; yourself); yourself); yourself.
	benchmark benchCallsite: self node atPosition: 0.
	self assert: (benchmark records allSatisfy: [ :r | (r at: #fallbackCalled) not ])
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testUncertainFusionDoesNotForceLMFirst [
	| lmTransport |
	lmTransport := CooLLMTestTransport new responseBlock: [ :r |
		Dictionary newFrom: { 'done' -> true. 'response' -> 'wrong'. 'eval_count' -> 1 } ]; yourself.
	benchmark := CooAdaptiveHybridBenchmarks new ranker: ranker; builder: builder;
		client: (CooLLMClient new transport: lmTransport; yourself); yourself.
	benchmark benchCallsite: self node atPosition: 0.
	self assert: lmTransport requests size equals: 3.
	self assert: transport requests size equals: 6.
	self assert: (benchmark records first at: #finalCandidates) first equals: 'signed'.
	self assert: (benchmark records first at: #finalCandidates) last equals: 'siwrong'.
	self assert: ((transport requests second at: 'candidates') last at: 'lmAgreement')
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testAdaptiveRejectsUntrainedFusionBeforeGeneration [
	transport responseBlock: [ :r | (self responseFor: r) at: 'fusionTrained' put: false; yourself ].
	benchmark := CooAdaptiveHybridBenchmarks new ranker: ranker; builder: builder; yourself.
	self should: [ benchmark benchCallsite: self node atPosition: 0 ] raise: Error.
	self assert: benchmark completionBenchs isEmpty
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testPercentilesPreserveExistingAggregates [
	#(1 2 3 4 100) do: [ :ms | benchmark logTime: ms forPrefix: 2 ].
	self assert: (benchmark totalTimeForPrefix: 2) equals: 110.
	self assert: (CooRankingReport percentile: 0.5 values: benchmark latencySamples) equals: 3.
	self assert: (CooRankingReport percentile: 0.95 values: benchmark latencySamples) equals: 100.
	self assert: (CooRankingReport percentile: 0.99 values: #()) isNil
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testInvalidCandidateLimits [
	#(0 1 11 51) do: [ :k | self should: [ benchmark candidateLimit: k ] raise: Error ]
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testRealProviderPreservesTopTenAndNestedPools [
	| node plain instrumented firstTen previous |
	node := ((OCParser parseMethod: 'example ^ OrderedCollection new') methodClass: self class; yourself)
		allChildren detect: #isMessage.
	plain := CooHybridBenchmarks new builder: CooBenchRunnerMessage new dependencyBuilder; yourself.
	firstTen := plain heuristicCandidatesFor: node atPosition: node keywordsIntervals first prefix: 'ne'.
	instrumented := CooCandidateRecallBenchmarks new builder: CooBenchRunnerMessage new dependencyBuilder; yourself.
	previous := #().
	#(10 20 30 50) do: [ :k |
		| entries names |
		instrumented candidateLimit: k.
		entries := instrumented entriesFor: node atPosition: node keywordsIntervals first prefix: 'ne'.
		names := entries collect: [ :entry | entry contents asString ].
		self assert: (names first: (10 min: names size)) equals: firstTen.
		self assert: (names first: previous size) equals: previous.
		previous := names ].
	self assert: node selector equals: #new
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testVariableRestorationAfterFailure [
	| node |
	node := ((OCParser parseMethod: 'example ^ OrderedCollection new') methodClass: self class; yourself)
		allChildren detect: [ :each | each isVariable and: [ each name = 'OrderedCollection' ] ].
	builder fetchBlock: [ self error: 'broken' ].
	benchmark kind: #variables.
	self should: [ benchmark benchCallsite: node atPosition: node start ] raise: Error.
	self assert: node name equals: 'OrderedCollection'.
	self assert: benchmark completionBenchs isEmpty
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testFusionUnionDeduplicatesWithoutMutatingOriginalCandidates [
	| candidates union |
	candidates := { CooRankingCandidate name: 'size' rank: 1 source: 'self' }.
	union := benchmark unionOf: candidates with: 'size'.
	self assert: union size equals: 1.
	self assert: (union first asDictionary at: 'lmAgreement').
	self deny: (candidates first asDictionary at: 'lmAgreement').
	self assert: (benchmark unionOf: candidates with: '') size equals: 1.
	self assert: ((benchmark unionOf: candidates with: 'sin') last asDictionary at: 'rank') equals: 0
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testFusionTrainingCollectorBootstrapsWithoutRanker [
	| lm file rows |
	lm := CooLLMTestTransport new responseBlock: [ :request |
		Dictionary newFrom: { 'done' -> true. 'response' -> 'new'. 'eval_count' -> 1 } ]; yourself.
	benchmark := CooFusionTrainingBenchmarks new builder: builder;
		client: (CooLLMClient new transport: lm; yourself); yourself.
	benchmark benchCallsite: self node atPosition: 0.
	self assert: transport requests isEmpty.
	file := FileLocator temp / ('fusion-', UUID new asString, '.jsonl').
	[ benchmark exportFusionTrainingTo: file.
		rows := file contents lines collect: [ :line | STONJSON fromString: line ].
		self assert: rows size equals: 3.
		self assert: ((rows first at: 'candidates') last at: 'lmAgreement').
		self assert: (rows first at: 'candidateLimit') equals: 50
	] ensure: [ file ensureDelete ]
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testReportDoesNotInventUnmeasuredRecallOrLatency [
	| runner summary |
	benchmark candidateLimit: 10.
	benchmark benchCallsite: self node atPosition: 0.
	runner := CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #neural -> benchmark }); yourself.
	summary := CooRankingReport summaryFor: #neural runs: { runner }.
	self assert: (summary at: #count) equals: 3.
	self assert: ((summary at: #candidateRecall) at: '10') equals: 1.0.
	self assert: ((summary at: #candidateRecall) at: '20') isNil.
	self assert: (summary at: #p95Ms) notNil.
	benchmark latencySamples removeAll.
	summary := CooRankingReport summaryFor: #neural runs: { runner }.
	self assert: (summary at: #p95Ms) isNil
]

{ #category : 'tests' }
CooNeuralRerankBenchmarksTest >> testBudgetAndParetoSelection [
	| a b c summaries |
	a := Dictionary newFrom: { #count -> 10. #errors -> 0. #performance -> 0.7. #latencyMs -> 10. #p95Ms -> 20 }.
	b := Dictionary newFrom: { #count -> 10. #errors -> 0. #performance -> 0.6. #latencyMs -> 20. #p95Ms -> 30 }.
	c := Dictionary newFrom: { #count -> 10. #errors -> 0. #performance -> 0.8. #latencyMs -> 200. #p95Ms -> 300 }.
	summaries := { a. b. c }.
	self assert: (CooRankingReport frontier: summaries) equals: { a. c }.
	self assert: (CooRankingReport bestIn: summaries p95Budget: 100 memoryBudget: nil) equals: a.
	self assert: (CooRankingReport bestIn: summaries p95Budget: 100 memoryBudget: 100) isNil
]
