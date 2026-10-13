Class {
	#name : 'CooLLMBeamCompleterTest',
	#superclass : 'TestCase',
	#instVars : [ 'transport', 'completer' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooLLMBeamCompleterTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	completer := CooLLMBeamCompleter new
		client: (CooLLMClient new transport: transport; yourself);
		kind: #messages;
		yourself
]

{ #category : 'helpers' }
CooLLMBeamCompleterTest >> snapshotFor: prefix [
	^ Dictionary new
		at: #context put: '"Class: Example"', String lf;
		at: #prefix put: prefix;
		at: #sourcePrefix put: 'example ^ self ', prefix;
		at: #suffix put: '';
		at: #contextPolicy put: 'fim-structural-v1';
		yourself
]

{ #category : 'helpers' }
CooLLMBeamCompleterTest >> complete: prefix among: names tokens: table [
	completer vocabulary: names.
	transport nextTokens: (Dictionary newFrom: table).
	^ completer candidatesFor: (self snapshotFor: prefix)
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testRanksRealNamesBySequenceProbability [
	| result |
	result := self complete: 'si' among: #('size' 'sizeInMemory' 'sign' 'at:') tokens: {
		'' -> { 'ze' -> -0.1. 'gn' -> -2.0 }.
		'ze' -> { ' ' -> -0.2. 'In' -> -1.5 }.
		'gn' -> { '.' -> -0.1 }.
		'zeIn' -> { 'Memory' -> -0.1 }.
		'zeInMemory' -> { ' ' -> -0.05 } }.
	self assert: (result at: #candidates) equals: #('size' 'sizeInMemory' 'sign').
	self assert: ((result at: #scores) at: 'size') closeTo: -0.3.
	self assert: ((result at: #scores) at: 'sizeInMemory') closeTo: -1.75.
	self assert: ((result at: #scores) at: 'sign') closeTo: -2.1.
	self assert: (result at: #requests) equals: #('' 'ze' 'gn' 'zeIn' 'zeInMemory').
	self assert: (result at: #steps) equals: 4.
	self deny: (result at: #complete)
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testOnlyRealNamesAreFollowedOrAnswered [
	"sizzle is likelier but is not a name: its beam is never requested."
	| result |
	result := self complete: 'si' among: #('size') tokens: {
		'' -> { 'zz' -> -0.1. 'ze' -> -2.0. 'z' -> -3.0 }.
		'ze' -> { ' ' -> -0.1. 'd' -> -0.5 }.
		'z' -> { ' ' -> -0.1 } }.
	self assert: (result at: #candidates) equals: #('size').
	self assert: (result at: #requests) equals: #('' 'ze' 'z')
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testEndOfNameFactorLetsAnExtensionWin [
	| result |
	result := self complete: 'at' among: #('at:' 'at:put:') tokens: {
		'' -> { ':' -> -0.01 }.
		':' -> { 'put' -> -0.1. ' ' -> -3.0 }.
		':put' -> { ':' -> -0.01 }.
		':put:' -> { ' ' -> -0.01 } }.
	self assert: (result at: #candidates) equals: #('at:put:' 'at:').
	self assert: ((result at: #scores) at: 'at:') closeTo: -3.01.
	self assert: ((result at: #scores) at: 'at:put:') closeTo: -0.13
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testNameMayEndInsideATokenOrWithAnEndMarker [
	| result |
	result := self complete: 'si' among: #('si' 'size' 'sign') tokens: {
		'' -> { 'ze. ' -> -1.0. '' -> -2.0. 'gn)' -> -3.0. 'zed ' -> -0.5 } }.
	self assert: (result at: #candidates) equals: #('size' 'si' 'sign').
	self assert: ((result at: #scores) at: 'si') closeTo: -2.0.
	self assert: (result at: #requests) equals: #('')
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testTokenPathsSpellingTheSameNameAddUp [
	| result |
	result := self complete: 'si' among: #('size') tokens: {
		'' -> { 'ze' -> 0.5 ln. 'z' -> 0.25 ln }.
		'ze' -> { ' ' -> 0.0 }.
		'z' -> { 'e ' -> 0.0 } }.
	self assert: ((result at: #scores) at: 'size') closeTo: 0.75 ln
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testBeamWidthPrunesLessLikelyPaths [
	| table |
	table := {
		'' -> { 'ze' -> -0.1. 'gn' -> -0.2 }.
		'ze' -> { ' ' -> -0.1 }.
		'gn' -> { ' ' -> -0.1 } }.
	completer beamWidth: 1.
	self assert: ((self complete: 'si' among: #('size' 'sign') tokens: table) at: #candidates)
		equals: #('size').
	completer beamWidth: 2.
	self assert: ((self complete: 'si' among: #('size' 'sign') tokens: table) at: #candidates)
		equals: #('size' 'sign')
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testStopsWhenNoBeamCanBeatTheLastCandidate [
	| result |
	completer candidateCount: 1.
	result := self complete: 'si' among: #('size' 'sign' 'signal') tokens: {
		'' -> { 'ze ' -> -0.1. 'gn' -> -3.0 }.
		'gn' -> { ' ' -> -0.1. 'al' -> -0.1 } }.
	self assert: (result at: #candidates) equals: #('size').
	self assert: (result at: #complete).
	self assert: (result at: #requests) equals: #('')
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testMaxStepsBoundsTheSearch [
	| result |
	completer maxSteps: 2.
	result := self complete: 'si' among: #('sizeInMemory') tokens: {
		'' -> { 'ze' -> -0.1 }.
		'ze' -> { 'In' -> -0.1 }.
		'zeIn' -> { 'Memory ' -> -0.1 } }.
	self assert: (result at: #candidates) isEmpty.
	self assert: (result at: #steps) equals: 2
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testPrefixWithoutRealNameAsksNothing [
	| result |
	result := self complete: 'zz' among: #('size') tokens: #().
	self assert: (result at: #candidates) isEmpty.
	self assert: transport requests isEmpty
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testBinarySelectorContinuesWithSpecialCharacters [
	| result |
	result := self complete: '>=' among: #('>=' '>==>') tokens: {
		'' -> { ' 3' -> -0.2. '=>' -> -2.0 }.
		'=>' -> { 'x' -> -0.1 } }.
	self assert: (result at: #candidates) equals: #('>=' '>==>')
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testClassNamesDoNotContinueWithColons [
	| result |
	completer kind: #variables.
	result := self complete: 'Or' among: #('Ord' 'OrderedCollection') tokens: {
		'' -> { 'd:' -> -0.1. 'deredCollection new' -> -1.0 } }.
	self assert: (result at: #candidates) equals: #('Ord' 'OrderedCollection')
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testRequestsAskOneTokenWithLogProbabilities [
	self complete: 'si' among: #('size') tokens: { '' -> { 'ze ' -> -0.1 } }.
	transport requests do: [ :request |
		self assert: ((request at: 'options') at: 'num_predict') equals: 1.
		self assert: ((request at: 'options') at: 'temperature') equals: 0.
		self assert: (request at: 'logprobs').
		self assert: (request at: 'top_logprobs') equals: 20 ]
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testFailedRequestIsNotAMiss [
	completer vocabulary: #('size').
	transport responseBlock: [ :payload | self error: 'Connection unavailable' ].
	self should: [ completer candidatesFor: (self snapshotFor: 'si') ] raise: Error.
	self assert: transport requests size equals: 1
]

{ #category : 'tests' }
CooLLMBeamCompleterTest >> testVocabularyIsTheImage [
	| classes selectors |
	classes := CooLLMBeamCompleter namesFor: #variables.
	selectors := CooLLMBeamCompleter namesFor: #messages.
	self assert: (classes includes: 'OrderedCollection').
	self deny: (classes includes: 'size').
	self assert: (selectors includes: 'size').
	self assert: (selectors includes: 'at:put:').
	"Class-side selectors count too."
	self assert: (selectors includes: 'llmModels').
	self deny: (selectors includes: 'OrderedCollection').
	completer kind: #variables.
	self assert: ((completer namesStartingWith: 'OrderedCol') includes: 'OrderedCollection')
]
