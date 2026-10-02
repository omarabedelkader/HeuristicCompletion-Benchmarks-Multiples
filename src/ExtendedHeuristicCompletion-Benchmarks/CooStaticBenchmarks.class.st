"
`CoStaticBenchmarks` provides a benchmarking framework for evaluating the performance and accuracy of various sorting algorithms in the context of heuristic-based completion systems. It defines methods for executing benchmarks, collecting metrics such as completion accuracy, memory usage, and execution time, and generating statistical reports. The benchmarks can be executed on different sorter classes, and results are stored for further inspection and analysis.

`CoStaticBenchmarks`, is designed to run completion benchmarks over a given **scope** (typically a class or package).

1. **Accuracy** (whether the correct selector is found among the top 10 suggestions and at which index).
2. **Timing** (the total and average time taken to compute suggestions for each prefix size).
3. **Memory Usage** (the total and average memory consumed during benchmark execution).
4. **Mean Reciprocal Rank (MRR)** (measures how high the correct suggestion appears in the ranked list).
5. **Normalized Discounted Cumulative Gain (NDCG)** (evaluates ranking quality based on relevance distribution).
6. **Rank Distribution** (counts how frequently the correct completion appears in each ranking position).
7. **Recall@K** (measures how often the correct result appears within the top-K results).


## API:
### Key Responsibilities

1. **Execution and Initialization (`run`, `runFor:`)**  
   - The `run` method iterates through all methods within a specified scope, parsing them to identify message callsites for benchmarking.  
   - `runFor:` is a convenience method that creates an instance and immediately executes benchmarks for a specified class.  

2. **Benchmarking Callsites (`benchCallsite:atPosition:`)**  
   - For each callsite, the process iterates over prefix lengths ranging from 2 to 8 characters (or fewer if the selector is shorter).  
   - It records whether the original selector appears within the top 10 completion candidates and its ranking.  
   - Completion times are tracked and accumulated in `completionTimes`.  

3. **Accuracy Measurement (`accuracyForCompletionIndex:withPrefixSize:`)**  
   - Evaluates how frequently the correct selector appears within specific top-index ranges (e.g., 1st, 2nd, 3rd) for a given prefix size.  
   - Accuracy is calculated by dividing the number of successful completions by the total attempts.  

4. **Performance Timing (`logTime:forPrefix:`, `totalTimeForPrefix:`)**  
   - Logs execution times for each benchmark run in `completionTimes`.  
   - Provides methods like `totalTimeForPrefix:` and `averageTimeForPrefix:` to aggregate and analyze performance data.  

5. **Results Analysis and Presentation (`inspectionResults`, `timeResults`)**  
   - Uses methods annotated with `<inspectorPresentationOrder:>` to format **accuracy results** in a table via `SpTablePresenter`.  
   - Displays **timing results**, including total and average execution times per prefix size, in a structured manner.



## Typical Usage:

See my subclasses



```
results := CooStaticBenchmarksMessage runAllSortersOnPackage: NECEntry package.
```

```
CooStaticBenchmarksMessage
    runAllSortersOnPackage: NECEntry package
    exportReportTo: 'nec-sorter-benchmarks.txt'.
```

```
single := CooStaticBenchmarksMessage new
    scope: (CoBenchmarkPackage on: CompletionSorter package);
    builder: (CoGlobalSorterResultSetBuilder new
        sorterClass: AlphabeticSorter;
        yourself);
    run.
```
"
Class {
	#name : 'CooStaticBenchmarks',
	#superclass : 'Object',
	#instVars : [
		'scope',
		'completionBenchs',
		'builder',
		'completionTimes',
		'memoryUsages',
		'name'
	],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Benchmarks',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Benchmarks'
}

