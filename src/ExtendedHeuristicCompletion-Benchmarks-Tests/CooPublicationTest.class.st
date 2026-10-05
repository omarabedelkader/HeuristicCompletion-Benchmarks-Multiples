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
	self assert: (CooBenchmarkChart performanceFormFor: comparison) extent equals: 1200 @ 1150
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
	"Two full PNG encodes can exceed the default SUnit limit on a busy image."
	self timeLimit: 1 minute.
	comparison := self comparison.
	requests := transport requests size.
	points := CooBenchmarkChart performancePointsFor: comparison.
	self assert: points size equals: 20.
	folder := FileLocator temp / ('coo-publication-' , UUID new asString).
	[
		2 timesRepeat: [
			files := CooBenchRunner export: comparison to: folder.
			self assert: (files collect: #basename) asSet
				equals: #('results-table.tex' 'performance.png' 'dataset-summary.tex') asSet.
			self assert: folder children size equals: 3.
			self assert: transport requests size equals: requests ].
		latex := (folder / 'results-table.tex') contents.
		self assert: (latex lines select: [ :line | line beginsWith: '& ' ]) size equals: 20.
		self assert: (latex includesSubstring: '\multirow{10}{*}{\textbf{Methods}}').
		self assert: (latex includesSubstring: '\multirow{10}{*}{\textbf{Classes}}').
		self assert: (PNGReadWriter formFromFileNamed: (folder / 'performance.png') fullName) extent equals: 1200 @ 1150.
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
	self assert: (CooBenchmarkChart performanceFormFor: comparison) extent equals: 1200 @ 1150.
	range := CooBenchmarkChart memoryRangeFor: { Dictionary newFrom: { #memoryMB -> 0 } }.
	self assert: range first equals: 0.
	self assert: range second > range first
]

{ #category : 'tests' }
CooPublicationTest >> testRandomSelectionHasExactlyRequestedNumberOfDistinctPackages [
	| candidates selection |
	candidates := (1 to: 30) collect: [ :index | 'Package', index asString ].
	#(10 20 30) do: [ :count |
		selection := CooBenchRunner randomPackageNames: count
			from: candidates , candidates using: (Random seed: 42).
		self assert: selection size equals: count.
		self assert: selection asSet size equals: count.
		self assert: (selection allSatisfy: [ :name | candidates includes: name ]) ].
	self assert: selection asSet equals: candidates asSet
]

{ #category : 'tests' }
CooPublicationTest >> testSeededSelectionIsIndependentOfCandidateOrder [
	| candidates first second |
	candidates := (1 to: 30) collect: [ :index | 'Package', index asString ].
	first := CooBenchRunner randomPackageNames: 10 from: candidates using: (Random seed: 42).
	second := CooBenchRunner randomPackageNames: 10 from: candidates reversed using: (Random seed: 42).
	self assert: first equals: second
]

{ #category : 'tests' }
CooPublicationTest >> testInvalidPackageCountsFailBeforeInference [
	#(0 -1 1.5 '10' nil 2) do: [ :count |
		self should: [ CooBenchRunnerRandomTestStub randomPackages: count ] raise: Error ].
	self assert: transport requests isEmpty
]

{ #category : 'tests' }
CooPublicationTest >> testRandomComparisonUsesAndRetainsOneSelectionForBothKinds [
	| comparison |
	comparison := CooBenchRunnerRandomTestStub randomPackages: 1 seed: 42.
	self assert: (comparison at: #packageNames) equals: #('CooPublication-Fixture').
	self assert: (comparison at: #selectionSeed) equals: 42.
	self assert: ((comparison at: #corpus) at: #packages) equals: 1.
	#(messages variables) do: [ :kind |
		self assert: ((comparison at: kind) first collect: [ :run | run package name ])
			equals: (comparison at: #packageNames).
		self assert: (comparison at: kind) first first results keys asSet
			equals: CooBenchmarkChart publicationStrategies asSet ].
	comparison := CooBenchRunnerRandomTestStub randomPackages: 1.
	self assert: (comparison at: #packageNames) equals: #('CooPublication-Fixture')
]

{ #category : 'tests' }
CooPublicationTest >> testEligiblePackagesExcludePackagesWithoutBenchmarkMethods [
	| emptyClass eligible |
	emptyClass := (Object << #CooEmptyPublicationFixture)
		package: 'CooPublication-EmptyFixture'; install.
	[
		eligible := CooBenchRunner eligiblePackageNames.
		self assert: (eligible includes: fixture package name).
		self deny: (eligible includes: emptyClass package name)
	] ensure: [
		emptyClass removeFromSystem.
		PackageOrganizer default removePackage: 'CooPublication-EmptyFixture' ]
]

{ #category : 'tests' }
CooPublicationTest >> testHybridsMatchPureLMRequestsAndAllStrategyPopulations [
	| comparison |
	comparison := self comparison.
	#(messages variables) do: [ :kind |
		| run dependency |
		run := (comparison at: kind) first first.
		dependency := run results at: #heuristicsDependency.
		#(hybrid05B hybrid15B hybrid3B hybrid7B) with: #(llm05B llm15B llm3B llm7B) do: [ :hybridKey :lmKey |
			| hybrid lm |
			hybrid := run results at: hybridKey.
			lm := run results at: lmKey.
			self assert: hybrid records size equals: lm records size.
			hybrid records with: lm records do: [ :h :l |
				self assert: (h at: #snapshot) equals: (l at: #snapshot).
				self assert: ((h at: #generation) at: #request) equals: ((l at: #generation) at: #request) ].
			2 to: 8 do: [ :prefix |
				self assert: (hybrid totalEntriesPerPrefixSize: prefix) equals: (dependency totalEntriesPerPrefixSize: prefix).
				self assert: (hybrid totalEntriesPerPrefixSize: prefix) equals: (lm totalEntriesPerPrefixSize: prefix).
				"Reusing dependency builders preserves the actual heuristic ranking too."
				self assert: ((hybrid records select: [ :record | (record at: #prefix) size = prefix ])
					count: [ :record | (record at: #heuristicRank) > 0 ])
					equals: ((dependency accuracyForCompletionIndex: (1 to: 10) withPrefixSize: prefix)
						* (dependency totalEntriesPerPrefixSize: prefix)) ] ] ]
]

{ #category : 'tests' }
CooPublicationTest >> testFailedHybridRetainsPartialDiagnostics [
	| runner |
	transport responseBlock: [ :payload | self error: 'Unavailable model' ].
	runner := CooBenchRunnerMessage new package: fixture package;
		baseline: #heuristicsBaseline; others: #(hybrid3B); yourself.
	self should: [ runner run ] raise: Error.
	self assert: (runner results includesKey: #heuristicsBaseline).
	self assert: ((runner results at: #hybrid3B) records first at: #error) equals: 'Unavailable model'.
	self assert: ((runner results at: #hybrid3B) totalEntriesPerPrefixSize: 2) equals: 0
]

{ #category : 'tests' }
CooPublicationTest >> testTopKAccuracyWeightsObservationsAndPreservesMissingData [
	| first second runs |
	first := CooStaticBenchmarksMessage new.
	first trackCompletionResultsFor: 'size' atIndex: 1 withPrefix: 'si'.
	second := CooStaticBenchmarksMessage new.
	#(3 10 0) do: [ :rank | second trackCompletionResultsFor: 'size' atIndex: rank withPrefix: 'siz' ].
	runs := { first. second } collect: [ :bench |
		CooBenchRunnerTestBenchStub new results: (Dictionary newFrom: { #sample -> bench }); yourself ].
	self assert: (CooBenchmarkChart accuracyAt: 1 for: #sample runs: runs) equals: 0.25.
	self assert: (CooBenchmarkChart accuracyAt: 3 for: #sample runs: runs) equals: 0.5.
	self assert: (CooBenchmarkChart accuracyAt: 10 for: #sample runs: runs) equals: 0.75.
	self assert: (CooBenchmarkChart accuracyAt: 10 for: #missing runs: runs) isNil
]
