"
Completes a typed prefix into at most ten real names, most probable first, by
beam search over the model's next-token log-probabilities.

Each beam is text generated after the typed prefix. A step asks the model for
its top tokens after prompt , beam text. A token is followed only while
prefix , text still begins a class name (or, for messages, an instance- or
class-side selector) of the image, so every candidate is a real name. Only the
beamWidth most probable texts survive a step. A name becomes a candidate when
the model ends it: the next characters cannot continue a name, or the token
prints nothing (an end marker). Its probability is
	P(rest of name) * P(name ends here)
summed over the token paths that spell it. Without the end factor a name would
never lose to its own extension (at: against at:put:).

The search stops when no beam is left, after maxSteps, or when ten candidates
are found and no beam can still beat the tenth. Fewer than ten real names may
be reachable. The vocabulary is the whole image; the target is never consulted.

With validating: false the image is not consulted during the search: any text
made of name characters is followed and answered, real name or not. #valid then
counts the answered candidates that are real names (all of them when
validating).
"
Class {
	#name : 'CooLLMBeamCompleter',
	#superclass : 'Object',
	#instVars : [ 'client', 'kind', 'beamWidth', 'topTokens', 'maxSteps', 'candidateCount', 'vocabulary', 'validating' ],
	#classInstVars : [ 'vocabularyOverride' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'vocabulary' }
CooLLMBeamCompleter class >> vocabularyOverride: aCollectionOrNil [
	"Tests only: replace the image vocabulary for completers the runner builds."
	vocabularyOverride := aCollectionOrNil
]

{ #category : 'vocabulary' }
CooLLMBeamCompleter class >> namesFor: kind [
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

{ #category : 'initialization' }
CooLLMBeamCompleter >> initialize [
	super initialize.
	kind := #messages.
	beamWidth := 10.
	topTokens := 20.
	maxSteps := 12.
	candidateCount := 10.
	validating := true
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> client: aClient [
	client := aClient
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> kind: aSymbol [
	kind := aSymbol.
	vocabulary := nil
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> beamWidth: anInteger [
	beamWidth := anInteger
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> topTokens: anInteger [
	"Ollama answers at most twenty alternatives per step."
	topTokens := anInteger
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> maxSteps: anInteger [
	maxSteps := anInteger
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> validating: aBoolean [
	"false: answer what the model generates, without checking it against the image."
	validating := aBoolean
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> candidateCount: anInteger [
	candidateCount := anInteger
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> vocabulary: names [
	"Real names by their first two characters, the shortest benchmarked prefix."
	vocabulary := Dictionary new.
	names do: [ :each |
		(vocabulary at: (each first: (2 min: each size)) ifAbsentPut: [ OrderedCollection new ]) add: each ]
]

{ #category : 'accessing' }
CooLLMBeamCompleter >> vocabulary [
	vocabulary ifNil: [ self vocabulary: (self class namesFor: kind) ].
	^ vocabulary
]

{ #category : 'completing' }
CooLLMBeamCompleter >> namesStartingWith: prefix [
	| names |
	names := prefix size < 2
		ifTrue: [ self vocabulary values flatCollect: [ :each | each ] ]
		ifFalse: [ self vocabulary at: (prefix first: 2) ifAbsent: [ #() ] ].
	^ names select: [ :each | each beginsWith: prefix ]
]

{ #category : 'completing' }
CooLLMBeamCompleter >> leadingNameOf: aString after: prefix [
	"The characters of a token that can continue the name: special characters
	for a binary selector, otherwise letters, digits, underscores and (for
	selectors) keyword colons."
	| binary end |
	binary := prefix notEmpty and: [ prefix first isSpecial ].
	end := aString findFirst: [ :each |
		(binary
			ifTrue: [ each isSpecial ]
			ifFalse: [ each isAlphaNumeric or: [ each = $_ or: [ kind = #messages and: [ each = $: ] ] ] ]) not ].
	^ end = 0 ifTrue: [ aString ] ifFalse: [ aString first: end - 1 ]
]

{ #category : 'completing' }
CooLLMBeamCompleter >> strongest: count of: probabilities [
	"The count most probable text -> probability associations, most probable first."
	| sorted |
	sorted := (probabilities associations asSortedCollection: [ :a :b |
		a value > b value or: [ a value = b value and: [ a key <= b key ] ] ]) asArray.
	^ sorted first: (count min: sorted size)
]

{ #category : 'completing' }
CooLLMBeamCompleter >> candidatesFor: snapshot [
	"Answer #candidates (most probable first), #scores (name -> log-probability),
	#valid (how many candidates are real names), #requests (the text appended
	for each request), #steps and #complete.
	Errors propagate: a failed request is not a miss."
	| prefix real pools beams finished requests steps ranked |
	prefix := snapshot at: #prefix.
	real := (self namesStartingWith: prefix) collect: [ :each | each allButFirst: prefix size ].
	pools := Dictionary new.
	pools at: '' put: real.
	beams := (validating and: [ real isEmpty ]) ifTrue: [ #() ] ifFalse: [ { '' -> 1.0 } ].
	finished := Dictionary new.
	requests := OrderedCollection new.
	steps := 0.
	[ beams notEmpty and: [ steps < maxSteps ] ] whileTrue: [
		| expansions nextPools tenth |
		steps := steps + 1.
		expansions := Dictionary new.
		nextPools := Dictionary new.
		beams do: [ :beam |
			| pool |
			pool := validating ifTrue: [ pools at: beam key ] ifFalse: [ #() ].
			requests add: beam key.
			((client topTokensFor: snapshot continuation: beam key count: topTokens) at: #tokens) do: [ :token |
				| probability name text |
				probability := beam value * token value exp.
				name := self leadingNameOf: token key after: prefix.
				text := beam key , name.
				probability > 0 ifTrue: [
					(token key isEmpty or: [ name size < token key size ])
						ifTrue: [ "The name ends inside this token."
							(validating not or: [ pool includes: text ]) ifTrue: [
								finished at: text put: (finished at: text ifAbsent: [ 0 ]) + probability ] ]
						ifFalse: [
							| continuing |
							continuing := pool select: [ :each | each beginsWith: text ].
							(validating not or: [ continuing notEmpty ]) ifTrue: [
								expansions at: text put: (expansions at: text ifAbsent: [ 0 ]) + probability.
								nextPools at: text put: continuing ] ] ] ] ].
		"A longer text is never more probable: drop beams that cannot reach the ten."
		tenth := finished size < candidateCount
			ifTrue: [ 0 ]
			ifFalse: [ (self strongest: candidateCount of: finished) last value ].
		beams := (self strongest: beamWidth of: expansions) select: [ :each | each value > tenth ].
		pools := nextPools ].
	ranked := self strongest: candidateCount of: finished.
	real := real asSet.
	^ Dictionary new
		at: #valid put: (ranked count: [ :each | real includes: each key ]);
		at: #request put: (client payloadFor: snapshot);
		at: #candidates put: (ranked collect: [ :each | prefix , each key ]);
		at: #scores put: (ranked collect: [ :each | prefix , each key -> each value ln ]) asDictionary;
		at: #requests put: requests asArray;
		at: #steps put: steps;
		at: #complete put: ranked size = candidateCount;
		yourself
]
