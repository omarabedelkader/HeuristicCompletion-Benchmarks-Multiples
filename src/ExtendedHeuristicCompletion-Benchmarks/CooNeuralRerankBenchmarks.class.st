Class {
	#name : 'CooNeuralRerankBenchmarks',
	#superclass : 'CooHybridBenchmarks',
	#instVars : [ 'ranker', 'candidateLimit', 'candidateSources' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> initialize [
	super initialize.
	name := 'NeuralRank-30'.
	candidateLimit := 30.
	ranker := CooNeuralRanker new
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> candidateLimit: k [
	(#(10 20 30 50) includes: k) ifFalse: [ self error: 'Candidate K must be 10, 20, 30 or 50' ].
	candidateLimit := k.
	self class = CooNeuralRerankBenchmarks ifTrue: [ name := 'NeuralRank-', k asString ]
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> ranker: object [
	ranker := object
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> builder: object [
	"Decorate only this benchmark's builder; never change shared heuristic classes."
	super builder: object.
	candidateSources := IdentityDictionary new.
	(builder respondsTo: #messagesHeuristic) ifTrue: [
		builder messagesHeuristic: (CooRankingHeuristic on: builder messagesHeuristic sources: candidateSources).
		builder variablesHeuristic: (CooRankingHeuristic on: builder variablesHeuristic sources: candidateSources) ]
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> entriesFor: node atPosition: position prefix: prefix [
	| original completion |
	candidateSources ifNil: [ candidateSources := IdentityDictionary new ].
	candidateSources removeAll.
	original := node isMessage ifTrue: [ node selectorNode value ] ifFalse: [ node name ].
	[
		node isMessage ifTrue: [ node selectorNode value: prefix ] ifFalse: [ node name: prefix ].
		completion := self buildCompletionFor: node atPosition: position.
		completion replaceFilterWith: (CoCaseSensitiveBeginsWithFilter filterString: prefix).
		"Some images sort each fetched batch. Preserve the legacy first ten,
		then extend in identical batches so K sweeps have nested candidate pools."
		10 to: candidateLimit by: 10 do: [ :limit | completion first: limit ].
		^ (completion first: candidateLimit) asArray
	] ensure: [ node isMessage
		ifTrue: [ node selectorNode value: original ] ifFalse: [ node name: original ] ]
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> rankedCandidates: candidates context: context snapshot: snapshot record: record [
	| response |
	response := ranker rank: candidates context: context.
	record at: #ranking put: response; at: #fallbackCalled put: false.
	^ (response at: 'scores') collect: #first
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> benchCallsite: node atPosition: position [
	| target |
	target := node isMessage ifTrue: [ node selector asString ] ifFalse: [ node name ].
	2 to: (target size min: 8) do: [ :size |
		| prefix start memory record snapshot context entries candidates names final rank stage |
		start := Time microsecondClockValue.
		memory := self startMemoryMeasurement.
		prefix := target first: size.
		record := Dictionary new.
		records add: record.
		[
			stage := Time microsecondClockValue.
			entries := self entriesFor: node atPosition: position prefix: prefix.
			record at: #candidateGenerationMs put: (Time microsecondClockValue - stage) / 1000.0.
			stage := Time microsecondClockValue.
			snapshot := CooLLMContextSnapshot for: node prefix: prefix kind: kind.
			context := CooRankingContext fromSnapshot: snapshot receiverKind: (CooRankingContext receiverKindFor: node).
			candidates := CooCandidateFeatureExtractor new candidatesFrom: entries sources: candidateSources.
			record at: #featureExtractionMs put: (Time microsecondClockValue - stage) / 1000.0.
			names := candidates collect: #name.
			record addAll: context;
				at: 'candidates' put: (candidates collect: #asDictionary);
				at: 'group' put: node methodNode methodClass instanceSide package name;
				at: 'target' put: target;
				at: #snapshot put: snapshot;
				at: #candidateLimit put: candidateLimit;
				at: #candidateRank put: (names indexOf: target).
			final := self rankedCandidates: candidates context: context snapshot: snapshot record: record.
			final := (final first: (10 min: final size)) asArray.
			rank := final indexOf: target.
			record at: #finalCandidates put: final; at: #rank put: rank.
			self trackCompletionResultsFor: target atIndex: rank withPrefix: prefix.
			record at: #memoryBytes put: self currentMemoryUsage - memory;
				at: #totalMs put: (Time microsecondClockValue - start) / 1000.0.
			self logMemory: (record at: #memoryBytes) forPrefix: size.
			self logTime: (record at: #totalMs) forPrefix: size
		] on: Error do: [ :error |
			record removeKey: #rank ifAbsent: [ ].
			record at: #error put: error messageText.
			error pass ] ]
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> exportTrainingTo: path [
	| file |
	file := path asFileReference.
	file writeStreamDo: [ :out |
		out truncate.
		self exportTrainingOn: out ].
	^ file
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> unionOf: candidates with: lmCandidate [
	| union candidate |
	union := candidates collect: [ :each | CooRankingCandidate new data: each asDictionary; yourself ].
	union := union asOrderedCollection.
	lmCandidate ifEmpty: [ ^ union asArray ].
	candidate := union detect: [ :each | each name = lmCandidate ] ifNone: [
		| added |
		added := CooRankingCandidate name: lmCandidate rank: 0 source: 'llm'.
		union add: added. added ].
	candidate markLMAgreement.
	^ union asArray
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> exportFusionTrainingTo: path [
	| file |
	file := path asFileReference.
	file writeStreamDo: [ :out |
		out truncate.
		records do: [ :record |
			((record includesKey: #rank) and: [ record includesKey: #unionCandidates ]) ifTrue: [
				| row |
				row := Dictionary new.
				#('schema' 'kind' 'prefix' 'sourcePrefix' 'receiverKind' 'group' 'target' 'candidateLimit')
					do: [ :key | row at: key put: (record at: key) ].
				row at: 'candidates' put: (record at: #unionCandidates).
				out nextPutAll: (STONJSON toString: row); lf ] ] ].
	^ file
]

{ #category : 'diagnostics' }
CooNeuralRerankBenchmarks >> diagnosticSummary [
	"The LM-first baseline's diagnostic flags do not apply to a reranker."
	^ Dictionary newFrom: {
		#count -> (records count: [ :row | row includesKey: #rank ]).
		#errors -> (records count: [ :row | row includesKey: #error ]).
		#fallbackCalls -> (records count: [ :row | row at: #fallbackCalled ifAbsent: [ false ] ]) }
]

{ #category : 'ranking' }
CooNeuralRerankBenchmarks >> exportTrainingOn: out [
	records do: [ :record | (record includesKey: #rank) ifTrue: [
		| row |
		row := Dictionary new.
		#('schema' 'kind' 'prefix' 'sourcePrefix' 'receiverKind' 'candidates' 'group' 'target' 'candidateLimit')
			do: [ :key | row at: key put: (record at: key) ].
		out nextPutAll: (STONJSON toString: row); lf ] ]
]
