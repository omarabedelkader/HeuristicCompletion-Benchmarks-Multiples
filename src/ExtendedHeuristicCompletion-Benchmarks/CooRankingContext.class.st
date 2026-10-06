Class {
	#name : 'CooRankingContext',
	#superclass : 'Object',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooRankingContext class >> for: node prefix: prefix kind: kind [
	| snapshot |
	snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
	^ self fromSnapshot: snapshot receiverKind: (self receiverKindFor: node)
]

{ #category : 'ranking' }
CooRankingContext class >> fromSnapshot: snapshot receiverKind: receiverKind [
	"Explicit allowlist: no target, full source, suffix or audit method identity."
	^ Dictionary newFrom: {
		'schema' -> 'coo-ranking-v1'. 'kind' -> (snapshot at: #kind) asString.
		'prefix' -> (snapshot at: #prefix). 'sourcePrefix' -> (snapshot at: #sourcePrefix).
		'receiverKind' -> receiverKind }
]

{ #category : 'ranking' }
CooRankingContext class >> receiverKindFor: node [
	| receiver |
	node isMessage ifFalse: [ ^ 'global' ].
	receiver := node receiver.
	receiver isSelfVariable ifTrue: [ ^ 'self' ].
	receiver isSuperVariable ifTrue: [ ^ 'super' ].
	receiver isLiteralNode ifTrue: [ ^ 'literal' ].
	receiver isVariable ifTrue: [
		^ receiver name first isUppercase ifTrue: [ 'global' ] ifFalse: [ 'variable' ] ].
	^ 'unknown' 
]
