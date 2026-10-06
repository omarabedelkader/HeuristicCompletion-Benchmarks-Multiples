Class {
	#name : 'CooRankingHeuristic',
	#superclass : 'CoASTNodeFetcherHeuristic',
	#instVars : [ 'wrapped', 'sources' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooRankingHeuristic class >> on: heuristic sources: dictionary [
	(heuristic respondsTo: #next) ifFalse: [ ^ heuristic ].
	^ self new wrapped: heuristic; sources: dictionary;
		next: (self on: heuristic next sources: dictionary); yourself
]

{ #category : 'ranking' }
CooRankingHeuristic >> sources: dictionary [
	sources := dictionary
]

{ #category : 'ranking' }
CooRankingHeuristic >> wrapped: heuristic [
	wrapped := heuristic
]

{ #category : 'ranking' }
CooRankingHeuristic >> appliesForNode: node inContext: context [
	^ wrapped appliesForNode: node inContext: context
]

{ #category : 'ranking' }
CooRankingHeuristic >> buildFetcherFor: node inContext: context [
	^ (wrapped buildFetcherFor: node inContext: context) collect: [ :entry |
		sources at: entry put: wrapped class name asString.
		entry ]
]
