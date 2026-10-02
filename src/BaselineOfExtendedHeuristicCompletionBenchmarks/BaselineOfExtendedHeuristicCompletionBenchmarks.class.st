Class {
	#name : 'BaselineOfExtendedHeuristicCompletionBenchmarks',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfExtendedHeuristicCompletionBenchmarks',
	#package : 'BaselineOfExtendedHeuristicCompletionBenchmarks'
}

{ #category : 'baselines' }
BaselineOfExtendedHeuristicCompletionBenchmarks >> baseline: spec [

	<baseline>
	spec for: #common do: [
			spec package: 'ExtendedHeuristicCompletion-Benchmarks'.

			"spec
				package: 'ExtendedHeuristicCompletion-Benchmarks-Tests'
				with: [ spec requires: #( 'ExtendedHeuristicCompletion-Benchmarks' ) ]" ]
]
