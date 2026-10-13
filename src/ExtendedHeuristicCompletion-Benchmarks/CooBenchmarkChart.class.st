"
Publication tables and memory/latency scatter plot from retained runs.
Across packages and prefixes, MRR, memory and latency are weighted by observation count.
Missing observations are gaps, never fabricated zero scores.
"
Class {
	#name : 'CooBenchmarkChart',
	#superclass : 'Object',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Results',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Results'
}

{ #category : 'exporting' }
CooBenchmarkChart class >> export: comparison to: directory [
	"Only publication artifacts. Everything is derived from retained results."
	| folder files table corpus form graph |
	table := self latexResultsTableFor: comparison.
	corpus := self latexCorpusSummaryFor: (comparison at: #corpus).
	form := self performanceFormFor: comparison.
	folder := directory asFileReference ensureCreateDirectory.
	files := OrderedCollection new.
	{ 'results-table.tex' -> table. 'dataset-summary.tex' -> corpus } do: [ :entry |
		| file |
		file := folder / entry key.
		file writeStreamDo: [ :out | out truncate; nextPutAll: entry value ].
		files add: file ].
	graph := folder / 'performance.png'.
	PNGReadWriter putForm: form onFileNamed: graph fullName.
	^ { files first. graph. files second }
]

{ #category : 'data' }
CooBenchmarkChart class >> strategiesFor: runs [
	| keys ordered |
	keys := Set new.
	runs do: [ :run | keys addAll: run results keys ].
	ordered := OrderedCollection new.
	(self publicationStrategies , #(llmCompletion)) do: [ :key |
		(keys includes: key) ifTrue: [ ordered add: key. keys remove: key ] ].
	ordered addAll: keys asSortedCollection.
	^ ordered
]

{ #category : 'data' }
CooBenchmarkChart class >> valueFor: strategy prefix: prefix runs: runs [
	| count weighted |
	count := 0.
	weighted := 0.0.
	runs do: [ :run |
		(run results at: strategy ifAbsent: [ nil ]) ifNotNil: [ :benchmark |
			| n |
			n := benchmark totalEntriesPerPrefixSize: prefix.
			count := count + n.
			weighted := weighted + (n * (benchmark mmrForPrefixSize: prefix)) ] ].
	^ count = 0 ifTrue: [ nil ] ifFalse: [ weighted / count ]
]

{ #category : 'data' }
CooBenchmarkChart class >> labelFor: strategy [
	^ (Dictionary newFrom: {
		#heuristicsBaseline -> 'Baseline'.
		#heuristicsDependency -> 'Dependency'.
		#llmCompletion -> 'LLM (1 model token)'.
		#llm05B -> '0.5B-LLM Completion'.
		#llm15B -> '1.5B-LLM Completion'.
		#llm3B -> '3B-LLM Completion'.
		#llm7B -> '7B-LLM Completion'.
		#hybrid05B -> 'Hybrid Rerank + 0.5B'.
		#hybrid15B -> 'Hybrid Rerank + 1.5B'.
		#hybrid3B -> 'Hybrid Rerank + 3B'.
		#hybrid7B -> 'Hybrid Rerank + 7B'.
		#neuralRank10 -> 'NeuralRank-10'.
		#neuralRank20 -> 'NeuralRank-20'.
		#neuralRank30 -> 'NeuralRank-30'.
		#neuralRank50 -> 'NeuralRank-50'.
		#adaptiveRank05B -> 'AdaptiveRank + 0.5B' })
		at: strategy ifAbsent: [ strategy asString ]
]

{ #category : 'exporting' }
CooBenchmarkChart class >> csvFor: runs [
	^ String streamContents: [ :out |
		out nextPutAll: 'package,strategy,prefix,count,mrr'; lf.
		runs do: [ :run |
			(self strategiesFor: { run }) do: [ :strategy |
				| benchmark |
				benchmark := run results at: strategy.
				2 to: 8 do: [ :prefix |
					out nextPutAll: (self csvField: run package name); nextPut: $,;
						nextPutAll: (self csvField: strategy asString); nextPut: $,;
						print: prefix; nextPut: $,;
						print: (benchmark totalEntriesPerPrefixSize: prefix); nextPut: $,.
					(benchmark totalEntriesPerPrefixSize: prefix) > 0 ifTrue: [
						out print: (benchmark mmrForPrefixSize: prefix) asFloat ].
					out lf ] ] ] ]
]

{ #category : 'private' }
CooBenchmarkChart class >> csvField: aString [
	^ '"' , (aString copyReplaceAll: '"' with: '""') , '"'
]

{ #category : 'drawing' }
CooBenchmarkChart class >> formFor: runs title: title [
	| form canvas font strategies label labelForm |
	strategies := self strategiesFor: runs.
	form := Form extent: 900 @ (900 + (strategies size * 35)) depth: 32.
	form fillWhite.
	canvas := form getCanvas.
	font := LogicalFont familyName: StandardFonts defaultFont familyName pointSize: 18.
	self text: title at: 450 @ 25 on: canvas font: font.
	0 to: 5 do: [ :tick |
		| y |
		y := 740 - (tick * 130).
		canvas line: 130 @ y to: 820 @ y width: 1 color: Color lightGray.
		self text: (tick / 5.0 printShowingDecimalPlaces: 1)
			at: 95 @ (y - 12) on: canvas font: font ].
	2 to: 8 do: [ :prefix |
		| x |
		x := self xFor: prefix.
		canvas line: x @ 90 to: x @ 740 width: 1 color: Color lightGray.
		self text: prefix asString at: x @ 755 on: canvas font: font ].
	canvas frameRectangle: (130 @ 90 corner: 820 @ 740) width: 2 color: Color black.
	self text: 'Prefix Length' at: 475 @ 800 on: canvas font: font.
	label := 'Average MRR'.
	labelForm := Form extent: (font widthOfString: label) ceiling @ font height ceiling depth: 32.
	labelForm fillWhite.
	labelForm getCanvas drawString: label at: 0 @ 0 font: font color: Color black.
	canvas drawImage: (labelForm rotateBy: #left centerAt: 0 @ 0) at: 25 @ 330.
	strategies withIndexDo: [ :strategy :index |
		| previous y |
		previous := nil.
		2 to: 8 do: [ :prefix |
			| value point |
			value := self valueFor: strategy prefix: prefix runs: runs.
			value ifNil: [ previous := nil ] ifNotNil: [
				point := (self xFor: prefix) @ (740 - (value * 650)) rounded.
				previous ifNotNil: [ canvas line: previous to: point width: 2 color: Color black ].
				self marker: index at: point on: canvas.
				previous := point ] ].
		y := 880 + ((index - 1) * 35).
		canvas line: 260 @ y to: 300 @ y width: 2 color: Color black.
		self marker: index at: 280 @ y on: canvas.
		canvas drawString: (self labelFor: strategy) at: 315 @ (y - 13) font: font color: Color black ].
	self text: 'Strategy' at: 475 @ 840 on: canvas font: font.
	^ form
]

{ #category : 'drawing' }
CooBenchmarkChart class >> marker: index at: point on: canvas [
	| style |
	style := (index - 1) \\ 4.
	style = 0 ifTrue: [ ^ canvas fillRectangle: (point - (6 @ 6) extent: 12 @ 12) color: Color black ].
	style = 1 ifTrue: [ ^ canvas drawPolygon:
		{ point + (0 @ -8). point + (-7 @ 6). point + (7 @ 6) }
		color: Color black borderWidth: 1 borderColor: Color black ].
	style = 2 ifTrue: [ ^ canvas fillOval: (point - (6 @ 6) extent: 12 @ 12) color: Color black ].
	canvas line: point - (6 @ 6) to: point + (6 @ 6) width: 2 color: Color black.
	canvas line: point + (-6 @ 6) to: point + (6 @ -6) width: 2 color: Color black
]

{ #category : 'private' }
CooBenchmarkChart class >> xFor: prefix [
	^ 175 + ((prefix - 2) * 100)
]

{ #category : 'private' }
CooBenchmarkChart class >> text: text at: centerTop on: canvas font: font [
	canvas drawString: text
		at: (centerTop x - ((font widthOfString: text) / 2)) rounded @ centerTop y
		font: font color: Color black
]

{ #category : 'data' }
CooBenchmarkChart class >> publicationStrategies [
	^ #(heuristicsBaseline heuristicsDependency llm05B llm15B llm3B llm7B
		hybrid05B hybrid15B hybrid3B hybrid7B)
]

{ #category : 'data' }
CooBenchmarkChart class >> averageMrrFor: strategy runs: runs [
	| count weighted |
	count := 0.
	weighted := 0.0.
	runs do: [ :run |
		(run results at: strategy ifAbsent: [ nil ]) ifNotNil: [ :benchmark |
			2 to: 8 do: [ :prefix |
				| n |
				n := benchmark totalEntriesPerPrefixSize: prefix.
				n > 0 ifTrue: [
					count := count + n.
					weighted := weighted + (n * (benchmark mmrForPrefixSize: prefix)) ] ] ] ].
	^ count = 0 ifTrue: [ nil ] ifFalse: [ weighted / count ]
]

{ #category : 'data' }
CooBenchmarkChart class >> performancePointFor: strategy runs: runs [
	| count totalTime totalMemory weighted |
	count := 0.
	totalTime := 0.0.
	totalMemory := 0.0.
	weighted := 0.0.
	runs do: [ :run |
		(run results at: strategy ifAbsent: [ nil ]) ifNotNil: [ :benchmark |
			2 to: 8 do: [ :prefix |
				| n |
				n := benchmark totalEntriesPerPrefixSize: prefix.
				n > 0 ifTrue: [
					count := count + n.
					totalTime := totalTime + (benchmark totalTimeForPrefix: prefix).
					totalMemory := totalMemory + (benchmark totalMemoryForPrefix: prefix).
					weighted := weighted + (n * (benchmark mmrForPrefixSize: prefix)) ] ] ] ].
	^ Dictionary new
		at: #strategy put: strategy;
		at: #performance put: (count = 0 ifTrue: [ nil ] ifFalse: [ weighted / count ]);
		at: #memoryMB put: (count = 0 ifTrue: [ nil ] ifFalse: [ totalMemory / count / 1000000.0 ]);
		at: #latencyMs put: (count = 0 ifTrue: [ nil ] ifFalse: [ totalTime / count ]);
		at: #count put: count;
		yourself
]

{ #category : 'data' }
CooBenchmarkChart class >> performancePointsFor: comparison [
	| points |
	points := OrderedCollection new.
	#(messages variables) do: [ :kind |
		(self publicationStrategiesFor: comparison) do: [ :strategy |
			| point |
			point := self performancePointFor: strategy runs: (comparison at: kind) first.
			(point at: #count) > 0 ifTrue: [
				point at: #kind put: kind.
				points add: point ] ] ].
	^ points
]

{ #category : 'exporting' }
CooBenchmarkChart class >> latexResultsTableFor: comparison [
	| strategies |
	strategies := self publicationStrategiesFor: comparison.
	^ String streamContents: [ :out |
		out nextPutAll: '\begin{table}[ht]'; lf;
			nextPutAll: '\centering'; lf;
			nextPutAll: '\caption{Completion performance by strategy and prefix length.}'; lf;
			nextPutAll: '\renewcommand{\arraystretch}{1.3}'; lf;
			nextPutAll: '\begin{tabular}{|c|l|c|c|c|c|c|c|c|c|}'; lf;
			nextPutAll: '\hline'; lf;
			nextPutAll: '\textbf{} & \textbf{Strategy} & \textbf{Average}'.
		2 to: 8 do: [ :prefix | out nextPutAll: ' & \textbf{'; print: prefix; nextPutAll: '}' ].
		out nextPutAll: ' \\'; lf; nextPutAll: '\hline'; lf.
		#(messages variables) do: [ :kind |
			| runs |
			runs := (comparison at: kind) first.
			out nextPutAll: '\multirow{'; print: strategies size;
				nextPutAll: '}{*}{\textbf{';
				nextPutAll: (self labelForKind: kind); nextPutAll: '}}'; lf.
			strategies withIndexDo: [ :strategy :index |
				out nextPutAll: '& '; nextPutAll: (self labelFor: strategy);
					nextPutAll: ' & '; nextPutAll: (self formattedMrr: (self averageMrrFor: strategy runs: runs)).
				2 to: 8 do: [ :prefix |
					out nextPutAll: ' & '; nextPutAll:
						(self formattedMrr: (self valueFor: strategy prefix: prefix runs: runs)) ].
				out nextPutAll: ' \\'.
				index < strategies size ifTrue: [ out nextPutAll: ' \cline{2-10}' ].
				out lf ].
			out nextPutAll: '\hline'; lf ].
		out nextPutAll: '\end{tabular}'; lf; nextPutAll: '\end{table}'; lf ]
]

{ #category : 'exporting' }
CooBenchmarkChart class >> latexCorpusSummaryFor: corpus [
	^ String streamContents: [ :out |
		out nextPutAll: '\begin{table}[ht]'; lf;
			nextPutAll: '\centering'; lf;
			nextPutAll: '\caption{Analyzed benchmark corpus.}'; lf;
			nextPutAll: '\begin{tabular}{|l|r|}'; lf;
			nextPutAll: '\hline'; lf;
			nextPutAll: '\textbf{Entity} & \textbf{Count} \\'; lf;
			nextPutAll: '\hline'; lf.
		#(packages classes methods) do: [ :entity |
			out nextPutAll: entity asString capitalized; nextPutAll: ' & ';
				print: (corpus at: entity); nextPutAll: ' \\'; lf ].
		out nextPutAll: '\hline'; lf; nextPutAll: '\end{tabular}'; lf;
			nextPutAll: '\end{table}'; lf ]
]

{ #category : 'private' }
CooBenchmarkChart class >> formattedMrr: value [
	^ value ifNil: [ '--' ] ifNotNil: [ value asFloat printShowingDecimalPlaces: 3 ]
]

{ #category : 'private' }
CooBenchmarkChart class >> labelForKind: kind [
	^ kind = #messages ifTrue: [ 'Methods' ] ifFalse: [ 'Classes' ]
]

{ #category : 'drawing' }
CooBenchmarkChart class >> performanceFormFor: comparison [
	| form canvas font points maximum memoryRange memorySpan memoryDecimals label labelForm strategies extraHeight |
	strategies := self publicationStrategiesFor: comparison.
	extraHeight := (((strategies size + 1) // 2) - 5 max: 0) * 40.
	points := self performancePointsFor: comparison.
	memoryRange := self memoryRangeFor: points.
	memorySpan := memoryRange second - memoryRange first.
	memoryDecimals := memorySpan < 0.01 ifTrue: [ 6 ] ifFalse: [ 3 ].
	maximum := 1.0.
	points do: [ :point | maximum := maximum max: (point at: #latencyMs) * 1.1 ].
	form := Form extent: 1200 @ (1150 + extraHeight) depth: 32.
	form fillWhite.
	canvas := form getCanvas.
	font := LogicalFont familyName: StandardFonts defaultFont familyName pointSize: 18.
	self text: 'Completion memory usage and latency' at: 660 @ 25 on: canvas font: font.
	0 to: 5 do: [ :tick |
		| x y |
		x := 170 + (tick * 196).
		y := 730 - (tick * 124).
		canvas line: x @ 110 to: x @ 730 width: 1 color: Color lightGray.
		canvas line: 170 @ y to: 1150 @ y width: 1 color: Color lightGray.
		self text: (memoryRange first + (memorySpan * tick / 5.0) printShowingDecimalPlaces: memoryDecimals)
			at: x @ 745 on: canvas font: font.
		self text: (maximum * tick / 5.0 printShowingDecimalPlaces: 1)
			at: 110 @ (y - 12) on: canvas font: font ].
	canvas frameRectangle: (170 @ 110 corner: 1150 @ 730) width: 2 color: Color black.
	self text: 'Mean Pharo memory change per completion (MB)' at: 660 @ 790 on: canvas font: font.
	label := 'Mean completion latency (ms)'.
	labelForm := Form extent: (font widthOfString: label) ceiling @ font height ceiling depth: 32.
	labelForm fillWhite.
	labelForm getCanvas drawString: label at: 0 @ 0 font: font color: Color black.
	canvas drawImage: (labelForm rotateBy: #left centerAt: 0 @ 0) at: 20 @ 150.
	points do: [ :point |
		self performanceMarkerFor: (point at: #kind)
			at: ((170 + (((point at: #memoryMB) - memoryRange first) / memorySpan * 980)) @
				(730 - ((point at: #latencyMs) / maximum * 620))) rounded
			color: (self colorFor: (point at: #strategy)) on: canvas ].
	strategies withIndexDo: [ :strategy :index |
		| x y |
		x := 100 + (((index - 1) \\ 2) * 570).
		y := 855 + (((index - 1) // 2) * 40).
		canvas fillRectangle: (x @ y extent: 18 @ 18) color: (self colorFor: strategy).
		canvas drawString: (self labelFor: strategy) at: (x + 28) @ (y - 5) font: font color: Color black ].
	#(messages variables) withIndexDo: [ :kind :index |
		| x |
		x := 400 + ((index - 1) * 320).
		self performanceMarkerFor: kind at: x @ (1098 + extraHeight) color: Color black on: canvas.
		canvas drawString: (self labelForKind: kind) at: (x + 22) @ (1084 + extraHeight) font: font color: Color black ].
	points ifEmpty: [ self text: 'No completion observations' at: 660 @ 410 on: canvas font: font ].
	^ form
]

{ #category : 'drawing' }
CooBenchmarkChart class >> colorFor: strategy [
	^ { Color black. Color gray. Color blue. Color orange. Color green darker. Color magenta darker.
		Color red. Color cyan darker. Color brown. Color purple.
		Color blue darker. Color orange darker. Color green. Color magenta. Color cyan }
		at: ((self publicationStrategies , self rankingStrategies) indexOf: strategy)
]

{ #category : 'drawing' }
CooBenchmarkChart class >> performanceMarkerFor: kind at: point color: color on: canvas [
	kind = #messages ifTrue: [
		^ canvas fillOval: (point - (8 @ 8) extent: 16 @ 16) color: color ].
	canvas drawPolygon: { point + (0 @ -11). point + (-10 @ 8). point + (10 @ 8) }
		color: Color white borderWidth: 3 borderColor: color
]

{ #category : 'data' }
CooBenchmarkChart class >> memoryRangeFor: points [
	"VM memory deltas may be zero or negative. Preserve them and include zero."
	| minimum maximum |
	minimum := 0.0.
	maximum := 0.0.
	points do: [ :point |
		minimum := minimum min: (point at: #memoryMB).
		maximum := maximum max: (point at: #memoryMB) ].
	minimum = maximum ifTrue: [ ^ { 0.0. 1.0 } ].
	^ { minimum * 1.1. maximum * 1.1 }
]

{ #category : 'data' }
CooBenchmarkChart class >> accuracyAt: k for: strategy runs: runs [
	| count hits |
	(#(1 3 10) includes: k) ifFalse: [ self error: 'Expected k = 1, 3 or 10' ].
	count := 0.
	hits := 0.
	runs do: [ :run |
		(run results at: strategy ifAbsent: [ nil ]) ifNotNil: [ :benchmark |
			2 to: 8 do: [ :prefix |
				| n |
				n := benchmark totalEntriesPerPrefixSize: prefix.
				n > 0 ifTrue: [
					count := count + n.
					hits := hits + (n * (benchmark accuracyForCompletionIndex: (1 to: k) withPrefixSize: prefix)) ] ] ] ].
	^ count = 0 ifTrue: [ nil ] ifFalse: [ hits / count asFloat ]
]

{ #category : 'data' }
CooBenchmarkChart class >> hybridSummaryFor: strategy runs: runs [
	"Aggregate counts, never per-package percentages. No additional inference."
	| summary keys |
	keys := #(count errors requests promoted demoted unchanged heuristicMiss).
	summary := Dictionary new.
	keys do: [ :key | summary at: key put: 0 ].
	runs do: [ :run |
		(run results at: strategy ifAbsent: [ nil ]) ifNotNil: [ :benchmark |
			| diagnostic |
			diagnostic := benchmark diagnosticSummary.
			keys do: [ :key | summary at: key put: (summary at: key) + (diagnostic at: key) ] ] ].
	summary at: #meanRequests put: ((summary at: #count) = 0
		ifTrue: [ nil ] ifFalse: [ (summary at: #requests) / (summary at: #count) asFloat ]);
		at: #mrr put: (self averageMrrFor: strategy runs: runs);
		at: #accuracyAt1 put: (self accuracyAt: 1 for: strategy runs: runs);
		at: #accuracyAt3 put: (self accuracyAt: 3 for: strategy runs: runs);
		at: #accuracyAt10 put: (self accuracyAt: 10 for: strategy runs: runs).
	^ summary
]

{ #category : 'data' }
CooBenchmarkChart class >> rerankerStrategies [
	^ #(neuralRank10 neuralRank20 neuralRank30 neuralRank50)
]

{ #category : 'data' }
CooBenchmarkChart class >> rankingStrategies [
	^ #(neuralRank10 neuralRank20 neuralRank30 neuralRank50 adaptiveRank05B)
]

{ #category : 'data' }
CooBenchmarkChart class >> validatePublicationStrategies: strategies [
	(strategies isEmpty or: [ strategies asSet size ~= strategies size ]) ifTrue: [
		self error: 'Choose a nonempty list of distinct publication strategies' ].
	strategies do: [ :strategy |
		((self publicationStrategies , self rankingStrategies) includes: strategy) ifFalse: [
			self error: 'Unknown publication strategy: ', strategy asString ] ].
	^ strategies asArray
]

{ #category : 'data' }
CooBenchmarkChart class >> publicationStrategiesFor: comparison [
	"Old comparisons retain their exact layout. Append known ranking results
	when present, or honor an explicit validated row list. Never run inference."
	| present |
	(comparison includesKey: #publicationStrategies) ifTrue: [
		^ self validatePublicationStrategies: (comparison at: #publicationStrategies) ].
	present := Set new.
	#(messages variables) do: [ :kind |
		(comparison at: kind) first do: [ :run | present addAll: run results keys ] ].
	^ self publicationStrategies , (self rankingStrategies select: [ :key | present includes: key ])
]
