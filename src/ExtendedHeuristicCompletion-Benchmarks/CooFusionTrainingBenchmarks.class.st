Class {
	#name : 'CooFusionTrainingBenchmarks',
	#superclass : 'CooNeuralRerankBenchmarks',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'initialization' }
CooFusionTrainingBenchmarks >> initialize [
	super initialize.
	name := 'Fusion training collector (not an evaluation strategy)'.
	candidateLimit := 50.
	client model: (CooBenchRunner llmModels at: #llm05B)
]

{ #category : 'ranking' }
CooFusionTrainingBenchmarks >> rankedCandidates: candidates context: context snapshot: snapshot record: record [
	"Bootstrap fusion examples without requiring an already fusion-trained ranker.
	Return the original dependency order; collector timings are not neural results."
	| generation content union start |
	start := Time microsecondClockValue.
	generation := client generateFor: snapshot.
	content := generation at: #content.
	content := content ifEmpty: [ '' ] ifNotEmpty: [ (context at: 'prefix') , content ].
	union := self unionOf: candidates with: content.
	record at: #generation put: generation;
		at: #generationMs put: (Time microsecondClockValue - start) / 1000.0;
		at: #unionCandidates put: (union collect: #asDictionary);
		at: #trainingCollection put: true.
	^ candidates collect: #name
]
