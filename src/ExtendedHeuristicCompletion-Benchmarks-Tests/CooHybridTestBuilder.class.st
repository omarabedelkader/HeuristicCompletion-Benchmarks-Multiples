Class {
	#name : 'CooHybridTestBuilder',
	#superclass : 'Object',
	#instVars : [ 'node', 'context', 'names', 'buildBlock', 'fetchBlock' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'initialization' }
CooHybridTestBuilder >> initialize [
	super initialize.
	names := #().
	buildBlock := [ :aNode :aContext | ].
	fetchBlock := [ ]
]

{ #category : 'accessing' }
CooHybridTestBuilder >> node: aNode [
	node := aNode
]

{ #category : 'accessing' }
CooHybridTestBuilder >> completionContext: aContext [
	context := aContext
]

{ #category : 'accessing' }
CooHybridTestBuilder >> names: strings [
	names := strings
]

{ #category : 'accessing' }
CooHybridTestBuilder >> buildBlock: aBlock [
	buildBlock := aBlock
]

{ #category : 'accessing' }
CooHybridTestBuilder >> fetchBlock: aBlock [
	fetchBlock := aBlock
]

{ #category : 'building' }
CooHybridTestBuilder >> buildCompletion [
	buildBlock value: node value: context.
	^ self
]

{ #category : 'building' }
CooHybridTestBuilder >> replaceFilterWith: aFilter [
	"Fixed rankings isolate fusion tests; population tests use the real builder."
]

{ #category : 'building' }
CooHybridTestBuilder >> first: count [
	fetchBlock value.
	^ (names first: (count min: names size)) collect: [ :each | each readStream ]
]
