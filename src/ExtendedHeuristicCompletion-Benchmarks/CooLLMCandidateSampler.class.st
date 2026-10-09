"
Builds up to ten LM candidates for one prefix. Each attempt samples one model
token with its own seed; the candidate is the leading name of prefix + token.
Only distinct names that continue the prefix and exist in the image (class
names, or instance- and class-side selectors) are kept. At most twenty
attempts are made, so an unreachable prefix cannot loop forever.
The vocabulary is the whole image; the target is never consulted.
"
Class {
	#name : 'CooLLMCandidateSampler',
	#superclass : 'Object',
	#instVars : [ 'client', 'kind', 'vocabulary' ],
	#classInstVars : [ 'vocabularyOverride' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'configuration' }
CooLLMCandidateSampler class >> candidateCount [
	^ 10
]

{ #category : 'configuration' }
CooLLMCandidateSampler class >> maxAttempts [
	^ 20
]

{ #category : 'configuration' }
CooLLMCandidateSampler class >> temperature [
	^ 0.8
]

{ #category : 'configuration' }
CooLLMCandidateSampler class >> firstSeed [
	"Attempt n uses firstSeed + n - 1, so every run samples the same sequence."
	^ 42
]

{ #category : 'vocabulary' }
CooLLMCandidateSampler class >> vocabularyOverride: aSetOrNil [
	"Tests only: replace the image vocabulary for samplers the runner builds."
	vocabularyOverride := aSetOrNil
]

{ #category : 'vocabulary' }
CooLLMCandidateSampler class >> vocabularyFor: kind [
	| names |
	vocabularyOverride ifNotNil: [ ^ vocabularyOverride ].
	names := Set new.
	Smalltalk allClasses do: [ :class |
		kind = #variables
			ifTrue: [ names add: class name asString ]
			ifFalse: [ { class. class classSide } do: [ :behavior |
				behavior selectorsDo: [ :selector | names add: selector asString ] ] ] ].
	^ names
]

{ #category : 'extraction' }
CooLLMCandidateSampler class >> leadingNameIn: aString kind: kind [
	"Generated text is code. Keep the class name, unary or binary selector, or
	complete keyword parts (at:put:) it starts with; a trailing word without
	its colon is not part of a keyword selector."
	| stream word keywords |
	stream := aString readStream.
	kind = #variables ifTrue: [ ^ self identifierFrom: stream ].
	(aString notEmpty and: [ aString first isSpecial ]) ifTrue: [
		^ String streamContents: [ :out |
			[ stream atEnd not and: [ stream peek isSpecial ] ] whileTrue: [ out nextPut: stream next ] ] ].
	keywords := WriteStream on: String new.
	[ word := self identifierFrom: stream.
	  word notEmpty and: [ stream peek = $: ] ] whileTrue: [
		keywords nextPutAll: word; nextPut: stream next ].
	^ keywords contents ifEmpty: [ word ]
]

{ #category : 'extraction' }
CooLLMCandidateSampler class >> identifierFrom: aStream [
	^ String streamContents: [ :out |
		(aStream atEnd not and: [ aStream peek isLetter or: [ aStream peek = $_ ] ]) ifTrue: [
			[ aStream atEnd not and: [ aStream peek isAlphaNumeric or: [ aStream peek = $_ ] ] ]
				whileTrue: [ out nextPut: aStream next ] ] ]
]

{ #category : 'accessing' }
CooLLMCandidateSampler >> client: aClient [
	client := aClient
]

{ #category : 'accessing' }
CooLLMCandidateSampler >> kind: aSymbol [
	kind := aSymbol.
	vocabulary := nil
]

{ #category : 'accessing' }
CooLLMCandidateSampler >> vocabulary [
	^ vocabulary ifNil: [ vocabulary := self class vocabularyFor: kind ]
]

{ #category : 'accessing' }
CooLLMCandidateSampler >> vocabulary: aSet [
	vocabulary := aSet
]

{ #category : 'sampling' }
CooLLMCandidateSampler >> candidatesFor: snapshot [
	"Answer #candidates (in generation order), #attempts and #complete.
	Errors propagate: a failed request is not a rejected candidate."
	| prefix candidates attempts |
	prefix := snapshot at: #prefix.
	candidates := OrderedCollection new.
	attempts := OrderedCollection new.
	[ candidates size < self class candidateCount and: [ attempts size < self class maxAttempts ] ]
		whileTrue: [
			| seed generation name status |
			seed := self class firstSeed + attempts size.
			generation := client generateFor: snapshot temperature: self class temperature seed: seed.
			name := self class leadingNameIn: prefix , (generation at: #content) kind: kind.
			status := (name beginsWith: prefix) & (self vocabulary includes: name)
				ifTrue: [ (candidates includes: name) ifTrue: [ #duplicate ] ifFalse: [ #accepted ] ]
				ifFalse: [ #unknown ].
			status = #accepted ifTrue: [ candidates add: name ].
			attempts add: (Dictionary new
				at: #seed put: seed;
				at: #content put: (generation at: #content);
				at: #response put: (generation at: #response);
				at: #name put: name;
				at: #status put: status;
				yourself) ].
	^ Dictionary new
		at: #request put: (client payloadFor: snapshot temperature: self class temperature seed: self class firstSeed);
		at: #candidates put: candidates asArray;
		at: #attempts put: attempts asArray;
		at: #complete put: candidates size = self class candidateCount;
		yourself
]
