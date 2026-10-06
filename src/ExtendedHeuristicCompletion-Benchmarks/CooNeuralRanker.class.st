Class {
	#name : 'CooNeuralRanker',
	#superclass : 'Object',
	#instVars : [ 'client' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooNeuralRanker >> initialize [
	super initialize.
	client := CooNeuralRankerClient new
]

{ #category : 'ranking' }
CooNeuralRanker >> client: object [
	client := object
]

{ #category : 'ranking' }
CooNeuralRanker >> rank: candidates context: context [
	^ client rank: candidates context: context
]

{ #category : 'ranking' }
CooNeuralRanker >> marginOf: response [
	| scores |
	scores := response at: 'scores'.
	scores ifEmpty: [ ^ 0.0 ].
	^ scores first second - (scores size > 1 ifTrue: [ scores second second ] ifFalse: [ 0 ])
]

{ #category : 'ranking' }
CooNeuralRanker >> entropyOf: response [
	| scores entropy |
	scores := response at: 'scores'.
	scores ifEmpty: [ ^ 1.0 ].
	scores size = 1 ifTrue: [ ^ 0.0 ].
	entropy := 0.0.
	scores do: [ :pair | pair second > 0 ifTrue: [ entropy := entropy - (pair second * pair second ln) ] ].
	^ entropy / scores size ln
]
