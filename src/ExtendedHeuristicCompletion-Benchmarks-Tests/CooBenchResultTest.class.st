Class {
	#name : 'CooBenchResultTest',
	#superclass : 'CoMiniTestCase',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'tests' }
CooBenchResultTest >> createResultNamed: aString values: anArray [

        | result |
        result := CooBenchResult new.
        result name: aString.

        (2 to: 8) withIndexDo: [ :prefix :index |
                | column |
                column := CooResultColumn new.
                column title: prefix asString.
                column addElement: (anArray at: index).
                result addColumn: column ].

        ^ result
]

{ #category : 'tests' }
CooBenchResultTest >> testCompletionIndexesAreStable [
        | result |
        result := CooBenchResult new.
        self
                assert: result completionIndexes
                equals:
                        { 1 to: 1.
                        2 to: 2.
                        3 to: 3.
                        4 to: 10.
                        0 to: 0 }
]

{ #category : 'tests' }
CooBenchResultTest >> testComputeRatioBuildsResultUsingBaseline [
        | baseline other ratio |
        baseline := self
                        createResultNamed: 'Baseline'
                        values: #( 10 20 30 40 50 60 70 ).
        other := self
                        createResultNamed: 'Other'
                        values: #( 5 10 15 20 25 30 35 ).

        ratio := baseline computeRatioWithReceiverAsBaselineComparedTo: other.

        self assert: ratio name equals: 'Baseline/Other'.
        self assert: ratio columns size equals: 7.
        ratio columns
                do: [ :column |
                        self
                                assert: column elements size
                                equals: 1.
                        self
                                assert: column elements first
                                equals: 0.5 ]
]

{ #category : 'tests' }
CooBenchResultTest >> testPrintOnFormatsColumnsAndRows [
        | result firstColumn secondColumn printed expected |
        result := CooBenchResult new.
        firstColumn := CooResultColumn new.
        firstColumn title: '2'.
        firstColumn addElement: 10.
        firstColumn addElement: 20.
        result addColumn: firstColumn.
        secondColumn := CooResultColumn new.
        secondColumn title: '3'.
        secondColumn addElement: 30.
        secondColumn addElement: 40.
        result addColumn: secondColumn.
        printed := String streamContents: [ :stream | result printOn: stream ].
        expected := String
                        streamContents: [ :stream |
                                stream nextPutAll: ('2' padRightTo: 6);
                                        space.
                                stream nextPutAll: ('3' padRightTo: 6);
                                        space.
                                stream cr.
                                stream nextPutAll: ('10' padRightTo: 6);
                                        space.
                                stream nextPutAll: ('30' padRightTo: 6);
                                        space.
                                stream cr.
                                stream nextPutAll: ('20' padRightTo: 6);
                                        space.
                                stream nextPutAll: ('40' padRightTo: 6);
                                        space ].
        self assert: printed equals: expected
]
