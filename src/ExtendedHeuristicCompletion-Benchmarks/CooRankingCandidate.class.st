Class {
	#name : 'CooRankingCandidate',
	#superclass : 'Object',
	#instVars : [ 'data' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooRankingCandidate class >> entry: entry rank: rank [
	| source |
	source := (entry respondsTo: #propertyAt:ifAbsent:)
		ifTrue: [ entry propertyAt: #cooHeuristicSource ifAbsent: [ 'unknown' ] ]
		ifFalse: [ 'unknown' ].
	^ self name: entry contents asString rank: rank source: source
]

{ #category : 'ranking' }
CooRankingCandidate class >> name: name rank: rank source: source [
	^ self new data: (Dictionary newFrom: {
		'name' -> name. 'rank' -> rank. 'heuristicSource' -> source.
		'inferredType' -> nil. 'lmAgreement' -> false }); yourself
]

{ #category : 'ranking' }
CooRankingCandidate >> data: dictionary [
	data := dictionary
]

{ #category : 'ranking' }
CooRankingCandidate >> asDictionary [
	^ data copy
]

{ #category : 'ranking' }
CooRankingCandidate >> name [
	^ data at: 'name'
]

{ #category : 'ranking' }
CooRankingCandidate >> markLMAgreement [
	data at: 'lmAgreement' put: true
]
