Class {
	#name : 'CooBenchmarkSplit',
	#superclass : 'Object',
	#instVars : [ 'data' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Benchmarks',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Benchmarks'
}

{ #category : 'instance creation' }
CooBenchmarkSplit class >> benchmarkPackages: count seed: seed [
	^ self benchmarkPackages: count from: CooBenchRunner eligiblePackageNames seed: seed
]

{ #category : 'instance creation' }
CooBenchmarkSplit class >> benchmarkPackages: count from: packageNames seed: seed [
	| eligible benchmark |
	seed isInteger ifFalse: [ self error: 'Selection seed must be an integer' ].
	eligible := packageNames asSet asSortedCollection asArray.
	benchmark := CooBenchRunner randomPackageNames: count from: eligible using: (Random seed: seed).
	^ self fromDictionary: (Dictionary new
		at: 'schema' put: 'coo-package-split-v1';
		at: 'seed' put: seed;
		at: 'eligible' put: eligible;
		at: 'benchmark' put: benchmark;
		at: 'train' put: (eligible reject: [ :name | benchmark includes: name ]);
		yourself)
]

{ #category : 'instance creation' }
CooBenchmarkSplit class >> fromDictionary: dictionary [
	^ self new data: dictionary; validate; yourself
]

{ #category : 'instance creation' }
CooBenchmarkSplit class >> readFrom: path [
	^ self fromDictionary: (STONJSON fromString: path asFileReference contents)
]

{ #category : 'private' }
CooBenchmarkSplit >> data: dictionary [
	data := dictionary deepCopy
]

{ #category : 'accessing' }
CooBenchmarkSplit >> asDictionary [
	^ data deepCopy
]

{ #category : 'accessing' }
CooBenchmarkSplit >> benchmarkPackageNames [
	^ (data at: 'benchmark') copy
]

{ #category : 'accessing' }
CooBenchmarkSplit >> trainingPackageNames [
	^ (data at: 'train') copy
]

{ #category : 'accessing' }
CooBenchmarkSplit >> seed [
	^ data at: 'seed'
]

{ #category : 'validation' }
CooBenchmarkSplit >> validate [
	| eligible benchmark train |
	(data at: 'schema') = 'coo-package-split-v1' ifFalse: [ self error: 'Unknown package split schema' ].
	(data at: 'seed') isInteger ifFalse: [ self error: 'Selection seed must be an integer' ].
	#('eligible' 'benchmark' 'train') do: [ :key |
		| names |
		names := data at: key.
		(names isArray and: [ names notEmpty and: [ names allSatisfy: [ :name |
			name isString and: [ name notEmpty ] ] ] ]) ifFalse: [
			self error: 'Each package partition must be a nonempty array of names' ].
		names asSet size = names size ifFalse: [ self error: 'Duplicate packages in split' ] ].
	eligible := (data at: 'eligible') asSet.
	benchmark := (data at: 'benchmark') asSet.
	train := (data at: 'train') asSet.
	(benchmark intersection: train) isEmpty ifFalse: [ self error: 'Benchmark packages must never enter training' ].
	(benchmark union: train) = eligible ifFalse: [ self error: 'Training must contain every remaining eligible package' ]
]

{ #category : 'validation' }
CooBenchmarkSplit >> validateAgainst: packageNames [
	self validate.
	(data at: 'eligible') asSet = packageNames asSet ifFalse: [
		self error: 'The image package pool changed; reuse the original image or create a new experiment' ]
]

{ #category : 'exporting' }
CooBenchmarkSplit >> writeTo: path [
	"A split is immutable on disk: a new selection needs a new file."
	| file |
	self validate.
	file := path asFileReference.
	file exists ifTrue: [ self error: 'Split file already exists; read and reuse it' ].
	file parent ensureCreateDirectory.
	file writeStreamDo: [ :out | out nextPutAll: (STONJSON toString: data); lf ].
	^ file
]
