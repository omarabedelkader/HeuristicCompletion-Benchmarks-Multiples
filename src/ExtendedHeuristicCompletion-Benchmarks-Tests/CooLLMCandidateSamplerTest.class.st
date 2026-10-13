Class {
	#name : 'CooLLMCandidateSamplerTest',
	#superclass : 'TestCase',
	#instVars : [ 'transport', 'sampler' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooLLMCandidateSamplerTest >> setUp [
	super setUp.
	transport := CooLLMTestTransport new.
	sampler := CooLLMCandidateSampler new
		client: (CooLLMClient new transport: transport; yourself);
		kind: #messages;
		yourself
]

{ #category : 'helpers' }
CooLLMCandidateSamplerTest >> snapshotFor: source prefix: prefix [
	| node |
	node := ((OCParser parseMethod: source) methodClass: self class; yourself)
		allChildren detect: #isMessage.
	^ CooLLMContextSnapshot for: node prefix: prefix kind: #messages
]

{ #category : 'helpers' }
CooLLMCandidateSamplerTest >> respondInTurn: texts [
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> (texts at: ((payload at: 'options') at: 'seed') - 41 ifAbsent: [ '?' ]).
		'done' -> true. 'eval_count' -> 1 } ]
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testKeepsDistinctRealNamesInGenerationOrder [
	| names result |
	names := #('size'), ((1 to: 9) collect: [ :index | 'size', index printString ]).
	sampler vocabulary: names asSet.
	self respondInTurn: #('ze' 'ze' 'zz'), ((1 to: 9) collect: [ :index | 'ze', index printString ]).
	result := sampler candidatesFor: (self snapshotFor: 'example ^ self size' prefix: 'si').
	self assert: (result at: #complete).
	self assert: (result at: #candidates) equals: names asArray.
	self assert: ((result at: #attempts) collect: [ :each | each at: #status ]) asArray
		equals: #(accepted duplicate unknown), ((1 to: 9) collect: [ :index | #accepted ]).
	self assert: transport requests size equals: 12.
	self assert: (transport requests collect: [ :each | (each at: 'options') at: 'seed' ]) asArray
		equals: (42 to: 53) asArray
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testSampledRequestsStayOneToken [
	sampler vocabulary: Set new.
	sampler candidatesFor: (self snapshotFor: 'example ^ self size' prefix: 'si').
	transport requests do: [ :request |
		self assert: ((request at: 'options') at: 'num_predict') equals: 1.
		self assert: ((request at: 'options') at: 'temperature') equals: 0.8 ]
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testStopsAfterTwentyAttempts [
	| result |
	sampler vocabulary: #('size') asSet.
	self respondInTurn: #('ze').
	result := sampler candidatesFor: (self snapshotFor: 'example ^ self size' prefix: 'si').
	self deny: (result at: #complete).
	self assert: (result at: #candidates) equals: #('size').
	self assert: (result at: #attempts) size equals: 20.
	self assert: transport requests size equals: 20
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testNameMustContinueTypedPrefix [
	| result |
	sampler vocabulary: #('at:' 'at:put:') asSet.
	self respondInTurn: #('u' 'ut:').
	result := sampler candidatesFor: (self snapshotFor: 'example ^ self at: 1 put: 2' prefix: 'at:p').
	self assert: ((result at: #attempts) first at: #name) equals: 'at:'.
	self assert: ((result at: #attempts) first at: #status) equals: #unknown.
	self assert: (result at: #candidates) equals: #('at:put:')
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testFailedRequestIsNotARejectedCandidate [
	sampler vocabulary: Set new.
	transport responseBlock: [ :payload | self error: 'Connection unavailable' ].
	self should: [ sampler candidatesFor: (self snapshotFor: 'example ^ self size' prefix: 'si') ]
		raise: Error.
	self assert: transport requests size equals: 1
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testLeadingNameIsCutFromGeneratedCode [
	#(
		#('size. self new' 'size')
		#('size ' 'size')
		#('si' 'si')
		#('at:put: x' 'at:put:')
		#('at:pu' 'at:')
		#('printOn:' 'printOn:')
		#('>= 3' '>=')
		#('' '')
	) do: [ :pair |
		self assert: (CooLLMCandidateSampler leadingNameIn: pair first kind: #messages) equals: pair second ].
	self assert: (CooLLMCandidateSampler leadingNameIn: 'OrderedCollection new' kind: #variables)
		equals: 'OrderedCollection'.
	self assert: (CooLLMCandidateSampler leadingNameIn: 'Ord:' kind: #variables) equals: 'Ord'
]

{ #category : 'tests' }
CooLLMCandidateSamplerTest >> testVocabularyIsTheImage [
	| classes selectors |
	classes := CooLLMCandidateSampler vocabularyFor: #variables.
	selectors := CooLLMCandidateSampler vocabularyFor: #messages.
	self assert: (classes includes: 'OrderedCollection').
	self deny: (classes includes: 'size').
	self assert: (selectors includes: 'size').
	self assert: (selectors includes: 'at:put:').
	"Class-side selectors count too."
	self assert: (selectors includes: 'llmModels').
	self deny: (selectors includes: 'OrderedCollection')
]
