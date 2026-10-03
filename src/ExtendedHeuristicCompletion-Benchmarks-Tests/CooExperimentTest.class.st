Class {
	#name : 'CooExperimentTest',
	#superclass : 'CooLLMBenchmarksTest',
	#instVars : [  ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#tag : 'LLM'
}

{ #category : 'helpers' }
CooExperimentTest >> hints [
	^ #('size' 'sizeHint' 'sizeOther') withIndexCollect: [ :candidate :index |
		Dictionary newFrom: { #candidate -> candidate.
			#ranks -> { Dictionary newFrom: { #source -> 'Dependency'. #rank -> index } } } ]
]

{ #category : 'tests' }
CooExperimentTest >> testRerankingIsCandidateConstrainedAndBlendsRanks [
	| benchmark snapshot generation record candidates |
	benchmark := CooRerankingHybridBenchmarks new weights: #(1 0 0); yourself.
	snapshot := self snapshot at: #heuristicCandidates put: self hints; yourself.
	generation := Dictionary newFrom: { #content -> '[3,2,1]' }.
	record := Dictionary new.
	candidates := benchmark candidatesFrom: generation snapshot: snapshot record: record.
	self assert: candidates equals: #('sizeOther' 'sizeHint' 'size').
	benchmark weights: #(0 1 0).
	candidates := benchmark candidatesFrom: generation snapshot: snapshot record: record.
	self assert: candidates equals: #('size' 'sizeHint' 'sizeOther').
	self assert: (record at: #scores) size equals: 3
]

{ #category : 'tests' }
CooExperimentTest >> testRerankerRejectsDuplicatesMissingUnknownAndNonIntegerIDs [
	| benchmark |
	benchmark := CooRerankingHybridBenchmarks new.
	#('[1,1,2]' '[1,2]' '[1,2,4]' '[1,2,3,4]' '[1,2,3.0]' '["1",2,3]' '{}' 'null' 'nonsense') do: [ :content |
		self should: [ benchmark validatedOrderFrom: (Dictionary newFrom: { #content -> content }) size: 3 ] raise: Error ]
]

{ #category : 'tests' }
CooExperimentTest >> testRerankingPayloadIncludesSchemaWithoutExpectedAnswer [
	| snapshot generation request |
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> '[3,2,1]'. 'done' -> true. 'eval_count' -> 8 } ].
	snapshot := self snapshot at: #heuristicCandidates put: self hints; at: #expected put: 'heldOutSentinel'; yourself.
	generation := client rerankFor: snapshot.
	request := generation at: #request.
	self assert: ((request at: 'format' at: 'items') at: 'enum') equals: #(1 2 3).
	self assert: (request at: 'options' at: 'num_predict') equals: 256.
	self deny: ((request at: 'prompt') includesSubstring: 'heldOutSentinel').
	self deny: ((request at: 'prompt') includesSubstring: '"ranks"')
]

{ #category : 'tests' }
CooExperimentTest >> testEmptyRerankingSkipsInference [
	| snapshot generation |
	snapshot := self snapshot at: #heuristicCandidates put: #(); yourself.
	generation := client rerankFor: snapshot.
	self assert: (generation at: #skipped).
	self assert: transport requests isEmpty.
	self assert: (CooRerankingHybridBenchmarks new candidatesFrom: generation
		snapshot: snapshot record: Dictionary new) isEmpty
]

{ #category : 'tests' }
CooExperimentTest >> testCompleteNameCanUseMultipleTokensAndStopsAtDelimiter [
	| benchmark |
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> 'ze. nextMessage'. 'done' -> true. 'eval_count' -> 6 } ].
	benchmark := CooLLMBenchmarks new client: client; completionLevel; yourself.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	self assert: (benchmark mmrForPrefixSize: 2) equals: 1.
	self assert: (transport requests first at: 'options' at: 'num_predict') equals: 64.
	self assert: (benchmark nameContinuationIn: 'put: moreCode') equals: 'put:'.
	self assert: (benchmark nameContinuationIn: ' space') equals: ''.
	benchmark kind: #variables.
	self assert: (benchmark nameContinuationIn: 'Collection: moreCode') equals: 'Collection'
]

{ #category : 'tests' }
CooExperimentTest >> testTimingsAreConvertedAndMissingFieldsRemainNil [
	| benchmark record |
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> 'ze'. 'done' -> true. 'eval_count' -> 1.
		'total_duration' -> 45000000. 'load_duration' -> 2000000.
		'prompt_eval_duration' -> 30000000. 'eval_duration' -> 10000000.
		'prompt_eval_count' -> 42 } ].
	benchmark := CooLLMBenchmarks new client: client; yourself.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	record := benchmark records first.
	self assert: (record at: #ollamaTotalMs) equals: 45.0.
	self assert: (record at: #generationMs) equals: 10.0.
	self assert: (record at: #promptTokens) equals: 42.
	self assert: (record at: #wallTimeMs) >= 0.
	self assert: (record at: #wallTimeMs) equals: (benchmark timeSamplesForPrefix: 2) first.
	benchmark addTimingsFrom: (Dictionary newFrom: { #response -> Dictionary new }) to: record.
	self assert: (record at: #generationMs) isNil
]

{ #category : 'tests' }
CooExperimentTest >> testWarmPreparationOccursOnceAndColdBeforeEachRequest [
	| benchmark |
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> ''. 'done' -> true. 'eval_count' -> 0 } ].
	benchmark := CooLLMBenchmarks new client: client; latencyCondition: #warm; yourself.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	self assert: transport requests size equals: 4.
	self assert: (transport requests first at: 'prompt') equals: ''.
	self assert: (benchmark records first at: #preparation) notNil.
	self assert: (benchmark records second at: #preparation) isNil.
	transport requests removeAll.
	benchmark := CooLLMBenchmarks new client: client; latencyCondition: #cold; yourself.
	benchmark benchCallsite: (self messageIn: 'example ^ self size') atPosition: 0.
	self assert: transport requests size equals: 6.
	#(1 3 5) do: [ :index | self assert: ((transport requests at: index) at: 'keep_alive') equals: 0 ]
]

{ #category : 'tests' }
CooExperimentTest >> testLatencyQuantilesUseIndividualSamples [
	| benchmark |
	benchmark := CooStaticBenchmarksMessage new.
	self assert: (benchmark medianTimeForPrefix: 2) isNil.
	#(1 2 3 100) do: [ :ms | benchmark logTime: ms forPrefix: 2 ].
	self assert: (benchmark medianTimeForPrefix: 2) equals: 2.5.
	self assert: (benchmark p95TimeForPrefix: 2) equals: 100.
	self assert: (benchmark averageTimeForPrefix: 2) equals: 26.5
]

{ #category : 'tests' }
CooExperimentTest >> testStaticObservationsAndExpandedCSV [
	| benchmark node run csv row |
	benchmark := CooStaticBenchmarksMessage new.
	node := (CooLLMBenchmarksTest >> #fixture) parseTree allChildren detect: #isMessage.
	benchmark benchCallsite: node atPosition: node keywordsIntervals first.
	self assert: benchmark observations size equals: 7.
	self assert: (benchmark observations first at: #model) equals: 'none'.
	run := CooBenchRunnerTestBenchStub new
		package: (CooBenchRunnerTestPackageStub new name: 'Example,quoted'; yourself);
		results: (Dictionary newFrom: { #heuristicsBaseline -> benchmark }); yourself.
	csv := CooBenchmarkChart csvFor: { run }.
	self assert: (csv beginsWith: 'package,strategy,model,prefix,count,mrr,total_ms,avg_ms').
	self assert: (csv includesSubstring: 'median_ms,p95_ms,recall_1,recall_3,recall_5,recall_10').
	self assert: (csv includesSubstring: '"Example,quoted"').
	row := benchmark observations first.
	self assert: (row at: #wallTimeMs) equals: (benchmark timeSamplesForPrefix: 2) first
]

{ #category : 'tests' }
CooExperimentTest >> testMatrixReusesStaticResultsAndPreservesDefaultClient [
	| original matrix first second |
	original := CooLLMClient default.
	PackageOrganizer default ensurePackage: 'ExtendedHeuristicCompletion-Benchmarks-Empty-Test'.
	[ matrix := CooBenchRunner compareModels: #('test-model-a' 'test-model-b')
		messagesAndVariablesFor: #('ExtendedHeuristicCompletion-Benchmarks-Empty-Test')
		strategies: #() latencyCondition: #warm.
	first := ((matrix at: 'test-model-a') at: #messages) first first.
	second := ((matrix at: 'test-model-b') at: #messages) first first.
	self assert: (first results at: #heuristicsBaseline) identicalTo: (second results at: #heuristicsBaseline).
	self assert: (first results at: #heuristicsDependency) identicalTo: (second results at: #heuristicsDependency).
	self assert: CooLLMClient default identicalTo: original
	] ensure: [ PackageOrganizer default removePackage: (PackageOrganizer default packageNamed: 'ExtendedHeuristicCompletion-Benchmarks-Empty-Test') ]
]

{ #category : 'tests' }
CooExperimentTest >> testRerankingTruncatesAtTenAndSerializesSharedRankMetadata [
	| benchmark hints snapshot generation record candidates |
	benchmark := CooRerankingHybridBenchmarks new weights: #(1 0 0); yourself.
	hints := (1 to: 12) collect: [ :id | Dictionary newFrom: {
		#candidate -> ('candidate' , id asString).
		#ranks -> { Dictionary newFrom: { #source -> 'Custom'. #rank -> id } } } ].
	snapshot := self snapshot at: #heuristicCandidates put: hints; yourself.
	generation := Dictionary newFrom: { #content -> '[12,11,10,9,8,7,6,5,4,3,2,1]' }.
	record := Dictionary newFrom: { #snapshot -> snapshot }.
	candidates := benchmark candidatesFrom: generation snapshot: snapshot record: record.
	self assert: candidates size equals: 10.
	self assert: candidates first equals: 'candidate12'.
	self deny: (candidates includes: 'candidate1').
	self assert: (STONJSON fromString: (STONJSON toString: record)) size equals: 4
]

{ #category : 'tests' }
CooExperimentTest >> testInvalidRerankingIsAuditedAndNotScoredAsMiss [
	| benchmark node |
	transport responseBlock: [ :payload | Dictionary newFrom: {
		'response' -> '[999]'. 'done' -> true. 'eval_count' -> 3 } ].
	benchmark := CooRerankingHybridBenchmarks new client: client; yourself.
	node := (CooLLMBenchmarksTest >> #fixture) parseTree allChildren detect: #isMessage.
	self should: [ benchmark benchCallsite: node atPosition: 0 ] raise: Error.
	self assert: (benchmark records first includesKey: #error).
	self assert: (benchmark records first at: #generation at: #content) equals: '[999]'.
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 0.
	self assert: (benchmark timeSamplesForPrefix: 2) isEmpty.
	self assert: node selector equals: #yourself
]

{ #category : 'tests' }
CooExperimentTest >> testBlendedTiesKeepOriginalUnionOrder [
	| benchmark snapshot generation hints candidates |
	benchmark := CooRerankingHybridBenchmarks new weights: #(1 1 0); yourself.
	hints := self hints first: 2.
	snapshot := self snapshot at: #heuristicCandidates put: hints; yourself.
	generation := Dictionary newFrom: { #content -> '[2,1]' }.
	candidates := benchmark candidatesFrom: generation snapshot: snapshot record: Dictionary new.
	self assert: candidates equals: #('size' 'sizeHint')
]
