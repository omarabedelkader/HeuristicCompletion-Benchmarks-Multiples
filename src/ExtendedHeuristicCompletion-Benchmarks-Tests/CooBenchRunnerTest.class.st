Class {
	#name : 'CooBenchRunnerTest',
	#superclass : 'CoMiniTestCase',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'tests' }
CooBenchRunnerTest >> accuracyResultNamed: aString values: anArray [

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
CooBenchRunnerTest >> sampleMmrString [
        ^ String streamContents: [ :stream |
                stream
                        nextPutAll: 'mmr: 0.9';
                        cr;
                        nextPutAll: '2 0.8';
                        cr;
                        nextPutAll: '3 0.7' ]
]

{ #category : 'tests' }
CooBenchRunnerTest >> setResultsOn: aRunner with: aDictionary [
        aRunner instVarNamed: #results put: aDictionary
]

{ #category : 'tests' }
CooBenchRunnerTest >> testCompletionIndexesDefinesMappingsForResultColumns [
        | result |
        result := CooBenchResult new.

        self
                assert: result completionIndexes
                equals: { 1 to: 1. 2 to: 2. 3 to: 3. 4 to: 10. 0 to: 0 }
]

{ #category : 'tests' }
CooBenchRunnerTest >> testComputeDeltaReturnsDifferenceBetweenBaselineAndOther [

        | runner baselineResult otherResult |
        runner := CooBenchRunner new.
        runner baseline: #baseline.
        runner others: { #other }.

        baselineResult := CooBenchRunnerTestBenchmarkStub new
                                mmr: 3;
                                yourself.
        otherResult := CooBenchRunnerTestBenchmarkStub new
                                mmr: 5;
                                yourself.

        self
                setResultsOn: runner
                with: (Dictionary newFrom:
                                { #baseline -> baselineResult.
                                #other -> otherResult }).

        self assert: runner computeDelta equals: 2
]

{ #category : 'tests' }
CooBenchRunnerTest >> testComputeDeltaUsesFirstOtherWhenMultipleOthersArePresent [
        | runner baselineResult firstOther secondOther |
        runner := CooBenchRunner new.
        runner baseline: #baseline.
        runner others: { #otherOne. #otherTwo }.

        baselineResult := CooBenchRunnerTestBenchmarkStub new
                                mmr: 4;
                                yourself.
        firstOther := CooBenchRunnerTestBenchmarkStub new
                                mmr: 10;
                                yourself.
        secondOther := CooBenchRunnerTestBenchmarkStub new
                                mmr: 100;
                                yourself.

        self
                setResultsOn: runner
                with: (Dictionary newFrom:
                                { #baseline -> baselineResult.
                                #otherOne -> firstOther.
                                #otherTwo -> secondOther }).

        self assert: runner computeDelta equals: 6
]

{ #category : 'tests' }
CooBenchRunnerTest >> testComputeRatioBuildsResultFromAccuracyTables [

        | runner baselineResult otherResult ratio |
        runner := CooBenchRunner new.
        runner baseline: #baseline.
        runner others: { #other }.

        baselineResult := CooBenchRunnerTestBenchmarkStub new
                                accuracyResults: (self accuracyResultNamed: 'Baseline' values: #( 50 40 30 20 10 5 1 ));
                                yourself.
        otherResult := CooBenchRunnerTestBenchmarkStub new
                                accuracyResults: (self accuracyResultNamed: 'Other' values: #( 25 20 15 10 5 2.5 0.5 ));
                                yourself.

        self
                setResultsOn: runner
                with: (Dictionary newFrom:
                                { #baseline -> baselineResult.
                                #other -> otherResult }).

        ratio := runner computeRatio.

        self assert: ratio name equals: 'Baseline/Other'.
        ratio columns
                do: [ :column |
                        self
                                assert: column elements first
                                equals: 0.5 ]
]

{ #category : 'tests' }
CooBenchRunnerTest >> testLatexTableResultIncludesPackageMetricAndValues [
        | package bench result latex |
        package := CooBenchRunnerTestPackageStub new.
        package name: 'SamplePackage'.

        bench := CooBenchRunnerTestBenchStub new.
        bench package: package.

        result := CooBenchRunnerTestResultStub new.
        result mmrString: self sampleMmrString.

        bench results: (Dictionary newFrom: { #metric -> result }).

        latex := CooBenchRunner latexTableResultForABenchCollection: { bench }.

        self
                assert: (latex includesSubstring: '\begin{tabular}{lll').
        self
                assert: (latex includesSubstring: 'Package & Metric & MMR & 2 & 3 \\').
        self
                assert: (latex includesSubstring: 'SamplePackage & metric & 0.9 & 0.8 & 0.7 \\').
        self assert: (latex includesSubstring: '\end{tabular}')
]

{ #category : 'tests' }
CooBenchRunnerTest >> testLatexTableResultRendersRowsForMultipleBenchmarks [
        | firstPackage secondPackage firstBench secondBench firstResult secondResult latex |
        firstPackage := CooBenchRunnerTestPackageStub new.
        firstPackage name: 'SamplePackage'.
        secondPackage := CooBenchRunnerTestPackageStub new.
        secondPackage name: 'AnotherPackage'.

        firstBench := CooBenchRunnerTestBenchStub new.
        firstBench package: firstPackage.
        firstResult := CooBenchRunnerTestResultStub new.
        firstResult mmrString: self sampleMmrString.
        firstBench results: (Dictionary newFrom: { #metric -> firstResult }).

        secondBench := CooBenchRunnerTestBenchStub new.
        secondBench package: secondPackage.
        secondResult := CooBenchRunnerTestResultStub new.
        secondResult
                mmrString:
                        (String streamContents: [ :stream |
                                 stream
                                         nextPutAll: 'mmr: 0.95';
                                         cr;
                                         nextPutAll: '2 0.85';
                                         cr;
                                         nextPutAll: '3 0.75';
                                         cr;
                                         nextPutAll: '4 0.65' ]).
        secondBench results: (Dictionary newFrom: { #metric -> secondResult }).

        latex := CooBenchRunner latexTableResultForABenchCollection: { firstBench. secondBench }.

        self
                assert: (latex includesSubstring: 'Package & Metric & MMR & 2 & 3 & 4 \\').
        self
                assert: (latex includesSubstring: 'SamplePackage & metric & 0.9 & 0.8 & 0.7 \\').
        self
                assert: (latex includesSubstring: 'AnotherPackage & metric & 0.95 & 0.85 & 0.75 & 0.65 \\').
]

{ #category : 'tests' }
CooBenchRunnerTest >> testPrefixSizesEnumeratesTwoToEight [
        | result |
        result := CooBenchResult new.

        self assert: result prefixSizes equals: (2 to: 8)
]

{ #category : 'tests' }
CooBenchRunnerTest >> testRunPopulatesResultsUsingSelectors [
        | runner |
        runner := CooBenchRunnerTestRunnerStub new.
        runner baseline: #baselineResultSelector.
        runner others: { #otherResultSelector }.

        runner run.

        self
                assert: (runner results at: #baselineResultSelector)
                equals: 'baseline-result'.
        self
                assert: (runner results at: #otherResultSelector)
                equals: 'other-result'.
        self assert: runner baselineCallCount equals: 1.
        self assert: runner otherCallCount equals: 1
]

{ #category : 'tests' }
CooBenchRunnerTest >> testStringResultForBenchCollectionIncludesAllMetrics [
        | package bench firstResult secondResult formatted |
        package := CooBenchRunnerTestPackageStub new.
        package name: 'SamplePackage'.

        bench := CooBenchRunnerTestBenchStub new.
        bench package: package.

        firstResult := CooBenchRunnerTestResultStub new.
        firstResult mmrString: self sampleMmrString.

        secondResult := CooBenchRunnerTestResultStub new.
        secondResult mmrString:
                (String streamContents: [ :stream |
                        stream
                                nextPutAll: 'mmr: 0.5';
                                cr;
                                nextPutAll: '2 0.4';
                                cr;
                                nextPutAll: '3 0.3' ]).

        bench
                results:
                        (Dictionary newFrom:
                                 { #metricA -> firstResult.
                                 #metricB -> secondResult }).

        formatted := CooBenchRunner stringResultForABenchCollection: { bench }.

        self assert: (formatted includesSubstring: 'SamplePackage').
        self assert: (formatted includesSubstring: 'metricA').
        self assert: (formatted includesSubstring: 'metricB').
        self assert: (formatted includesSubstring: 'mmr: 0.9').
        self assert: (formatted includesSubstring: 'mmr: 0.5')
]
