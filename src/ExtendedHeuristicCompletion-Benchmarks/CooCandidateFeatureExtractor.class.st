Class {
	#name : 'CooCandidateFeatureExtractor',
	#superclass : 'Object',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooCandidateFeatureExtractor >> candidatesFrom: entries sources: sources [
	| seen candidates |
	seen := Set new.
	candidates := OrderedCollection new.
	entries withIndexDo: [ :entry :rank |
		(seen includes: entry contents asString) ifFalse: [
			seen add: entry contents asString.
			candidates add: (CooRankingCandidate name: entry contents asString rank: rank
				source: (sources at: entry ifAbsent: [ 'unknown' ])) ] ].
	^ candidates asArray
]