{ #category : 'examples' }
CooStaticBenchmarks class >> messageBenchmarksOnNECompletion [
	<script>
	
	(CooStaticBenchmarksMessage new
		scope: (CoBenchmarkPackage on: CompletionSorter package);
		builder: CoASTHeuristicsResultSetBuilder new;
		run) inspect



]

{ #category : 'running' }
CooStaticBenchmarks class >> onPackage: aPackage heuristics: aHeuristicsBlock [

	| benchmark builder |
	builder := CoASTHeuristicsResultSetBuilder new.
	aHeuristicsBlock value: builder.

	benchmark := self new
		             scope: (CoBenchmarkPackage on: aPackage);
		             builder: builder;
		             yourself.
	^ benchmark
]

{ #category : 'running sorter' }
CooStaticBenchmarks class >> runAllSortersOnPackage: aPackageIdentifier [
    "Runs the CoStaticBenchmarks for every sorter class in sorterClasses using the given package as the scope.
    Returns a Dictionary mapping sorter class symbols to their benchmark instances."

    | pkg results isPkg |
    isPkg := aPackageIdentifier isKindOf: Package.
    isPkg ifTrue: [ pkg := aPackageIdentifier ]
         ifFalse: [ pkg := PackageOrganizer default packageNamed: aPackageIdentifier ].
    
    results := Dictionary new.
    
    self sorterClasses do: [ :sorterSymbol |
        | sorterClass benchmark |
        
        sorterClass := Smalltalk globals at: sorterSymbol.
        benchmark := self new
            scope: (CoBenchmarkPackage on: pkg);
            builder: (CooGlobalSorterResultSetBuilder new
                        sorterClass: sorterClass;
                        yourself);
            yourself.
    
        benchmark run.
    
        results at: sorterSymbol put: benchmark.
    ].
    
    ^ results
]

{ #category : 'running' }
CooStaticBenchmarks class >> runAllSortersOnPackage: aPackageIdentifier exportReportTo: aFileReference [
	"Run all known sorters on the given package and write a human readable report for each sorter to the given file reference or path. Returns the same Dictionary as #runAllSortersOnPackage:."

	| results output |
	results := self runAllSortersOnPackage: aPackageIdentifier.
	output := aFileReference asFileReference.
	output ensureCreateFile.
	output writeStreamDo: [ :stream |
		results keys asSortedCollection do: [ :sorterSymbol |
			| benchmark |
			benchmark := results at: sorterSymbol.
			stream
				nextPutAll: '### ';
				nextPutAll: sorterSymbol asString;
				nextPutAll: ' ###';
				cr; cr.
			stream nextPutAll: benchmark textReport; cr; cr ] ].
	^ results
]

{ #category : 'running' }
CooStaticBenchmarks class >> runOnPackage: aPackage heuristics: aHeuristicsBlock [

	^ (self onPackage: aPackage heuristics: aHeuristicsBlock) run; yourself

]

{ #category : 'running' }
CooStaticBenchmarks class >> runOnPackageOrName: aPackageOrName heuristics: aHeuristicsBlock [

	| package |
	package := aPackageOrName isString
		           ifTrue: [ PackageOrganizer default packageNamed: aPackageOrName ]
		           ifFalse: [ aPackageOrName ].
	package ifNil: [
		^ self error: 'Package not found: ' , aPackageOrName printString ].
	
	^ self runOnPackage: package heuristics: aHeuristicsBlock
]

{ #category : 'examples' }
CooStaticBenchmarks class >> runVariableOnNeCompletionPackage [
	<script>
	
	^ (CooStaticBenchmarksVariables 
			runOnPackage: (PackageOrganizer default packageNamed: 'NECompletion')
			heuristics: [:b | b]) inspect. 
]

{ #category : 'running sorter' }
CooStaticBenchmarks class >> sorterClasses [
	"Answers an array of the symbols of all sorter classes to be run."

	^ #( NoSorter SizeSorter AISorter )
]

{ #category : 'metrics' }
CooStaticBenchmarks >> accuracyForCompletionIndex: completionIndexRange withPrefixSize: prefixSize [
	"Computes the accuracy for a given completion index range and prefix size."

	| totalEntries |
	totalEntries := self totalEntriesPerPrefixSize: prefixSize.
	totalEntries = 0 ifTrue: [ ^ 0 ].
	^ (completionIndexRange sum: [ :index |
		   (completionBenchs at: index at: prefixSize ifAbsent: [ { 0 } ])
			   first ]) / totalEntries
]

{ #category : 'inspector' }
CooStaticBenchmarks >> accuracyInspectionResults: aBuilder [
	"Generates a table displaying completion accuracy."

	<inspectorPresentationOrder: 0 title: 'Accuracy'>
	| table |
	table := SpTablePresenter new
		         items: self completionIndexes;
		         addColumn: (SpCompositeTableColumn new
				          title: 'Prefix';
				          addColumn:
					          (SpStringTableColumn evaluated: [ :completionIndexRange |
							           | label |
							           label := '% '.
							           label := label , (completionIndexRange size = 1
									                     ifTrue: [
										                     { 'fail'. '1st'. '2nd'. '3rd' } at:
												                     completionIndexRange first + 1 ]
									                     ifFalse: [
										                     completionIndexRange first asString
										                     , '-'
										                     , completionIndexRange last asString ]).
							           label ]);
				          yourself).

	self prefixSizes do: [ :prefixSize |
		table addColumn: (SpStringTableColumn
				 title: prefixSize asString
				 evaluated: [ :completionIndexRange |
					 | float |
					 float := self
						          accuracyForCompletionIndex: completionIndexRange
						          withPrefixSize: prefixSize.
					 float * 100 asFloat round: 2 ]) ].
	^ table
]

{ #category : 'metrics' }
CooStaticBenchmarks >> accuracyPerSelectorLength: selectorLength [
	"Computes the accuracy of completions based on method selector length."

	| relevantCallsites correctCount totalCount |
	relevantCallsites := 0.
	correctCount := 0.
	totalCount := 0.
	completionBenchs keysAndValuesDo: [ :rank :prefixDict |
		prefixDict keysAndValuesDo: [ :pSize :info |
			| count usedSelectors |
			count := info first.
			usedSelectors := info second.
			usedSelectors do: [ :sel |
				sel size = selectorLength ifTrue: [
					relevantCallsites := relevantCallsites + 1.
					rank ~= 0 ifTrue: [ correctCount := correctCount + 1 ] ] ].
			totalCount := totalCount + count ] ].
	relevantCallsites = 0 ifTrue: [ ^ 0 ].
	^ correctCount asFloat / relevantCallsites
]

{ #category : 'accessing' }
CooStaticBenchmarks >> accuracyResults [
	"Generates a BenchResult"

	| table |
	table := CooBenchResult new. 
	table name: self name.
	
	self prefixSizes do: [ :prefixSize |
		| col colElements |
		col := CooResultColumn new.
		col title: prefixSize asString.
		table addColumn: col.
		colElements := self completionIndexes collect: [ :completionIndexRange |
					 | float |
					 float := self
						          accuracyForCompletionIndex: completionIndexRange
						          withPrefixSize: prefixSize.
					 (float * 100 asFloat round: 2) ].
		col elements: colElements].
	^ table
]

{ #category : 'metrics' }
CooStaticBenchmarks >> averageMemoryForPrefix: prefixSize [
	"Computes the average memory usage for a given prefix size."
	
	| stats |
	stats := memoryUsages at: prefixSize ifAbsent: [ #( 0 0 ) ].
	stats second = 0
		ifTrue: [ ^ 0 ]
		ifFalse: [ ^ stats first / stats second ]
]

{ #category : 'metrics' }
CooStaticBenchmarks >> averageTimeForPrefix: prefixSize [
	"Computes the average execution time for completions with a given prefix size."

	| times |
	times := completionTimes at: prefixSize ifAbsent: [ #( 0 0 ) ].
	times second = 0
		ifTrue: [ ^ 0 ]
		ifFalse: [ ^ times first / times second ]
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> benchCallsite: aMessageNode atPosition: aPosition [

	self subclassResponsibility
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> buildCompletionFor: aMessageNode atPosition: aPosition [

	"Method to generate completion suggestions."
	self subclassResponsibility
]

{ #category : 'accessing' }
CooStaticBenchmarks >> builder [

	^ builder
]

{ #category : 'accessing' }
CooStaticBenchmarks >> builder: aCompletionBuilder [

	builder := aCompletionBuilder
]

{ #category : 'accessing' }
CooStaticBenchmarks >> completionBenchs [

	^ completionBenchs
]

{ #category : 'accessing' }
CooStaticBenchmarks >> completionBenchs: anObject [

	completionBenchs := anObject
]

{ #category : 'accessing' }
CooStaticBenchmarks >> completionIndexLabelFor: completionIndexRange [ 

	^ completionIndexRange size = 1
		  ifTrue: [
			  #( 'fail' '1st' '2nd' '3rd' )
				  at: completionIndexRange first + 1
				  ifAbsent: [ completionIndexRange first asString ] ]
		  ifFalse: [
			  completionIndexRange first asString , '-' ,
			  completionIndexRange last asString ]
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> completionIndexes [

	^ { 1 to: 1.
	  2 to: 2.
	  3 to: 3.
	  4 to: 10.
	  0 to: 0.
	}
]

{ #category : 'accessing' }
CooStaticBenchmarks >> completionTimes [

	^ completionTimes
]

{ #category : 'accessing' }
CooStaticBenchmarks >> completionTimes: anObject [

	completionTimes := anObject
]

{ #category : 'metrics' }
CooStaticBenchmarks >> currentMemoryUsage [

    ^ Smalltalk vm memorySize
]

{ #category : 'diff' }
CooStaticBenchmarks >> diff: anotherBenchmark [ 

    | tableDataSelf tableDataOther tableDataDifference |
    "Generate accuracy tables for self"
    tableDataSelf := self completionIndexes collect: [ :completionIndexRange |
        | label rowData |
        
        "Compute the Prefix column value"
        label := '% '.
        label := label , (completionIndexRange size = 1
            ifTrue: [ { 'fail'. '1st'. '2nd'. '3rd' } at: (completionIndexRange first + 1) ]
            ifFalse: [ completionIndexRange first asString , '-' , completionIndexRange last asString ]).
    
        "Compute the accuracy values for each prefix size"
        rowData := self prefixSizes collect: [ :prefixSize |
            (self accuracyForCompletionIndex: completionIndexRange withPrefixSize: prefixSize) * 100
                printShowingDecimalPlaces: 2
        ].
    
        "Combine Prefix column and computed values"
        { label } , rowData.
    ].
    
    "Generate accuracy tables for anotherBenchmark"
    tableDataOther := anotherBenchmark completionIndexes collect: [ :completionIndexRange |
        | label rowData |
        
        "Compute the Prefix column value"
        label := '% '.
        label := label , (completionIndexRange size = 1
            ifTrue: [ { 'fail'. '1st'. '2nd'. '3rd' } at: (completionIndexRange first + 1) ]
            ifFalse: [ completionIndexRange first asString , '-' , completionIndexRange last asString ]).
    
        "Compute the accuracy values for each prefix size"
        rowData := anotherBenchmark prefixSizes collect: [ :prefixSize |
            (anotherBenchmark accuracyForCompletionIndex: completionIndexRange withPrefixSize: prefixSize) * 100
                printShowingDecimalPlaces: 2
        ].
    
        "Combine Prefix column and computed values"
        { label } , rowData.
    ].
    
    "Calculate the difference between the two tables"
    tableDataDifference := (1 to: tableDataSelf size) collect: [ :index |
        | label diffRowData |
    
        label := (tableDataSelf at: index) first. "Keep the prefix label"
        diffRowData := ((tableDataSelf at: index) allButFirst) withIndexCollect: [ :value :i |
            | valueA valueB difference |
    
            valueA := value asNumber ifNil: [ 0 ].
            valueB := ((tableDataOther at: index) at: (i + 1)) asNumber ifNil: [ 0 ].
            difference := valueA - valueB.
            
            difference printShowingDecimalPlaces: 2
        ].
    
        { label } , diffRowData.
    ].
    
    "Return a dictionary with both tables and the computed difference"
    ^ { 'BenchmarkA' -> tableDataSelf. 'BenchmarkB' -> tableDataOther. 'Difference' -> tableDataDifference }.


]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> extractPrefixFrom: receiver at: index [

	self subclassResponsibility
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> fetchTopCandidatesFrom: completion usingPrefix: prefix [

	self subclassResponsibility
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> findCompletionIndexFor: receiver inCandidates: candidates [

	self subclassResponsibility
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> gradeForPrefixSize: prefixSize [

	^ self accuracyForCompletionIndex: (2 to: 8) withPrefixSize: prefixSize
]

{ #category : 'initialization' }
CooStaticBenchmarks >> initialize [

	super initialize.
	completionBenchs := Dictionary new.
	builder := CoASTHeuristicsResultSetBuilder new.
	completionTimes := Dictionary new. 
	memoryUsages := Dictionary new.
	name := 'Baseline'
]

{ #category : 'printing' }
CooStaticBenchmarks >> latexInspectionResults [

    "Generate and return a LaTeX table representation of the data shown in #inspectionResults (accuracy table)."
    | prefixSizes completionIndexRanges |
    ^ String streamContents: [:s |
        prefixSizes := self prefixSizes.
        completionIndexRanges := self completionIndexes.  

        s nextPutAll: '\begin{table}[ht]'; cr.
        s nextPutAll: '\centering'; cr.
        s nextPutAll: '\begin{tabular}{|l'.

        prefixSizes size timesRepeat: [ s nextPutAll: '|c' ].
        s nextPutAll: '|}'; cr.
        s nextPutAll: '\hline'; cr.

        s nextPutAll: 'Prefix'.
        prefixSizes do: [:pSize |
            s nextPutAll: ' & '.
            s nextPutAll: pSize asString
        ].
        s nextPutAll: '\\ \hline'; cr.

        completionIndexRanges do: [:range |
            | label accuracyPercentage |
            label := (range size = 1
                ifTrue: [
                    #('fail' '1st' '2nd' '3rd')
                        at: (range first + 1)
                        ifAbsent: [ range first asString ]
                ]
                ifFalse: [
                    (range first asString), '-', (range last asString)
                ]).
            s nextPutAll: label.

            prefixSizes do: [:pSize |
                accuracyPercentage := (self accuracyForCompletionIndex: range withPrefixSize: pSize) * 100.
                s nextPutAll: ' & '.
                s nextPutAll: (accuracyPercentage printShowingDecimalPlaces: 2)
            ].

            s nextPutAll: '\\ \hline'; cr.
        ].
        s nextPutAll: '\end{tabular}'; cr.
        s nextPutAll: '\caption{Completion Accuracy Results}'; cr.
        s nextPutAll: '\end{table}'; cr.
    ]
]

{ #category : 'printing' }
CooStaticBenchmarks >> latexMMRResults [

    | prefixSizes |
    prefixSizes := self prefixSizes.
    ^ String streamContents: [:s |
        s nextPutAll: '\begin{table}[ht]'; cr.
        s nextPutAll: '\centering'; cr.
        s nextPutAll: '\begin{tabular}{|c|c|}'; cr.
        s nextPutAll: '\hline'; cr.
        s nextPutAll: 'Prefix & MRR \\ \hline'; cr.
        prefixSizes do: [:pSize |
            | val |
            val := (self mmrForPrefixSize: pSize) printShowingDecimalPlaces: 4.
            s nextPutAll: pSize asString; nextPutAll: ' & '.
            s nextPutAll: val; nextPutAll: ' \\ \hline'; cr.
        ].
        s nextPutAll: '\end{tabular}'; cr.
        s nextPutAll: '\caption{Mean Reciprocal Rank by prefix size}'; cr.
        s nextPutAll: '\end{table}'; cr.
    ].

]

{ #category : 'printing' }
CooStaticBenchmarks >> latexResultsFor: metricType [
	"Generate a LaTeX table representation for the specified metricType.
    Available metricType values:
    - #accuracy -> Completion Accuracy table
    - #time -> Completion Time table
    - #mmr -> Mean Reciprocal Rank (MRR) table
    - #ndcg -> Normalized Discounted Cumulative Gain (NDCG) table
    - #rankDistribution -> Rank Distribution table
    - #recall -> Recall@K table"

	^ String streamContents: [ :s |
		  s
			  nextPutAll: '\begin{table}[ht]';
			  cr.
		  s
			  nextPutAll: '\centering';
			  cr.

		  metricType = #accuracy ifTrue: [
			  | prefixSizes completionIndexRanges |
			  prefixSizes := self prefixSizes.
			  completionIndexRanges := self completionIndexes.

			  s nextPutAll: '\begin{tabular}{|l'.
			  prefixSizes size timesRepeat: [ s nextPutAll: '|c' ].
			  s
				  nextPutAll: '|}';
				  cr.
			  s
				  nextPutAll: '\hline';
				  cr.

			  s nextPutAll: 'Prefix'.
			  prefixSizes do: [ :pSize |
				  s nextPutAll: ' & '.
				  s nextPutAll: pSize asString ].
			  s
				  nextPutAll: '\\ \hline';
				  cr.

			  completionIndexRanges do: [ :range |
				  | label accuracyPercentage |
				  label := range size = 1
					           ifTrue: [
						           #( 'fail' '1st' '2nd' '3rd' )
							           at: range first + 1
							           ifAbsent: [ range first asString ] ]
					           ifFalse: [
					           range first asString , '-' , range last asString ].
				  s nextPutAll: label.

				  prefixSizes do: [ :pSize |
					  accuracyPercentage := (self
						                         accuracyForCompletionIndex: range
						                         withPrefixSize: pSize) * 100.
					  s nextPutAll: ' & '.
					  s nextPutAll: (accuracyPercentage printShowingDecimalPlaces: 2) ].
				  s
					  nextPutAll: '\\ \hline';
					  cr ].
			  s
				  nextPutAll: '\end{tabular}';
				  cr.
			  s
				  nextPutAll: '\caption{Completion Accuracy Results}';
				  cr ].

		  metricType = #time ifTrue: [
			  | prefixArray |
			  prefixArray := self prefixSizes.
			  s
				  nextPutAll: '\begin{tabular}{|c|c|c|c|}';
				  cr.
			  s
				  nextPutAll: '\hline';
				  cr.
			  s
				  nextPutAll:
					  'Prefix & Total (ms) & Count & Average (ms)\\ \hline';
				  cr.

			  prefixArray do: [ :pSize |
				  | total count average |
				  total := self totalTimeForPrefix: pSize.
				  count := (completionTimes at: pSize ifAbsent: [ #( 0 0 ) ])
					           second.
				  average := self averageTimeForPrefix: pSize.
				  s
					  nextPutAll: pSize asString;
					  nextPutAll: ' & ';
					  print: total;
					  nextPutAll: ' & ';
					  print: count;
					  nextPutAll: ' & ';
					  print: (average roundTo: 0.01);
					  nextPutAll: '\\ \hline';
					  cr ].
			  s
				  nextPutAll: '\end{tabular}';
				  cr.
			  s
				  nextPutAll: '\caption{Completion Time Results}';
				  cr ].

		  metricType = #mmr ifTrue: [
			  | prefixSizes |
			  prefixSizes := self prefixSizes.
			  s
				  nextPutAll: '\begin{tabular}{|c|c|}';
				  cr.
			  s
				  nextPutAll: '\hline';
				  cr.
			  s
				  nextPutAll: 'Prefix & MRR \\ \hline';
				  cr.
			  prefixSizes do: [ :pSize |
				  | val |
				  val := (self mmrForPrefixSize: pSize)
					         printShowingDecimalPlaces: 2.
				  s
					  nextPutAll: pSize asString;
					  nextPutAll: ' & '.
				  s
					  nextPutAll: val;
					  nextPutAll: ' \\ \hline';
					  cr ].
			  s
				  nextPutAll: '\end{tabular}';
				  cr.
			  s
				  nextPutAll: '\caption{Mean Reciprocal Rank by prefix size}';
				  cr ].

		  metricType = #ndcg ifTrue: [
			  | prefixSizes |
			  prefixSizes := self prefixSizes.
			  s
				  nextPutAll: '\begin{tabular}{|c|c|}';
				  cr.
			  s
				  nextPutAll: '\hline';
				  cr.
			  s
				  nextPutAll: 'Prefix & NDCG \\ \hline';
				  cr.
			  prefixSizes do: [ :pSize |
				  | val |
				  val := (self ndcgForPrefixSize: pSize)
					         printShowingDecimalPlaces: 2.
				  s
					  nextPutAll: pSize asString;
					  nextPutAll: ' & '.
				  s
					  nextPutAll: val;
					  nextPutAll: ' \\ \hline';
					  cr ].
			  s
				  nextPutAll: '\end{tabular}';
				  cr.
			  s
				  nextPutAll:
					  '\caption{Normalized Discounted Cumulative Gain (NDCG) by prefix size}';
				  cr ].

		  metricType = #rankDistribution ifTrue: [
			  | prefixSizes |
			  prefixSizes := self prefixSizes.
			  s nextPutAll: '\begin{tabular}{|c|'.

			  (1 to: 10) do: [ :i | s nextPutAll: 'c|' ]. "✅ Fixed here"

			  s
				  nextPutAll: '}';
				  cr.
			  s
				  nextPutAll: '\hline';
				  cr.

			  s nextPutAll: 'Prefix'.
			  (1 to: 10) do: [ :rank |
				  s nextPutAll: ' & Rank '.
				  s nextPutAll: rank asString ].

			  s
				  nextPutAll: '\\ \hline';
				  cr.

			  prefixSizes do: [ :pSize |
				  s nextPutAll: pSize asString.
				  (self rankDistributionForPrefixSize: pSize) do: [ :val |
					  s nextPutAll: ' & '.
					  s nextPutAll: val asString ].
				  s
					  nextPutAll: '\\ \hline';
					  cr ].

			  s
				  nextPutAll: '\end{tabular}';
				  cr.
			  s
				  nextPutAll: '\caption{Rank Distribution by prefix size}';
				  cr ].

		  metricType = #recall ifTrue: [
			  | prefixSizes kValues |
			  prefixSizes := self prefixSizes.
			  kValues := #( 1 3 5 10 ).
			  s nextPutAll: '\begin{tabular}{|c|'.
			  prefixSizes size timesRepeat: [ s nextPutAll: 'c|' ].
			  s
				  nextPutAll: '}';
				  cr.
			  s
				  nextPutAll: '\hline';
				  cr.
			  s nextPutAll: 'K'.
			  prefixSizes do: [ :pSize |
				  s nextPutAll: ' & Prefix ' , pSize asString ].
			  s
				  nextPutAll: '\\ \hline';
				  cr.
			  kValues do: [ :k |
				  s nextPutAll: k asString.
				  prefixSizes do: [ :pSize |
					  s nextPutAll: ' & '.
					  s nextPutAll: ((self recallAtK: k withPrefixSize: pSize) * 100
							   printShowingDecimalPlaces: 2) asString ].
				  s
					  nextPutAll: '\\ \hline';
					  cr ].
			  s
				  nextPutAll: '\end{tabular}';
				  cr.
			  s
				  nextPutAll: '\caption{Recall@K by prefix size}';
				  cr ].

		  s
			  nextPutAll: '\end{table}';
			  cr ]
]

{ #category : 'printing' }
CooStaticBenchmarks >> latexTimeResults [

    ^ String streamContents: [:s |
        | prefixArray |
        prefixArray := self prefixSizes.
        s nextPutAll: '\begin{table}[ht]'; cr.
        s nextPutAll: '\centering'; cr.
        s nextPutAll: '\begin{tabular}{|c|c|c|c|}'; cr.
        s nextPutAll: '\hline'; cr.
        s nextPutAll: 'Prefix & Total (ms) & Count & Average (ms)\\ \hline'; cr.

        prefixArray do: [:pSize |
            | total count average |
            total := self totalTimeForPrefix: pSize.
            count := (completionTimes at: pSize ifAbsent: [ #(0 0) ]) second.
            average := self averageTimeForPrefix: pSize.
            s
                nextPutAll: pSize asString; nextPutAll: ' & ';
                print: total; nextPutAll: ' & ';
                print: count; nextPutAll: ' & ';
                print: (average roundTo: 0.01); 
                nextPutAll: '\\ \hline'; cr
        ].
        s nextPutAll: '\end{tabular}'; cr.
        s nextPutAll: '\caption{Completion Time Results}'; cr.
        s nextPutAll: '\end{table}'; cr.
    ]
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> logExecutionTimeSince: startTime forPrefixSize: prefixSize [

	self subclassResponsibility
]

{ #category : 'metrics' }
CooStaticBenchmarks >> logMemory: usage forPrefix: prefixSize [ 

    | stats |
    stats := memoryUsages at: prefixSize ifAbsent: [ #( 0 0 ) ].
    memoryUsages
        at: prefixSize
        put: { stats first + usage. stats second + 1 }.
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> logMemoryUsageSince: startMemory forPrefixSize: prefixSize [

	self subclassResponsibility
]

{ #category : 'metrics' }
CooStaticBenchmarks >> logTime: executionTime forPrefix: prefixSize [

    | times |
    times := completionTimes
        at: prefixSize
        ifAbsent: [ #( 0 0 )  ].
    completionTimes
        at: prefixSize
        put: { times first + executionTime.  times second + 1 }.
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> maxPrefixSizeFor: receiver [

	self subclassResponsibility
]

{ #category : 'inspector' }
CooStaticBenchmarks >> memoryInspectionResults: aBuilder [
	"Displays memory usage statistics."
	
	<inspectorPresentationOrder: 3 title: 'Memory Usage'>
	| table |
	table := SpTablePresenter new
		         items: self prefixSizes;
		         addColumn: (SpStringTableColumn
				          title: 'Prefix'
				          evaluated: [ :prefixSize | prefixSize asString ]);
		         addColumn: (SpStringTableColumn
				          title: 'Total (bytes)'
				          evaluated: [ :prefixSize |
					          (self totalMemoryForPrefix: prefixSize) asString ]);
		         addColumn:
			         (SpStringTableColumn
				          title: 'Total (MB)'
				          evaluated: [ :prefixSize |
					          ((self totalMemoryForPrefix: prefixSize) / 1024 / 1024)
						          asFloat
						          round: 2;
						          asString ]);
		         yourself.
	^ table
]

{ #category : 'accessing' }
CooStaticBenchmarks >> memoryUsages [

	^ memoryUsages
]

{ #category : 'accessing' }
CooStaticBenchmarks >> memoryUsages: anObject [

	memoryUsages := anObject
]

{ #category : 'metrics' }
CooStaticBenchmarks >> mmr [

    "Return the overall Mean Reciprocal Rank across all prefix sizes  (2 through 8) in a single number."
    | totalAll sumAll |
    sumAll := 0.0.
    totalAll := 0.
    (2 to: 8) do: [ :prefixSize |
        | prefixCount |
        prefixCount := self totalEntriesPerPrefixSize: prefixSize.
        totalAll := totalAll + prefixCount.
        sumAll := sumAll + (prefixCount * (self mmrForPrefixSize: prefixSize))
    ].
    totalAll = 0 ifTrue: [ ^ 0 ].
    ^ sumAll / totalAll
]

{ #category : 'metrics' }
CooStaticBenchmarks >> mmrForPrefixSize: prefixSize [
	"Computes the Mean Reciprocal Rank (MRR) for a given prefix size."

	| total sumOfReciprocalRanks |
	total := self totalEntriesPerPrefixSize: prefixSize.
	total = 0 ifTrue: [ ^ 0 ].

	sumOfReciprocalRanks := 0.0.

	1 to: 10 do: [ :rank |
		| entry rankCount |
		entry := (completionBenchs at: rank ifAbsent: [ Dictionary new ])
			         at: prefixSize
			         ifAbsent: [ #( 0 #(  ) ) ].

		rankCount := entry first.
		sumOfReciprocalRanks := sumOfReciprocalRanks
		                        + (rankCount * (1 / rank)) ].

	^ sumOfReciprocalRanks / total
]

{ #category : 'inspector' }
CooStaticBenchmarks >> mmrInspectionResults: aBuilder [
	"Displays Mean Reciprocal Rank results."

	<inspectorPresentationOrder: 4 title: 'MMR Results'>
	| table |
	table := SpTablePresenter new
		         items: self prefixSizes;
		         addColumn: (SpStringTableColumn
				          title: 'Prefix'
				          evaluated: [ :prefixSize | prefixSize asString ]);
		         addColumn: (SpStringTableColumn
				          title: 'Mean Reciprocal Rank'
				          evaluated: [ :prefixSize |
					          | valueAsString |
					          valueAsString := (self mmrForPrefixSize: prefixSize)
						                           asFloat round: 2.
					          valueAsString ]);
		         yourself.

	^ table
]

{ #category : 'inspector' }
CooStaticBenchmarks >> mmrString [

	^ String streamContents: [ :s |
		s << 'mmr: '.
		self mmr printOn: s. 
		s cr.
		self prefixSizes 
			do: [ :prefixSize |
				prefixSize printOn: s. 
				s space. 
				((self mmrForPrefixSize: prefixSize) asFloat round: 2) printOn: s ]
			separatedBy: [ s cr ] 
			]

]

{ #category : 'accessing' }
CooStaticBenchmarks >> name [

	^ name
]

{ #category : 'accessing' }
CooStaticBenchmarks >> name: aString [

	name := aString
]

{ #category : 'metrics' }
CooStaticBenchmarks >> ndcgForPrefixSize: prefixSize [

    "Compute Normalized Discounted Cumulative Gain for each prefix size."
    | total relevantCount idealDcg actualDcg |
    total := self totalEntriesPerPrefixSize: prefixSize.
    total isNumber ifFalse: [ ^ 0 ].
    total = 0 ifTrue: [ ^ 0 ].

    actualDcg := 0.0.
    1 to: 10 do: [ :rank |
        | entry rankCount rel factor |
        (completionBenchs respondsTo: #at:ifAbsent:) ifFalse: [ ^ 0 ].
        entry := (completionBenchs 
                    at: rank 
                    ifAbsent: [ Dictionary new ]) 
                  at: prefixSize 
                  ifAbsent: [ #(0 #()) ].

        (entry isArray and: [ entry size > 0 ]) ifFalse: [ ^ 0 ].

        rankCount := entry first.
        rankCount isNumber ifFalse: [ ^ 0 ].

        rel := 1.  
        factor := (2 raisedTo: rel) - 1.
        actualDcg := actualDcg + (rankCount * (factor / ((rank + 1) log: 2))).
    ].

    idealDcg := 0.0.
    relevantCount := total. 

    1 to: (relevantCount min: 10) do: [ :r |
        idealDcg := idealDcg 
            + ( (2 raisedTo: 1) - 1 ) / ((r + 1) log: 2). 
    ].
    idealDcg = 0  
        ifTrue: [ ^ 0 ]  
        ifFalse: [ ^ (actualDcg / idealDcg) ].
]

{ #category : 'inspector' }
CooStaticBenchmarks >> ndcgInspectionResults: aBuilder [
	"Displays NDCG (ranking effectiveness) results."
	
	<inspectorPresentationOrder: 5 title: 'NDCG Results'>
	| table |
	table := SpTablePresenter new
		         items: self prefixSizes;
		         addColumn: (SpStringTableColumn
				          title: 'Prefix'
				          evaluated: [ :prefixSize | prefixSize asString ]);
		         addColumn: (SpStringTableColumn
				          title: 'NDCG'
				          evaluated: [ :prefixSize |
					          (self ndcgForPrefixSize: prefixSize) asFloat round: 2 ]);
		         yourself.
	^ table
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> prefixSizes [

	^ 2 to: 8
]

{ #category : 'printing' }
CooStaticBenchmarks >> printOn: aStream [

	aStream
		nextPutAll: name;
		space;
		print: builder;
		nextPutAll: '(';
		print: scope;
		nextPutAll: ')'
]

{ #category : 'metrics' }
CooStaticBenchmarks >> rankDistributionForPrefixSize: prefixSize [ 

    "Returns an Array of length 10, where each element is  how many times we found the correct item at rank i for this prefix size."
    | distribution |
    distribution := (1 to: 10) collect: [ :rank |
        ( (completionBenchs at: rank ifAbsent: [ Dictionary new ])
            at: prefixSize ifAbsent: [ #(0 #()) ]) first
    ].
    ^ distribution

]

{ #category : 'inspector' }
CooStaticBenchmarks >> rankDistributionInspectionResults: aBuilder [

	<inspectorPresentationOrder: 6 title: 'Rank Distribution'>
	| table |
	table := SpTablePresenter new
		         items: self prefixSizes;
		         addColumn: (SpStringTableColumn
				          title: 'Prefix'
				          evaluated: [ :prefixSize | prefixSize asString ]).
	1 to: 10 do: [ :rank |
		table addColumn: (SpStringTableColumn
				 title: 'Rank ' , rank asString
				 evaluated: [ :prefixSize |
					 (self rankDistributionForPrefixSize: prefixSize) at: rank ]) ].
	^ table
]

{ #category : 'metrics' }
CooStaticBenchmarks >> recallAtK: k withPrefixSize: prefixSize [
	"Return the fraction (0..1) of callsites whose correct selector appears in the top k for the given prefix size."
	"If k > 10, we'll just take the top-10 maximum, since we only store up to 10 anyway."

	| effectiveK |
	effectiveK := k min: 10.

	^ self
		  accuracyForCompletionIndex: (1 to: effectiveK)
		  withPrefixSize: prefixSize
]

{ #category : 'inspector' }
CooStaticBenchmarks >> recallInspectionResults: aBuilder [
	"Displays recall@K metrics."
	
	<inspectorPresentationOrder: 7 title: 'Recall@K Results'>
	| table kValues |
	kValues := #( 1 3 5 10 ).
	table := SpTablePresenter new
		         addColumn:
			         (SpStringTableColumn
				          title: 'K'
				          evaluated: [ :k | k asString ]);
		         yourself.
	self prefixSizes do: [ :prefixSize |
		table addColumn: (SpStringTableColumn
				 title: 'Prefix ' , prefixSize asString
				 evaluated: [ :k |
					 ((self recallAtK: k withPrefixSize: prefixSize) * 100 asFloat
						  round: 2) asString ]) ].
	table items: kValues.
	^ table
]

{ #category : 'running' }
CooStaticBenchmarks >> run [

	self subclassResponsibility
]

{ #category : 'accessing' }
CooStaticBenchmarks >> scope [

	^ scope
]

{ #category : 'accessing' }
CooStaticBenchmarks >> scope: aClass [

	scope := aClass
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> score [

	^ ((1 to: 7) sum: [ :i | (self gradeForPrefixSize: i + 1) / i ]) * 100 / ((1 to: 7) sum: [ :index | 1/index ])
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> startMemoryMeasurement [

	self subclassResponsibility
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> startTimeMeasurement [

	self subclassResponsibility
]

{ #category : 'accessing' }
CooStaticBenchmarks >> textReport [
    "Return a plain text report with the main metrics for this benchmark instance."

    | prefixSizes kValues |
    prefixSizes := self prefixSizes.
    kValues := #(1 3 5 10).

    ^ String streamContents: [ :stream |

        stream
            nextPutAll: 'Name: ';
            nextPutAll: self name;
            cr.

        (builder respondsTo: #sorterClass) ifTrue: [
            stream
                nextPutAll: 'Sorter: ';
                nextPutAll: builder sorterClass name;
                cr ].

        stream
            nextPutAll: 'Scope: ';
            print: scope;
            cr;
            cr.

        "Accuracy"
        stream
            nextPutAll: 'Accuracy (%)';
            cr;
            nextPutAll: 'Row'.

        prefixSizes do: [ :prefixSize |
            stream
                nextPutAll: ' | ';
                nextPutAll: prefixSize asString ].
        stream cr.

        self completionIndexes do: [ :completionIndexRange |
            stream nextPutAll:
                (self completionIndexLabelFor: completionIndexRange).

            prefixSizes do: [ :prefixSize |
                | percentage |
                percentage :=
                    (self
                        accuracyForCompletionIndex: completionIndexRange
                        withPrefixSize: prefixSize) * 100.

                stream
                    nextPutAll: ' | ';
                    nextPutAll: (percentage asFloat round: 2) asString ].
            stream cr ].

        stream cr.

        "Time"
        stream
            nextPutAll: 'Time (ms)';
            cr;
            nextPutAll: 'Prefix | Total | Count | Average';
            cr.

        prefixSizes do: [ :prefixSize |
            | timeStats |
            timeStats := completionTimes at: prefixSize ifAbsent: [ #(0 0) ].

            stream
                nextPutAll: prefixSize asString;
                nextPutAll: ' | ';
                nextPutAll: (self totalTimeForPrefix: prefixSize) asString;
                nextPutAll: ' | ';
                nextPutAll: timeStats second asString;
                nextPutAll: ' | ';
                nextPutAll:
                    ((self averageTimeForPrefix: prefixSize) asFloat round: 2)
                        asString;
                cr ].

        stream cr.

        "Memory"
        stream
            nextPutAll: 'Memory Usage';
            cr;
            nextPutAll: 'Prefix | Total (bytes) | Average (bytes) | Total (MB)';
            cr.

        prefixSizes do: [ :prefixSize |
            | total average |
            total := self totalMemoryForPrefix: prefixSize.
            average := self averageMemoryForPrefix: prefixSize.

            stream
                nextPutAll: prefixSize asString;
                nextPutAll: ' | ';
                nextPutAll: total asString;
                nextPutAll: ' | ';
                nextPutAll: (average asFloat round: 2) asString;
                nextPutAll: ' | ';
                nextPutAll: ((total / 1024 / 1024) asFloat round: 2) asString;
                cr ].

        stream cr.

        "MMR"
        stream
            nextPutAll: 'MMR';
            cr;
            nextPutAll: 'Prefix | Mean Reciprocal Rank';
            cr.

        prefixSizes do: [ :prefixSize |
            stream
                nextPutAll: prefixSize asString;
                nextPutAll: ' | ';
                nextPutAll:
                    ((self mmrForPrefixSize: prefixSize) asFloat round: 2)
                        asString;
                cr ].

        stream cr.

        "NDCG"
        stream
            nextPutAll: 'NDCG';
            cr;
            nextPutAll: 'Prefix | NDCG';
            cr.

        prefixSizes do: [ :prefixSize |
            stream
                nextPutAll: prefixSize asString;
                nextPutAll: ' | ';
                nextPutAll:
                    ((self ndcgForPrefixSize: prefixSize) asFloat round: 2)
                        asString;
                cr ].

        stream cr.

        "Rank Distribution"
        stream
            nextPutAll:
                'Rank Distribution (correct result count per rank)';
            cr;
            nextPutAll:
                'Prefix | Rank1 | Rank2 | Rank3 | Rank4 | Rank5 | Rank6 | Rank7 | Rank8 | Rank9 | Rank10';
            cr.

        prefixSizes do: [ :prefixSize |
            stream nextPutAll: prefixSize asString.
            (self rankDistributionForPrefixSize: prefixSize) do: [ :rankCount |
                stream
                    nextPutAll: ' | ';
                    nextPutAll: rankCount asString ].
            stream cr ].

        stream cr.

        "Recall@K"
        stream
            nextPutAll: 'Recall@K (%)';
            cr;
            nextPutAll: 'K'.

        prefixSizes do: [ :prefixSize |
            stream
                nextPutAll: ' | Prefix ';
                nextPutAll: prefixSize asString ].
        stream cr.

        kValues do: [ :k |
            stream nextPutAll: k asString.
            prefixSizes do: [ :prefixSize |
                stream
                    nextPutAll: ' | ';
                    nextPutAll:
                        (((self recallAtK: k withPrefixSize: prefixSize) * 100)
                            asFloat round: 2) asString ].
            stream cr ]
    ]

]

{ #category : 'inspector' }
CooStaticBenchmarks >> timeInspectionResults: aBuilder [
	"Generates a table displaying time-based benchmark results."

	<inspectorPresentationOrder: 1 title: 'Time Results'>
	| table |
	table := SpTablePresenter new
		         items: self prefixSizes;
		         addColumn: (SpStringTableColumn
				          title: 'Prefix'
				          evaluated: [ :prefixSize | prefixSize asString ]);
		         addColumn: (SpStringTableColumn
				          title: 'Total (ms)'
				          evaluated: [ :prefixSize |
					          (self totalTimeForPrefix: prefixSize) asString ]);
		         addColumn:
			         (SpStringTableColumn
				          title: 'Count'
				          evaluated: [ :prefixSize |
					          (completionTimes at: prefixSize ifAbsent: [ #( 0 0 ) ])
						          second asString ]);
		         addColumn:
			         (SpStringTableColumn
				          title: 'Average (ms)'
				          evaluated: [ :prefixSize |
					          (self averageTimeForPrefix: prefixSize) asFloat round:
							          2 ]);
		         yourself.

	^ table
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> totalEntriesPerPrefixSize: aPrefixSize [

	^ completionBenchs sum: [ :benchsPerPrefix |  (benchsPerPrefix at: aPrefixSize ifAbsent: [ {0} ]) first ]
]

{ #category : 'metrics' }
CooStaticBenchmarks >> totalMemoryForPrefix: prefixSize [
	"The accumulated total memory usage in bytes"

	| stats |
	stats := memoryUsages at: prefixSize ifAbsent: [ #( 0 0 ) ].
	^ stats first
]

{ #category : 'metrics' }
CooStaticBenchmarks >> totalTime [
	"Returns the total execution time for all benchmarks."

	^ completionTimes values
		  inject: 0
		  into: [ :sum :timeArray | sum + timeArray first ]
]

{ #category : 'metrics' }
CooStaticBenchmarks >> totalTimeForPrefix: prefixSize [

    | times |
    times := completionTimes at: prefixSize ifAbsent: [ #( 0 0 ) ].
    ^ times first
]

{ #category : 'inspector' }
CooStaticBenchmarks >> totalTimeInspectionResults: aBuilder [

	<inspectorPresentationOrder: 2 title: 'Total Time'>
	^ self totalTime asPresenter
]

{ #category : 'benchmarks' }
CooStaticBenchmarks >> trackCompletionResultsFor: receiver atIndex: completionIndex withPrefix: prefix [
	
	"Track completion accuracy."
	self subclassResponsibility
]
