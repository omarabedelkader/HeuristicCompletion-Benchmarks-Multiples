Class {
	#name : 'CooLLMBeamRerankerTest',
	#superclass : 'TestCase',
	#instVars : [ 'transport', 'reranker' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooLLMBeamRerankerTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	reranker := CooLLMBeamReranker new
		client: (CooLLMClient new transport: transport; yourself);
		yourself
]

{ #category : 'helpers' }
CooLLMBeamRerankerTest >> snapshot [
	^ Dictionary new
		at: #context put: '"Class: Example"', String lf;
		at: #sourcePrefix put: 'example ^ self si';
		at: #suffix put: '';
		at: #contextPolicy put: 'fim-structural-v1';
		yourself
]

{ #category : 'helpers' }
CooLLMBeamRerankerTest >> rerank: candidates prefix: prefix tokens: table [
	transport nextTokens: (Dictionary newFrom: table).
	^ reranker rerank: candidates prefix: prefix snapshot: self snapshot
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testOrdersCandidatesBySequenceProbability [
	| result |
	result := self rerank: #('sizeInMemory' 'sign' 'size') prefix: 'si' tokens: {
		'' -> { 'ze' -> -0.1. 'gn' -> -2.0 }.
		'ze' -> { ' ' -> -0.2. 'In' -> -1.5 }.
		'gn' -> { '.' -> -0.1 }.
		'zeIn' -> { 'Memory' -> -0.1 }.
		'zeInMemory' -> { ' ' -> -0.05 } }.
	self assert: (result at: #ranking) equals: #('size' 'sizeInMemory' 'sign').
	self assert: ((result at: #scores) at: 'size') closeTo: -0.3.
	self assert: ((result at: #scores) at: 'sizeInMemory') closeTo: -1.75.
	self assert: ((result at: #scores) at: 'sign') closeTo: -2.1.
	self assert: (result at: #requests) equals: #('' 'ze' 'gn' 'zeIn' 'zeInMemory').
	self assert: (result at: #steps) equals: 4
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testEndOfNameFactorLetsAnExtensionWin [
	"Without the end factor at: would always score at least as well as at:put:."
	| result |
	result := self rerank: #('at:' 'at:put:') prefix: 'at' tokens: {
		'' -> { ':' -> -0.01 }.
		':' -> { 'put' -> -0.1. ' ' -> -3.0 }.
		':put' -> { ':' -> -0.01 }.
		':put:' -> { ' ' -> -0.01 } }.
	self assert: (result at: #ranking) equals: #('at:put:' 'at:').
	self assert: ((result at: #scores) at: 'at:') closeTo: -3.01.
	self assert: ((result at: #scores) at: 'at:put:') closeTo: -0.13
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testBeamWidthPrunesLessLikelyPaths [
	| table |
	table := {
		'' -> { 'ze' -> -0.1. 'gn' -> -0.2 }.
		'ze' -> { ' ' -> -1.0 }.
		'gn' -> { ' ' -> -0.1 } }.
	self assert: ((self rerank: #('size' 'sign') prefix: 'si' tokens: table) at: #ranking)
		equals: #('sign' 'size').
	reranker beamWidth: 1.
	self assert: ((self rerank: #('size' 'sign') prefix: 'si' tokens: table) at: #ranking)
		equals: #('size' 'sign')
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testUnreachedAndForeignNamesKeepHeuristicOrderAfterScoredOnes [
	| result |
	result := self rerank: #('Sign' 'sip' 'size' 'sizeX' 'sip') prefix: 'si' tokens: {
		'' -> { 'ze' -> -0.5 }.
		'ze' -> { ' ' -> -0.1 } }.
	self assert: (result at: #ranking) equals: #('size' 'Sign' 'sip' 'sizeX').
	self assert: (result at: #scores) keys asArray equals: #('size')
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testMissingEndingTokenIsBoundedByLowestListedToken [
	| result |
	result := self rerank: #('size' 'sizeAll') prefix: 'si' tokens: {
		'' -> { 'ze' -> -0.1 }.
		'ze' -> { 'All' -> -0.5. 'For' -> -2.0 }.
		'zeAll' -> { '.' -> -0.2 } }.
	self assert: (result at: #ranking) equals: #('sizeAll' 'size').
	self assert: ((result at: #scores) at: 'size') closeTo: -2.1.
	self assert: ((result at: #scores) at: 'sizeAll') closeTo: -0.8
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testCandidateEqualToPrefixAndModelEnd [
	| result |
	result := self rerank: #('sin' 'si') prefix: 'si' tokens: {
		'' -> { '<|endoftext|>' -> -0.1. 'n' -> -0.5 }.
		'n' -> { '(' -> -0.3 } }.
	self assert: (result at: #ranking) equals: #('si' 'sin').
	self assert: ((result at: #scores) at: 'si') closeTo: -0.1.
	self assert: ((result at: #scores) at: 'sin') closeTo: -0.8
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testPromptListsCandidatesAndRequestsLogprobs [
	| request |
	self rerank: #('size' 'sign') prefix: 'si' tokens: { '' -> { 'ze' -> -0.1 } }.
	request := transport requests first.
	self assert: ((request at: 'prompt') includesSubstring: '"Completion candidates: size sign"').
	self assert: ((request at: 'prompt') endsWith: '<|fim_prefix|>example ^ self si<|fim_suffix|><|fim_middle|>').
	self assert: (request at: 'logprobs').
	self assert: (request at: 'top_logprobs') equals: 20.
	self assert: ((request at: 'options') at: 'num_predict') equals: 1.
	self assert: ((request at: 'options') at: 'temperature') equals: 0.
	self assert: ((transport requests second at: 'prompt') endsWith: '<|fim_middle|>ze')
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testNoScorableCandidateMakesNoRequest [
	self assert: ((self rerank: #() prefix: 'si' tokens: #()) at: #ranking) isEmpty.
	self assert: ((self rerank: #('Size') prefix: 'si' tokens: #()) at: #ranking) equals: #('Size').
	self assert: transport requests isEmpty
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testServerWithoutLogprobsIsAnError [
	transport withoutLogprobs.
	self should: [ reranker rerank: #('size') prefix: 'si' snapshot: self snapshot ] raise: Error
]

{ #category : 'tests' }
CooLLMBeamRerankerTest >> testInvisibleEndTokenWithoutLogprobsIsACertainEnd [
	"Ollama omits log-probabilities when its top token prints nothing."
	| result |
	transport withoutLogprobs.
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> ''. 'done' -> true. 'eval_count' -> 1 } ].
	result := reranker rerank: #('sin' 'si') prefix: 'si' snapshot: self snapshot.
	self assert: (result at: #ranking) equals: #('si' 'sin').
	self assert: ((result at: #scores) at: 'si') equals: 0.0.
	self assert: (result at: #endsWithoutLogprobs) equals: 1.
	self assert: transport requests size equals: 1
]
