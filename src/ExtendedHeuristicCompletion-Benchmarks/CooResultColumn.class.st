"
A class used inside the bench
"
Class {
	#name : 'CooResultColumn',
	#superclass : 'Object',
	#instVars : [
		'title',
		'elements'
	],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Results',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Results'
}

{ #category : 'accessing' }
CooResultColumn >> addElement: anElement [

	elements add: anElement
]

{ #category : 'accessing' }
CooResultColumn >> elements [

	^ elements
]

{ #category : 'accessing' }
CooResultColumn >> elements: anObject [

	elements := anObject
]

{ #category : 'accessing' }
CooResultColumn >> initialize [ 
	super initialize.
	elements := OrderedCollection new 
]

{ #category : 'printing' }
CooResultColumn >> printOn: aStream [
	aStream nextPutAll: title; nextPutAll: ' -- '.
	elements 
		do: [ :e | e printOn: aStream ]
		separatedBy: [ aStream space ]
]

{ #category : 'accessing' }
CooResultColumn >> title [

	^ title
]

{ #category : 'accessing' }
CooResultColumn >> title: anObject [

	title := anObject
]
