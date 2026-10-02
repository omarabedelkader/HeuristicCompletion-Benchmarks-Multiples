"
```
StObjectTranscriptLogger reset.

StObjectTranscriptLogger new
		runDuring: [ 
	CooStaticBenchmarksMessage  new
    scope: (CoBenchmarkPackage on: CompletionSorter package);
    builder: CoASTHeuristicsResultSetBuilder new;
    run.
].

StObjectTranscriptLogger instance.
 
StObjectTranscriptPresenter openWithLogger: StObjectTranscriptLogger instance.
```
"
Class {
	#name : 'CooProbe',
	#superclass : 'Object',
	#instVars : [
		'originalSelector',
		'prefix'
	],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Results',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Results'
}

{ #category : 'accessing' }
CooProbe >> originalSelector: aString [ 
	originalSelector := aString
]

{ #category : 'accessing' }
CooProbe >> prefix [
	^ prefix
]

{ #category : 'accessing' }
CooProbe >> prefix: aString [ 
	prefix := aString
]

{ #category : 'printing' }
CooProbe >> printOn: aStream [

	super printOn: aStream. 
	aStream space ; nextPutAll: prefix ; space ; nextPutAll: originalSelector 
	
]
