Class {
	#name : 'CooCandidateRecallBenchmarks',
	#superclass : 'CooNeuralRerankBenchmarks',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooCandidateRecallBenchmarks >> initialize [
	super initialize.
	candidateLimit := 50.
	name := 'Dependency candidate recall'
]

{ #category : 'ranking' }
CooCandidateRecallBenchmarks >> rankedCandidates: candidates context: context snapshot: snapshot record: record [
	^ candidates collect: #name
]
