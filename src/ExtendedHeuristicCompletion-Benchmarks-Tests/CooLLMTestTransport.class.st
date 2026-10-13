Class {
	#name : 'CooLLMTestTransport',
	#superclass : 'Object',
	#instVars : [ 'responseBlock', 'requests', 'answersLogprobs' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'initialization' }
CooLLMTestTransport >> initialize [
	super initialize.
	requests := OrderedCollection new.
	answersLogprobs := true.
	responseBlock := [ :payload | Dictionary newFrom: {
		'response' -> 'ze'. 'done' -> true. 'eval_count' -> 1 } ]
]

{ #category : 'accessing' }
CooLLMTestTransport >> responseBlock: aBlock [
	responseBlock := aBlock
]

{ #category : 'accessing' }
CooLLMTestTransport >> withoutLogprobs [
	"Behave like a server that ignores log-probability requests."
	answersLogprobs := false
]

{ #category : 'accessing' }
CooLLMTestTransport >> requests [
	^ requests
]

{ #category : 'requests' }
CooLLMTestTransport >> postJsonAt: path body: payload [
	| response |
	requests add: payload.
	response := responseBlock value: payload.
	"A log-probability request to a plain fixture lists only its answer, certain."
	((payload at: 'logprobs' ifAbsent: [ false ]) and: [
		answersLogprobs and: [ (response includesKey: 'logprobs') not ] ])
		ifTrue: [ response := response copy at: 'logprobs' put: (self logprobsFor: {
			(response at: 'response') -> 0.0 }); yourself ].
	^ response
]

{ #category : 'requests' }
CooLLMTestTransport >> logprobsFor: tokens [
	tokens ifEmpty: [ ^ #() ].
	^ { Dictionary newFrom: {
		'token' -> tokens first key. 'logprob' -> tokens first value.
		'top_logprobs' -> (tokens collect: [ :each |
			Dictionary newFrom: { 'token' -> each key. 'logprob' -> each value } ]) asArray } }
]

{ #category : 'requests' }
CooLLMTestTransport >> continuationIn: payload [
	"The text a beam appended after the rendered FIM prompt."
	| prompt marker |
	prompt := payload at: 'prompt'.
	marker := '<|fim_middle|>'.
	^ prompt allButFirst: (prompt findLastOccurrenceOfString: marker startingAt: 1) + marker size - 1
]

{ #category : 'accessing' }
CooLLMTestTransport >> nextTokens: aDictionary [
	"Beam tests: continuation -> token -> log-probability associations, most
	likely first. An unlisted continuation answers no tokens."
	responseBlock := [ :payload |
		| tokens |
		tokens := aDictionary at: (self continuationIn: payload) ifAbsent: [ #() ].
		Dictionary newFrom: {
			'response' -> (tokens ifEmpty: [ '' ] ifNotEmpty: [ tokens first key ]).
			'done' -> true. 'eval_count' -> 1.
			'logprobs' -> (self logprobsFor: tokens) } ]
]

{ #category : 'accessing' }
CooLLMTestTransport >> completeNames: names [
	"Beam tests: a model that knows only names, the earlier the likelier. After
	the typed text it answers, for the k-th name continuing that text, the
	rest of the name with log-probability -k squared; a name typed in full ends
	with a space."
	responseBlock := [ :payload |
		| before start typed tokens |
		before := (payload at: 'prompt') readStream upToAll: '<|fim_suffix|>'.
		start := before size.
		[ start > 0 and: [ (before at: start) isAlphaNumeric or: [ (before at: start) = $: ] ] ]
			whileTrue: [ start := start - 1 ].
		typed := (before copyFrom: start + 1 to: before size) , (self continuationIn: payload).
		tokens := ((names select: [ :each | each beginsWith: typed ]) withIndexCollect: [ :each :index |
			(each = typed ifTrue: [ ' ' ] ifFalse: [ each allButFirst: typed size ]) -> index squared negated asFloat ]) asArray.
		Dictionary newFrom: {
			'response' -> (tokens ifEmpty: [ '' ] ifNotEmpty: [ tokens first key ]).
			'done' -> true. 'eval_count' -> 1.
			'logprobs' -> (self logprobsFor: tokens) } ]
]
