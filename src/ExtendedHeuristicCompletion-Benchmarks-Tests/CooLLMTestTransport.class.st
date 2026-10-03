Class {
	#name : 'CooLLMTestTransport',
	#superclass : 'Object',
	#instVars : [ 'responseBlock', 'requests' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'initialization' }
CooLLMTestTransport >> initialize [
	super initialize.
	requests := OrderedCollection new.
	responseBlock := [ :payload | Dictionary newFrom: {
		'response' -> 'ze'. 'done' -> true. 'eval_count' -> 1 } ]
]

{ #category : 'accessing' }
CooLLMTestTransport >> responseBlock: aBlock [
	responseBlock := aBlock
]

{ #category : 'accessing' }
CooLLMTestTransport >> requests [
	^ requests
]

{ #category : 'requests' }
CooLLMTestTransport >> postJsonAt: path body: payload [
	requests add: payload.
	^ responseBlock value: payload
]
