Class {
	#name : 'CooBenchmarkSplitTest',
	#superclass : 'TestCase',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Tests',
	#package : 'ExtendedHeuristicCompletion-Benchmarks-Tests'
}

{ #category : 'helpers' }
CooBenchmarkSplitTest >> split [
	^ CooBenchmarkSplit benchmarkPackages: 2
		from: #('Collections-Core' 'Collections-Tests' 'Kernel' 'Tools' 'AST' 'Tests') seed: 42
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testExactCountAndAllRemainingPackages [
	| split |
	split := self split.
	self assert: split benchmarkPackageNames size equals: 2.
	self assert: split trainingPackageNames size equals: 4.
	self assert: (split benchmarkPackageNames asSet intersection: split trainingPackageNames asSet) isEmpty.
	self assert: (split benchmarkPackageNames asSet union: split trainingPackageNames asSet)
		equals: (split asDictionary at: 'eligible') asSet
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testSelectionIndependentOfPackageEnumeration [
	| other |
	other := CooBenchmarkSplit benchmarkPackages: 2
		from: (self split asDictionary at: 'eligible') reversed seed: 42.
	self assert: other asDictionary equals: self split asDictionary
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testRejectsInvalidCountsAndEmptyTrainingPool [
	#(0 -1 1.5 6 7) do: [ :count |
		self should: [ CooBenchmarkSplit benchmarkPackages: count
			from: (self split asDictionary at: 'eligible') seed: 42 ] raise: Error ]
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testRejectsBenchmarkLeakage [
	| dictionary |
	dictionary := self split asDictionary.
	dictionary at: 'train' put: (dictionary at: 'train'), { (dictionary at: 'benchmark') first }.
	self should: [ CooBenchmarkSplit fromDictionary: dictionary ] raise: Error
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testRejectsOmittedOrDuplicatePackages [
	| dictionary |
	dictionary := self split asDictionary.
	dictionary at: 'train' put: (dictionary at: 'train') allButFirst.
	self should: [ CooBenchmarkSplit fromDictionary: dictionary ] raise: Error.
	dictionary := self split asDictionary.
	dictionary at: 'benchmark' put: (dictionary at: 'benchmark'), { (dictionary at: 'benchmark') first }.
	self should: [ CooBenchmarkSplit fromDictionary: dictionary ] raise: Error
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testRejectsChangedImagePool [
	| split |
	split := self split.
	split validateAgainst: (split asDictionary at: 'eligible').
	self should: [ split validateAgainst: (split asDictionary at: 'eligible'), #('NewPackage') ] raise: Error.
	self should: [ split validateAgainst: (split asDictionary at: 'eligible') allButFirst ] raise: Error
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testAccessorsDoNotMutateSavedSelection [
	| split |
	split := self split.
	split benchmarkPackageNames at: 1 put: 'Changed'.
	(split asDictionary at: 'train') at: 1 put: 'Changed'.
	self assert: split asDictionary equals: self split asDictionary
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testJsonRoundTripAndNoOverwrite [
	| folder file split |
	folder := FileLocator temp / ('coo-split-', UUID new asString).
	file := folder / 'split.json'.
	[
		split := self split.
		split writeTo: file.
		self assert: (CooBenchmarkSplit readFrom: file) asDictionary equals: split asDictionary.
		self should: [ split writeTo: file ] raise: Error
	] ensure: [ folder ensureDeleteAll ]
]

{ #category : 'tests' }
CooBenchmarkSplitTest >> testRejectsWrongOrUntrackedModel [
	| client split metadata |
	client := CooNeuralRankerClient new.
	split := self split.
	metadata := Dictionary new at: 'packageSplit' put: split asDictionary; yourself.
	client validateMetadata: metadata split: split.
	self should: [ client validateMetadata: Dictionary new split: split ] raise: Error.
	(metadata at: 'packageSplit') at: 'seed' put: 100.
	self should: [ client validateMetadata: metadata split: split ] raise: Error
]
