Class {
	#name : 'CooBenchRunnerTestRunnerStub',
	#superclass : 'CooBenchRunner',
	#instVars : [
		'baselineCallCount',
		'otherCallCount'
	],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'initialization' }
CooBenchRunnerTestRunnerStub >> baselineCallCount [
    ^ baselineCallCount
]

{ #category : 'initialization' }
CooBenchRunnerTestRunnerStub >> baselineResultSelector [
    baselineCallCount := baselineCallCount + 1.
    ^ 'baseline-result'
]

{ #category : 'initialization' }
CooBenchRunnerTestRunnerStub >> initialize [
    super initialize.
    baselineCallCount := 0.
    otherCallCount := 0
]

{ #category : 'initialization' }
CooBenchRunnerTestRunnerStub >> otherCallCount [
    ^ otherCallCount
]

{ #category : 'initialization' }
CooBenchRunnerTestRunnerStub >> otherResultSelector [
    otherCallCount := otherCallCount + 1.
    ^ 'other-result'
]
