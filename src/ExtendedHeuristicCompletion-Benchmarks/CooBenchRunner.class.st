"
a simple interface for managing the running of the benchs, look to my subclasses to know more
"
Class {
	#name : 'CooBenchRunner',
	#superclass : 'Object',
	#instVars : [
		'package',
		'baseline',
		'others',
		'results',
		'activeStrategy'
	],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Benchmarks',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Benchmarks'
}

{ #category : 'benchmarks' }
CooBenchRunner class >> allResultsFor: aColOfPackageNames [

	| packages runs string latex |
	packages := aColOfPackageNames collect: [ :p |
		            PackageOrganizer default packageNamed: p ].
	runs := self runComparisonForPackages: packages.
	string := self stringResultForABenchCollection: runs.
	latex := self latexTableResultForABenchCollection: runs.
	^ {
		  runs.
		  string.
		  latex }
]

{ #category : 'examples' }
CooBenchRunner class >> necTests [
	"Both completion kinds, each containing two heuristics and four one-token LLMs.
	Keep the answer to inspect or export without running the model again."
	^ self compareMessagesAndVariablesFor: { 'NECompletion-Tests' }
]

{ #category : 'benchmarks' }
CooBenchRunner class >> compareMessagesAndVariablesFor: packageNames [
	| selectedNames |
	selectedNames := packageNames asArray copy.
	^ Dictionary new
		at: #packageNames put: selectedNames;
		at: #corpus put: (self corpusSummaryForPackageNames: selectedNames);
		at: #messages put: (CooBenchRunnerMessage allResultsFor: selectedNames);
		at: #variables put: (CooBenchRunnerVariables allResultsFor: selectedNames);
		yourself
]

{ #category : 'benchmarks' }
CooBenchRunner class >> randomPackages: count [
	"Choose once, without replacement, for both kinds and all strategies."
	^ self compareMessagesAndVariablesFor: (self
		randomPackageNames: count
		from: self eligiblePackageNames
		using: Random new)
]

{ #category : 'benchmarks' }
CooBenchRunner class >> randomPackagesForReranker: count [
	"Run only the pure neural rerankers on the same packages for both kinds."
	| packageNames |
	packageNames := self
		randomPackageNames: count
		from: self eligiblePackageNames
		using: Random new.
	^ self
		compareMessagesAndVariablesFor: packageNames
		strategies: CooBenchmarkChart rerankerStrategies
]

{ #category : 'benchmarks' }
CooBenchRunner class >> randomPackages: count seed: seed [
	"Repeat the selection with the same seed and eligible package names."
	| comparison |
	comparison := self compareMessagesAndVariablesFor: (self
		randomPackageNames: count
		from: self eligiblePackageNames
		using: (Random seed: seed)).
	comparison at: #selectionSeed put: seed.
	^ comparison
]

{ #category : 'benchmarks' }
CooBenchRunner class >> eligiblePackageNames [
	"All loaded packages with methods in the actual benchmark traversal."
	^ ((PackageOrganizer default packages select: [ :each |
		self hasBenchmarkMethods: each ]) collect: #name) asSortedCollection asArray
]

{ #category : 'private' }
CooBenchRunner class >> hasBenchmarkMethods: aPackage [
	(CoBenchmarkPackage on: aPackage) methodsDo: [ :method | ^ true ].
	^ false
]

{ #category : 'benchmarks' }
CooBenchRunner class >> randomPackageNames: count from: packageNames using: random [
	"Sorting makes seeded sampling independent of organizer enumeration order."
	| remaining selected |
	(count isInteger and: [ count > 0 ]) ifFalse: [
		self error: 'Package count must be a positive integer' ].
	remaining := packageNames asSet asSortedCollection asOrderedCollection.
	count > remaining size ifTrue: [
		self error: 'Requested ', count asString, ' packages, but only ',
			remaining size asString, ' eligible packages are available' ].
	selected := OrderedCollection new: count.
	count timesRepeat: [
		selected add: (remaining removeAt: (random nextInteger: remaining size)) ].
	^ selected asArray
]

{ #category : 'exporting' }
CooBenchRunner class >> export: comparison to: directory [
	"Export previously computed results; no new inference requests."
	^ CooBenchmarkChart export: comparison to: directory
]

{ #category : 'exporting' }
CooBenchRunner class >> exportReranker: comparison to: directory [
	"Export the retained reranker table without running inference again."
	| folder tableFile |
	folder := directory asFileReference.
	folder ensureCreateDirectory.
	tableFile := folder / 'results-table-re-ranker.tex'.
	tableFile writeStreamDo: [ :stream |
		stream
			truncate;
			nextPutAll: (self latexResultsTableFor: comparison) ].
	^ tableFile
]

{ #category : 'benchmarks' }
CooBenchRunner class >> latexTableResultForABenchCollection: aCol [
	"Produce a LaTeX table showing the results from each benchmark in aCol."

	| header body mmrKeys footer rows |
	mmrKeys := OrderedCollection new.
	rows := OrderedCollection new.

	"First pass: collect all keys for MMR columns"
	aCol do: [ :bench |
			bench results do: [ :result |
					| mmrs |
					mmrs := result mmrString splitOn: Character cr.
					mmrs := mmrs copyFrom: 2 to: mmrs size.
					mmrKeys := mmrs collect: [ :r |
						           (r splitOn: Character space) first ] ] ].

	"Second pass: build rows"
	body := String streamContents: [ :s |
			        aCol do: [ :bench |
					        | packageName |
					        packageName := bench package name.

					        bench results keysAndValuesDo: [ :metric :result |
							        | mmrs mmrValues globalMmr |
							        mmrs := result mmrString splitOn: Character cr.
							        mmrValues := mmrs copyFrom: 2 to: mmrs size.
							        mmrValues := mmrValues collect: [ :r |
								                     (r splitOn: Character space) second ].
							        globalMmr := (mmrs first splitOn: Character space)
								                     second.

							        s
								        nextPutAll: packageName;
								        nextPutAll: ' & '.
							        s
								        nextPutAll: metric asString;
								        nextPutAll: ' & '.
							        s
								        nextPutAll: globalMmr asString;
								        nextPutAll: ' & '.
							        s nextPutAll: (mmrValues joinUsing: ' & ').
							        s nextPutAll: ' \\'.
							        s cr ] ] ].
	"Build header"
	header := String streamContents: [ :s |
			          s nextPutAll: '\begin{tabular}{lll'.
			          mmrKeys do: [ :k | s nextPutAll: 'l' ].
			          s
				          nextPutAll: '}';
				          cr.
			          s
				          nextPutAll: '\hline';
				          cr.
			          s nextPutAll: 'Package & Metric & MMR'.
			          mmrKeys do: [ :k | s nextPutAll: ' & ' , k ].
			          s
				          nextPutAll: ' \\';
				          cr.
			          s
				          nextPutAll: '\hline';
				          cr ].

	"Footer"
	footer := String streamContents: [ :s |
			          s
				          nextPutAll: '\hline';
				          cr.
			          s
				          nextPutAll: '\end{tabular}';
				          cr ].

	^ header , body , footer
]

{ #category : 'benchmarks' }
CooBenchRunner class >> runComparisonForPackages: aCol [

	^ self subclassResponsibility
]

{ #category : 'benchmarks' }
CooBenchRunner class >> stringResultForABenchCollection: aCol [

	^ String streamContents: [ :s |
			  aCol do: [ :p |
					  s << p package name.
					  s cr.
					  p results keysAndValuesDo: [ :k :v |
							  s << k asString.
							  s cr.
							  s << v mmrString.
							  s cr ].
					  s cr ] ]
]

{ #category : 'baselines' }
CooBenchRunner >> baseline: aSymbol [

	baseline := aSymbol
]

{ #category : 'accessing' }
CooBenchRunner >> computeDelta [

	| baselineAcc otherAcc delta |
	baselineAcc := (results at: baseline) mmr.
	otherAcc := (results at: others first) mmr.
	delta := otherAcc - baselineAcc.

	^ delta
]

{ #category : 'accessing' }
CooBenchRunner >> computeRatio [

	^ (results at: baseline) accuracyResults
		  computeRatioWithReceiverAsBaselineComparedTo:
		  (results at: others first) accuracyResults
]

{ #category : 'accessing' }
CooBenchRunner >> others: aSymbolCollect [

	others := aSymbolCollect
]

{ #category : 'accessing' }
CooBenchRunner >> package [

	^ package
]

{ #category : 'accessing' }
CooBenchRunner >> package: aPackage [

	package := aPackage
]

{ #category : 'accessing' }
CooBenchRunner >> results [

	^ results
]

{ #category : 'LLM' }
CooBenchRunner >> llmCompletionFor: kind [
	^ self llmCompletionFor: kind model: CooLLMClient default model
]

{ #category : 'LLM' }
CooBenchRunner >> llmCompletionFor: kind model: modelName [
	| benchmark client |
	client := CooLLMClient default copy model: modelName; yourself.
	benchmark := CooLLMBenchmarks new
		client: client;
		kind: kind;
		scope: (CoBenchmarkPackage on: package);
		yourself.
	"Keep partial diagnostics under the strategy that actually failed."
	activeStrategy ifNotNil: [ results at: activeStrategy put: benchmark ].
	^ benchmark run; yourself
]

{ #category : 'accessing' }
CooBenchRunner >> run [
	results := Dictionary new.
	[ { baseline } , others do: [ :strategy |
		activeStrategy := strategy.
		results at: strategy put: (self perform: strategy) ] ]
		ensure: [ activeStrategy := nil ]
]

{ #category : 'LLM configuration' }
CooBenchRunner class >> llmModels [
	^ OrderedDictionary new
		at: #llm05B put: 'pharo-llm/Qwen2.5-Coder-SFT:0.5B';
		at: #llm15B put: 'pharo-llm/Qwen2.5-Coder-SFT:1.5B';
		at: #llm3B put: 'pharo-llm/Qwen2.5-Coder-SFT:3b';
		at: #llm7B put: 'pharo-llm/Qwen2.5-Coder-SFT:7b';
		yourself
]

{ #category : 'benchmarks' }
CooBenchRunner class >> corpusSummaryForPackageNames: packageNames [
	"Count the same corpus traversed by CoBenchmarkPackage, once per entity.
	Do not include trait or extension methods that the benchmark never visits."
	| packages classes methods |
	packages := (packageNames collect: [ :name |
		PackageOrganizer default packageNamed: name ]) asSet.
	classes := Set new.
	methods := Set new.
	packages do: [ :each |
		classes addAll: (each definedClasses reject: #isTrait).
		(CoBenchmarkPackage on: each) methodsDo: [ :method | methods add: method ] ].
	^ Dictionary new
		at: #packages put: packages size;
		at: #classes put: classes size;
		at: #methods put: methods size;
		yourself
]

{ #category : 'exporting' }
CooBenchRunner class >> latexResultsTableFor: comparison [
	^ CooBenchmarkChart latexResultsTableFor: comparison
]

{ #category : 'exporting' }
CooBenchRunner class >> latexCorpusSummaryFor: corpus [
	^ CooBenchmarkChart latexCorpusSummaryFor: corpus
]

{ #category : 'Hybrid' }
CooBenchRunner >> hybridCompletionFor: kind model: modelName builder: aBuilder [
	| benchmark client |
	client := CooLLMClient default copy model: modelName; yourself.
	benchmark := CooHybridBenchmarks new
		client: client; kind: kind;
		scope: (CoBenchmarkPackage on: package);
		builder: aBuilder; yourself.
	activeStrategy ifNotNil: [ results at: activeStrategy put: benchmark ].
	^ benchmark run; yourself
]

{ #category : 'ranking' }
CooBenchRunner >> rankingCompletionFor: kind limit: k benchmarkClass: benchmarkClass [

	| benchmark |
	benchmark := benchmarkClass new
		kind: kind; candidateLimit: k;
		scope: (CoBenchmarkPackage on: package);
		builder: self dependencyBuilder; yourself.
	activeStrategy ifNotNil: [ results at: activeStrategy put: benchmark ].
	^ benchmark run; yourself
]

{ #category : 'benchmarks' }
CooBenchRunner class >> compareMessagesAndVariablesFor: packageNames strategies: strategies [
	"Opt-in comparison on identical packages, with the requested publication rows."
	| selectedNames ordered comparison packages |
	ordered := CooBenchmarkChart validatePublicationStrategies: strategies.
	selectedNames := packageNames asArray copy.
	packages := selectedNames collect: [ :packageName | PackageOrganizer default packageNamed: packageName ].
	comparison := Dictionary new
		at: #packageNames put: selectedNames;
		at: #publicationStrategies put: ordered;
		at: #corpus put: (self corpusSummaryForPackageNames: selectedNames); yourself.
	{ #messages -> CooBenchRunnerMessage. #variables -> CooBenchRunnerVariables } do: [ :entry |
		| runs |
		runs := packages collect: [ :package |
			entry value new package: package; baseline: ordered first;
				others: ordered allButFirst; run; yourself ].
		comparison at: entry key put: {
			runs. self stringResultForABenchCollection: runs.
			self latexTableResultForABenchCollection: runs } ].
	^ comparison
]
