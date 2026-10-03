Class {
	#name : 'CooHybridTestHeuristics',
	#superclass : 'Object',
	#instVars : [ 'fail', 'seenPrefix' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'accessing' }
CooHybridTestHeuristics >> fail: aBoolean [
	fail := aBoolean
]

{ #category : 'accessing' }
CooHybridTestHeuristics >> seenPrefix [
	^ seenPrefix
]

{ #category : 'benchmarks' }
CooHybridTestHeuristics >> buildCompletionFor: node atPosition: position [
	seenPrefix := node isMessage ifTrue: [ node selector asString ] ifFalse: [ node name ].
	^ #()
]

{ #category : 'benchmarks' }
CooHybridTestHeuristics >> fetchTopCandidatesFrom: completion usingPrefix: prefix [
	fail = true ifTrue: [ self error: 'Heuristic fetch failed' ].
	^ #()
]
