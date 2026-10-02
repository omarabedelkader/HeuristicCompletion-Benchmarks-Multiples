Class {
	#name : 'CooResultColumnTest',
	#superclass : 'CoMiniTestCase',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'tests' }
CooResultColumnTest >> testAddElementAppendsValuesInOrder [

    | column |
    column := CooResultColumn new.
    column title: '2'.
    column addElement: 10.
    column addElement: 20.

    self assert: column elements asArray equals: #( 10 20 ).
]

{ #category : 'tests' }
CooResultColumnTest >> testPrintOnIncludesTitleAndElements [

    | column printed |
    column := CooResultColumn new.
    column title: 'Accuracy'.
    column addElement: 0.5.
    column addElement: 0.75.

    printed := String streamContents: [ :stream | column printOn: stream ].

    self assert: printed equals: 'Accuracy -- 0.5 0.75'.
]
