"
Dependency-free Pharo PNG export: MRR versus prefix length, separate plots for
messages and variables. Across packages, MRR is weighted by completion count.
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
	| folder files |
	folder := directory asFileReference ensureCreateDirectory.
	files := OrderedCollection new.
	#(messages variables) do: [ :kind |
		| result runs png csv |
		result := comparison at: kind.
		runs := result first.
		png := folder / (kind asString , '.png').
		PNGReadWriter putForm: (self formFor: runs title: kind asString capitalized)
			onFileNamed: png fullName.
		files add: png.
		csv := folder / (kind asString , '.csv').
		csv writeStreamDo: [ :out | out truncate; nextPutAll: (self csvFor: runs) ].
		files add: csv.
		(folder / (kind asString , '.txt')) writeStreamDo: [ :out |
			out truncate; nextPutAll: result second ].
		(folder / (kind asString , '.tex')) writeStreamDo: [ :out |
			out truncate; nextPutAll: result third ].
		runs withIndexDo: [ :run :index |
			(run results at: #llmCompletion ifAbsent: [ nil ]) ifNotNil: [ :llm |
				files add: (llm exportRecordsTo:
					(folder / (kind asString , '-' , index asString , '-llm.jsonl'))) ] ] ].
	^ files
]

{ #category : 'data' }
CooBenchmarkChart class >> strategiesFor: runs [
	| keys ordered |
	keys := Set new.
	runs do: [ :run | keys addAll: run results keys ].
	ordered := OrderedCollection new.
	#(heuristicsBaseline heuristicsDependency llmCompletion) do: [ :key |
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
		#llmCompletion -> 'LLM (1 model token)' })
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
