"
I represent a result.
I'm like a dictionary but I'm handy for defining treaments on the result such as ratio, diff, latex...

"
Class {
	#name : 'CooBenchResult',
	#superclass : 'Object',
	#instVars : [
		'name',
		'columns'
	],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Results',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Results'
}

{ #category : 'inspector' }
CooBenchResult >> accuracyInspectionResults [
	"Generates a table displaying completion accuracy."

	"<inspectorPresentationOrder: 0 title: 'Accuracy'>"
	"does not work."
	
	| table |
	table := SpTablePresenter new.
 	table items: columns. 

	columns do: [ :column |
		table addColumn: (SpStringTableColumn
				 title: column title
				 evaluated: [ :c | c elements ])].
	^ table
]

{ #category : 'adding' }
CooBenchResult >> addColumn: aCooResultColumn [ 
	columns add: aCooResultColumn 
]

{ #category : 'accessing' }
CooBenchResult >> columns [
	^ columns
	
]

{ #category : 'accessing' }
CooBenchResult >> completionIndexes [
	"I copied this but it should not it should be part of the structure."
	
	^ { 1 to: 1.
	  2 to: 2.
	  3 to: 3.
	  4 to: 10.
	  0 to: 0.
	}
]

{ #category : 'operations' }
CooBenchResult >> computeRatioWithReceiverAsBaselineComparedTo: anotherResult [

	| table |
	table := CooBenchResult new. 
	table name: self name, '/', anotherResult name.
	
	self prefixSizes do: [ :prefixSize |
		| col |
		col := CooResultColumn new.
		col title: prefixSize asString.
		table addColumn: col.
		
		(columns at: (prefixSize -1)) elements 
			with: (anotherResult columns at: (prefixSize -1)) elements 
			do: [ :a :b | col addElement: ((b/a) asFloat round: 2)] ].
	^ table
]

{ #category : 'initialization' }
CooBenchResult >> initialize [

	super initialize.
	columns := OrderedCollection new.
	name := ''
]

{ #category : 'accessing' }
CooBenchResult >> name [

	^ name
]

{ #category : 'accessing' }
CooBenchResult >> name: anObject [

	name := anObject
]

{ #category : 'accessing' }
CooBenchResult >> prefixSizes [ 
	^ 2 to: 8
]

{ #category : 'initialization' }
CooBenchResult >> printOn: aStream [

	columns do: [:c | aStream nextPutAll: (c title padRightTo: 6); space ].
	
	1 to: columns first elements size do: [ :i |  
		aStream cr. 
		columns do: [ :c |
				aStream nextPutAll: ((c elements at: i) asString padRightTo: 6). 
				aStream space
			 ]
		]
]
