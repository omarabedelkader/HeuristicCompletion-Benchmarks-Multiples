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
		'llmClient',
		'latencyCondition'
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
	"Both completion kinds, each containing the original strategies and the LLM.
	Keep the answer to inspect or export without running the model again."
	^ self compareMessagesAndVariablesFor: { 'NECompletion-Tests' }
]

{ #category : 'benchmarks' }
CooBenchRunner class >> compareMessagesAndVariablesFor: packageNames [
	^ Dictionary new
		at: #messages put: (CooBenchRunnerMessage allResultsFor: packageNames);
		at: #variables put: (CooBenchRunnerVariables allResultsFor: packageNames);
		yourself
]

{ #category : 'exporting' }
CooBenchRunner class >> export: comparison to: directory [
	"Export previously computed results; no new inference requests."
	^ CooBenchmarkChart export: comparison to: directory
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
	^ self modelBenchmark: CooLLMBenchmarks kind: kind strategy: #llmCompletion configure: [ :bench | ]
]

{ #category : 'accessing' }
CooBenchRunner >> run [
	^ self runWithResults: Dictionary new
]

{ #category : 'LLM' }
CooBenchRunner >> hybridCompletionFor: kind [
	^ self modelBenchmark: CooHybridLLMBenchmarks kind: kind strategy: #hybridCompletion configure: [ :bench | ]
]

{ #category : 'accessing' }
CooBenchRunner >> client: aClient [
	llmClient := aClient
]

{ #category : 'accessing' }
CooBenchRunner >> latencyCondition: condition [
	latencyCondition := condition
]

{ #category : 'benchmarks' }
CooBenchRunner >> runWithResults: existingResults [
	results := existingResults copy.
	{ baseline } , others do: [ :strategy |
		results at: strategy ifAbsentPut: [ self perform: strategy ] ]
]

{ #category : 'LLM' }
CooBenchRunner >> modelBenchmark: benchmarkClass kind: kind strategy: strategy configure: block [
	| benchmark |
	benchmark := benchmarkClass new
		kind: kind;
		client: (llmClient ifNil: [ CooLLMClient default ] ) copy;
		latencyCondition: (latencyCondition ifNil: [ #uncontrolled ]);
		scope: (CoBenchmarkPackage on: package);
		yourself.
	block value: benchmark.
	results ifNotNil: [ results at: strategy put: benchmark ].
	^ benchmark run; yourself
]

{ #category : 'LLM' }
CooBenchRunner >> nameCompletionFor: kind hybrid: hybrid [
	^ self modelBenchmark: (hybrid ifTrue: [ CooHybridLLMBenchmarks ] ifFalse: [ CooLLMBenchmarks ])
		kind: kind strategy: (hybrid ifTrue: [ #hybridNameCompletion ] ifFalse: [ #llmNameCompletion ])
		configure: [ :bench | bench completionLevel ]
]

{ #category : 'LLM' }
CooBenchRunner >> rerankingFor: kind strategy: strategy [
	^ self modelBenchmark: CooRerankingHybridBenchmarks kind: kind strategy: strategy configure: [ :bench |
		strategy = #neuralRerankingCompletion ifTrue: [ bench weights: #(1 0 0) ].
		strategy = #dependencyRerankingCompletion ifTrue: [
			bench weights: #(1 1 0);
				heuristics: { #Dependency -> ((kind = #messages
					ifTrue: [ CooStaticBenchmarksMessage ] ifFalse: [ CooStaticBenchmarksVariables ]) new
					builder: self dependencyBuilder; yourself) } ] ]
]

{ #category : 'benchmarks' }
CooBenchRunner class >> compareModels: modelNames messagesAndVariablesFor: packageNames [
	^ self compareModels: modelNames messagesAndVariablesFor: packageNames
		strategies: #(llmCompletion hybridCompletion llmNameCompletion hybridNameCompletion rerankingCompletion)
		latencyCondition: #warm
]

{ #category : 'benchmarks' }
CooBenchRunner class >> compareModels: modelNames messagesAndVariablesFor: packageNames strategies: strategies latencyCondition: condition [
	"Use explicit clients, never mutate the process-wide default. Static results
	are shared, not measured again for each model. All runs use the same packages."
	| matrix staticResults packages |
	matrix := OrderedDictionary new.
	staticResults := Dictionary new.
	packages := packageNames collect: [ :each | PackageOrganizer default packageNamed: each ].
	modelNames do: [ :modelName |
		| comparison client |
		client := CooLLMClient default copy model: modelName; yourself.
		comparison := Dictionary new.
		{ #messages -> CooBenchRunnerMessage. #variables -> CooBenchRunnerVariables } do: [ :entry |
			| runs |
			runs := packages collect: [ :pack |
				| runner key shared |
				key := { entry key. pack name }.
				runner := entry value new package: pack; baseline: #heuristicsBaseline;
					others: #(heuristicsDependency); yourself.
				shared := staticResults at: key ifAbsentPut: [ runner run. runner results ].
				runner client: client; latencyCondition: condition;
					others: #(heuristicsDependency) , strategies;
					runWithResults: shared.
				runner ].
			comparison at: entry key put: { runs.
				self stringResultForABenchCollection: runs.
				self latexTableResultForABenchCollection: runs } ].
		matrix at: modelName put: comparison ].
	^ matrix
]

{ #category : 'exporting' }
CooBenchRunner class >> exportModels: matrix to: directory [
	^ CooBenchmarkChart exportModels: matrix to: directory
]
