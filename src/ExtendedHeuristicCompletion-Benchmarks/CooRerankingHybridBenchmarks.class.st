Class {
	#name : 'CooRerankingHybridBenchmarks',
	#superclass : 'CooHybridLLMBenchmarks',
	#instVars : [ 'neuralWeight', 'dependencyWeight', 'baselineWeight' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'initialization' }
CooRerankingHybridBenchmarks >> initialize [
	super initialize.
	name := 'Hybrid (candidate reranking)'.
	experiment := #ranking.
	self weights: #(1 1 1)
]

{ #category : 'accessing' }
CooRerankingHybridBenchmarks >> weights: weights [
	(weights size = 3 and: [ (weights allSatisfy: [ :w | w isNumber and: [ w >= 0 ] ])
		and: [ weights sum > 0 ] ]) ifFalse: [ self error: 'Expected three nonnegative weights with positive sum' ].
	neuralWeight := weights first asFloat.
	dependencyWeight := weights second asFloat.
	baselineWeight := weights third asFloat
]

{ #category : 'benchmarks' }
CooRerankingHybridBenchmarks >> enrichSnapshot: snapshot for: node [
	| start |
	start := self startTimeMeasurement.
	snapshot at: #heuristicCandidates put: (self candidatesFor: node prefix: (snapshot at: #prefix));
		at: #heuristicMs put: self startTimeMeasurement - start;
		at: #contextPolicy put: 'prefix-only-candidate-reranking-v1';
		at: #heuristicSources put: (heuristics collect: [ :source | source key asString ]) asArray
]

{ #category : 'benchmarks' }
CooRerankingHybridBenchmarks >> generationFor: snapshot [
	^ client rerankFor: snapshot
]

{ #category : 'private' }
CooRerankingHybridBenchmarks >> validatedOrderFrom: generation size: size [
	| order |
	size = 0 ifTrue: [ ^ #() ].
	order := STONJSON fromString: (generation at: #content).
	((order isArray and: [ order size = size ]) and: [
		(order allSatisfy: [ :id | id isInteger and: [ id between: 1 and: size ] ])
			and: [ order asSet size = size ] ]) ifFalse: [
		self error: 'Reranker must return each candidate ID exactly once' ].
	^ order
]

{ #category : 'private' }
CooRerankingHybridBenchmarks >> reciprocalRankOf: source in: hint [
	| rank |
	rank := (hint at: #ranks) detect: [ :each | (each at: #source) = source ] ifNone: [ nil ].
	^ rank ifNil: [ 0 ] ifNotNil: [ 1.0 / (rank at: #rank) ]
]

{ #category : 'benchmarks' }
CooRerankingHybridBenchmarks >> candidatesFrom: generation snapshot: snapshot record: record [
	| hints order scored sorted |
	hints := snapshot at: #heuristicCandidates.
	order := self validatedOrderFrom: generation size: hints size.
	scored := hints withIndexCollect: [ :hint :id |
		| neuralRank score |
		neuralRank := order indexOf: id.
		score := (neuralWeight / neuralRank)
			+ (dependencyWeight * (self reciprocalRankOf: 'Dependency' in: hint))
			+ (baselineWeight * (self reciprocalRankOf: 'Baseline' in: hint)).
		Dictionary newFrom: { #id -> id. #candidate -> (hint at: #candidate).
			#neuralRank -> neuralRank. #score -> score. #ranks -> ((hint at: #ranks) collect: [ :rank | rank copy ]) } ].
	sorted := scored sorted: [ :a :b |
		(a at: #score) = (b at: #score)
			ifTrue: [ (a at: #id) < (b at: #id) ]
			ifFalse: [ (a at: #score) > (b at: #score) ] ].
	record at: #neuralOrder put: order;
		at: #weights put: { neuralWeight. dependencyWeight. baselineWeight };
		at: #scores put: sorted asArray.
	^ (sorted first: (sorted size min: 10)) collect: [ :each | each at: #candidate ]
]
