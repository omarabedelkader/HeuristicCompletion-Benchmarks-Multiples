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
		'results'
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

{ #category : 'accessing' }
CooBenchRunner >> run [

	results := Dictionary new.
	{ baseline } , others do: [ :s |
		results at: s put: (self perform: s) ]
]
