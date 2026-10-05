Class {
	#name : 'CooAdaptiveHybridBenchmarks',
	#superclass : 'CooNeuralRerankBenchmarks',
	#instVars : [ 'marginThreshold', 'entropyThreshold' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooAdaptiveHybridBenchmarks >> initialize [
	super initialize.
	name := 'AdaptiveRank + 0.5B'.
	marginThreshold := 0.2.
	entropyThreshold := 0.8.
	client model: (CooBenchRunner llmModels at: #llm05B)
]

{ #category : 'ranking' }
CooAdaptiveHybridBenchmarks >> marginThreshold: value [
	(value between: 0 and: 1) ifFalse: [ self error: 'Margin must be between zero and one' ].
	marginThreshold := value
]

{ #category : 'ranking' }
CooAdaptiveHybridBenchmarks >> entropyThreshold: value [
	(value between: 0 and: 1) ifFalse: [ self error: 'Entropy must be between zero and one' ].
	entropyThreshold := value
]

{ #category : 'ranking' }
CooAdaptiveHybridBenchmarks >> rankedCandidates: candidates context: context snapshot: snapshot record: record [
	| response ranked margin entropy stage generation content union fusion |
	response := ranker rank: candidates context: context.
	ranked := (response at: 'scores') collect: #first.
	margin := ranker marginOf: response.
	entropy := ranker entropyOf: response.
	record at: #ranking put: response; at: #fallbackCalled put: false;
		at: #margin put: margin; at: #entropy put: entropy;
		at: #marginThreshold put: marginThreshold; at: #entropyThreshold put: entropyThreshold.
	(candidates notEmpty and: [ margin >= marginThreshold and: [ entropy <= entropyThreshold ] ])
		ifTrue: [ ^ ranked ].
	(response at: 'fusionTrained' ifAbsent: [ false ]) ifFalse: [
		self error: 'Adaptive fusion requires a model trained on LM union observations' ].
	record at: #fallbackCalled put: true.
	stage := Time microsecondClockValue.
	generation := client generateFor: snapshot.
	record at: #generation put: generation;
		at: #generationMs put: (Time microsecondClockValue - stage) / 1000.0.
	content := generation at: #content.
	content ifEmpty: [ ^ ranked ].
	stage := Time microsecondClockValue.
	content := (context at: 'prefix') , content.
	union := self unionOf: candidates with: content.
	record at: #fusionMs put: (Time microsecondClockValue - stage) / 1000.0;
		at: #unionCandidates put: (union collect: #asDictionary) asArray.
	fusion := ranker rank: union asArray context: context.
	(fusion at: 'modelId') = (response at: 'modelId') ifFalse: [ self error: 'Ranker model changed during fusion' ].
	record at: #fusionRanking put: fusion.
	^ (fusion at: 'scores') collect: #first
]
