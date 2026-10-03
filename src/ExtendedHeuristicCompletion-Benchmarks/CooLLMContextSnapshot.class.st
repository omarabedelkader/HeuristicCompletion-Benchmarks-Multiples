"
A value snapshot at a simulated completion cursor. Never sends the held-out
target, the rest of the method, or another copy of the method to the model.
The suffix is deliberately empty: this benchmark models left-to-right typing.
"
Class {
	#name : 'CooLLMContextSnapshot',
	#superclass : 'Object',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'building' }
CooLLMContextSnapshot class >> for: aNode prefix: aPrefix kind: aKind [
	| method source start targetClass |
	method := aNode methodNode.
	source := method source.
	start := aNode isMessage
		ifTrue: [ aNode keywordsPositions first ]
		ifFalse: [ aNode start ].
	(start between: 1 and: source size) ifFalse: [
		self error: 'Completion node has no valid source position' ].
	targetClass := method methodClass.
	^ Dictionary new
		at: #contextPolicy put: 'prefix-only-structural-v1';
		at: #kind put: aKind;
		at: #className put: targetClass name;
		at: #methodSelector put: method selector asString;
		at: #sourceStart put: start;
		at: #prefix put: aPrefix copy;
		at: #sourcePrefix put: (self normalize: (source first: start - 1) , aPrefix);
		at: #suffix put: '';
		at: #context put: (self contextFor: targetClass);
		yourself
]

{ #category : 'building' }
CooLLMContextSnapshot class >> contextFor: aClass [
	"Structural context only. No method bodies, including the benchmarked method.
	Declarations and source before the cursor may naturally mention the target."
	^ String streamContents: [ :out |
		out nextPutAll: '<|repo_name|>'; nextPutAll: aClass name; lf;
			nextPutAll: '<|file_sep|>class-context'; lf;
			nextPutAll: '"Class: '; nextPutAll: aClass name.
		aClass superclass ifNotNil: [ :parent |
			out nextPutAll: ' Superclass: '; nextPutAll: parent name ].
		out nextPutAll: ' Instance variables: '.
		aClass allInstVarNames do: [ :each | out nextPutAll: each; space ].
		out nextPutAll: ' Class variables: '.
		aClass instanceSide allClassVarNames asSortedCollection do: [ :each |
			out nextPutAll: each; space ].
		out nextPut: $"; lf ]
]

{ #category : 'private' }
CooLLMContextSnapshot class >> normalize: aString [
	^ (aString copyReplaceAll: String crlf with: String lf)
		copyReplaceAll: String cr with: String lf
]
