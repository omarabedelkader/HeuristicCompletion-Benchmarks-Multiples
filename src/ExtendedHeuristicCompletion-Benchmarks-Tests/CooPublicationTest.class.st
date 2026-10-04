Class {
	#name : 'CooPublicationTest',
	#superclass : 'TestCase',
	#instVars : [ 'fixture', 'transport', 'previousClient' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'running' }
CooPublicationTest >> setUp [
	super setUp.
	previousClient := CooLLMClient default.
	transport := CooLLMTestTransport new.
	CooLLMClient default: (CooLLMClient new transport: transport; yourself).
	fixture := (Object << #CooPublicationFixture) package: 'CooPublication-Fixture'; install.
	fixture compile: 'example ^ OrderedCollection new. Smalltalk yourself'.
	fixture class compile: 'classExample ^ Set new'
]

{ #category : 'running' }
CooPublicationTest >> tearDown [
	CooLLMClient default: previousClient.
	fixture ifNotNil: [ fixture removeFromSystem ].
	PackageOrganizer default removePackage: 'CooPublication-Fixture'.
	super tearDown
]

{ #category : 'helpers' }
CooPublicationTest >> comparison [
	^ CooBenchRunner compareMessagesAndVariablesFor: #('CooPublication-Fixture')
]

{ #category : 'tests' }
CooPublicationTest >> testFourModelsUseSameOneTokenRequestsAndPopulations [
	| comparison defaultModel |
	defaultModel := CooLLMClient default model.
	comparison := self comparison.
	#(messages variables) do: [ :kind |
		| run reference |
		run := (comparison at: kind) first first.
		self assert: run results keys asSet equals: CooBenchmarkChart publicationStrategies asSet.
		reference := (run results at: #llm05B) records collect: [ :record |
			(record at: #generation) at: #request ].
		CooBenchRunner llmModels keysAndValuesDo: [ :strategy :model |
			| benchmark |
			benchmark := run results at: strategy.
			benchmark records withIndexDo: [ :record :index |
				| request |
				request := (record at: #generation) at: #request.
				self assert: (request at: 'model') equals: model.
				self assert: ((request at: 'options') at: 'num_predict') equals: 1.
				self assert: (request at: 'prompt') equals: ((reference at: index) at: 'prompt') ].
			2 to: 8 do: [ :prefix |
				#(heuristicsBaseline heuristicsDependency) do: [ :heuristic |
					self assert: (benchmark totalEntriesPerPrefixSize: prefix)
						equals: ((run results at: heuristic) totalEntriesPerPrefixSize: prefix) ] ] ] ].
	self assert: CooLLMClient default model equals: defaultModel
]

{ #category : 'tests' }
CooPublicationTest >> testClassesExcludeNonClassGlobals [
	| run benchmark |
	run := (CooBenchRunnerVariables runComparisonForPackages: { fixture package }) first.
	benchmark := run results at: #llm05B.
	self assert: benchmark records isNotEmpty.
	self assert: (benchmark records allSatisfy: [ :record | (record at: #expected) = 'OrderedCollection' ]).
	self assert: (benchmark totalEntriesPerPrefixSize: 2) equals: 1
]

{ #category : 'tests' }
CooPublicationTest >> testAverageMemoryAndLatencyWeightObservationsAcrossPackagesAndPrefixes [
	| first second runs point |
	first := CooStaticBenchmarksMessage new.
	first trackCompletionResultsFor: 'size' atIndex: 1 withPrefix: 'si'; logTime: 10 forPrefix: 2; logMemory: 1000000 forPrefix: 2.
	3 timesRepeat: [ first trackCompletionResultsFor: 'size' atIndex: 0 withPrefix: 'siz'; logTime: 30 forPrefix: 3; logMemory: 3000000 forPrefix: 3 ].
	second := CooStaticBenchmarksMessage new.
	second trackCompletionResultsFor: 'size' atIndex: 1 withPrefix: 'si'; logTime: 20 forPrefix: 2; logMemory: 2000000 forPrefix: 2.
	runs := { first. second } collect: [ :benchmark |
		CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #sample -> benchmark }); yourself ].
	self assert: (CooBenchmarkChart averageMrrFor: #sample runs: runs) equals: 0.4.
	self assert: (CooBenchmarkChart valueFor: #sample prefix: 2 runs: runs) equals: 1.
	self assert: (CooBenchmarkChart valueFor: #sample prefix: 3 runs: runs) equals: 0.
	point := CooBenchmarkChart performancePointFor: #sample runs: runs.
	self assert: (point at: #performance) equals: 0.4.
	self assert: (point at: #latencyMs) equals: 24.
	self assert: (point at: #memoryMB) equals: 2.4.
	self assert: (point at: #count) equals: 5
]

{ #category : 'tests' }
CooPublicationTest >> testMissingObservationsAreNotZeroMeasurements [
	| comparison point |
	comparison := Dictionary newFrom: { #messages -> { #() }. #variables -> { #() } }.
	point := CooBenchmarkChart performancePointFor: #llm3B runs: #().
	self assert: (point at: #count) equals: 0.
	self assert: (point at: #performance) isNil.
	self assert: (point at: #latencyMs) isNil.
	self assert: (point at: #memoryMB) isNil.
	self assert: (CooBenchmarkChart averageMrrFor: #llm3B runs: #()) isNil.
	self assert: (CooBenchmarkChart performancePointsFor: comparison) isEmpty.
	self assert: ((CooBenchRunner latexResultsTableFor: comparison) includesSubstring: '& -- & --').
	self assert: (CooBenchmarkChart performanceFormFor: comparison) extent equals: 1200 @ 1000
]

{ #category : 'tests' }
CooPublicationTest >> testCorpusCountsUniqueEntitiesInActualBenchmarkScope [
	| corpus methods |
	methods := Set new.
	(CoBenchmarkPackage on: fixture package) methodsDo: [ :method | methods add: method ].
	corpus := CooBenchRunner corpusSummaryForPackageNames: #('CooPublication-Fixture' 'CooPublication-Fixture').
	self assert: (corpus at: #packages) equals: 1.
	self assert: (corpus at: #classes) equals: 1.
	self assert: (corpus at: #methods) equals: methods size
]

{ #category : 'tests' }
CooPublicationTest >> testExportWritesExactlyThreeArtifactsWithoutInference [
	| comparison folder requests files latex points |
	comparison := self comparison.
	requests := transport requests size.
	points := CooBenchmarkChart performancePointsFor: comparison.
	self assert: points size equals: 12.
	folder := FileLocator temp / ('coo-publication-' , UUID new asString).
	[
		2 timesRepeat: [
			files := CooBenchRunner export: comparison to: folder.
			self assert: (files collect: #basename) asSet
				equals: #('results-table.tex' 'performance.png' 'dataset-summary.tex') asSet.
			self assert: folder children size equals: 3.
			self assert: transport requests size equals: requests ].
		latex := (folder / 'results-table.tex') contents.
		self assert: (latex lines select: [ :line | line beginsWith: '& ' ]) size equals: 12.
		self assert: (latex includesSubstring: '\multirow{6}{*}{\textbf{Methods}}').
		self assert: (latex includesSubstring: '\multirow{6}{*}{\textbf{Classes}}').
		self assert: (PNGReadWriter formFromFileNamed: (folder / 'performance.png') fullName) extent equals: 1200 @ 1000.
		self assert: ((folder / 'dataset-summary.tex') contents includesSubstring: 'Packages & 1')
	] ensure: [ folder ensureDeleteAll ]
]

{ #category : 'tests' }
CooPublicationTest >> testFailedModelRetainsItsOwnPartialDiagnostics [
	| runner |
	transport responseBlock: [ :payload | self error: 'Unavailable model' ].
	runner := CooBenchRunnerMessage new package: fixture package;
		baseline: #heuristicsBaseline; others: #(llm3B); yourself.
	self should: [ runner run ] raise: Error.
	self assert: (runner results includesKey: #heuristicsBaseline).
	self assert: (runner results includesKey: #llm3B).
	self deny: (runner results includesKey: #llmCompletion).
	self assert: ((runner results at: #llm3B) records first at: #error) equals: 'Unavailable model'
]

{ #category : 'tests' }
CooPublicationTest >> testMemoryAxisIncludesNegativeDeltasAndValuesAboveOneMB [
	| range benchmark run comparison point |
	benchmark := CooStaticBenchmarksMessage new.
	benchmark trackCompletionResultsFor: 'size' atIndex: 1 withPrefix: 'si';
		logMemory: -2000000 forPrefix: 2; logTime: 5 forPrefix: 2.
	run := CooBenchRunnerTestBenchStub new
		results: (Dictionary newFrom: { #heuristicsBaseline -> benchmark }); yourself.
	point := CooBenchmarkChart performancePointFor: #heuristicsBaseline runs: { run }.
	self assert: (point at: #memoryMB) equals: -2.
	range := CooBenchmarkChart memoryRangeFor: { point. Dictionary newFrom: { #memoryMB -> 8 } }.
	self assert: range first < -2.
	self assert: range second > 8.
	comparison := Dictionary newFrom: { #messages -> { { run } }. #variables -> { #() } }.
	self assert: (CooBenchmarkChart performanceFormFor: comparison) extent equals: 1200 @ 1000.
	range := CooBenchmarkChart memoryRangeFor: { Dictionary newFrom: { #memoryMB -> 0 } }.
	self assert: range first equals: 0.
	self assert: range second > range first
]
