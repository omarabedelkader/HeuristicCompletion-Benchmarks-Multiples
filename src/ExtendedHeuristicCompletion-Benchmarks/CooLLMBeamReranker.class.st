"
Reorders a heuristic candidate list by the model's probability of each name,
found by beam search over next-token log-probabilities.

The prompt is the usual FIM snapshot whose context also lists the candidates.
Each beam is text generated after the typed prefix. A step asks the model for
its top tokens after prompt , beam text and keeps a token only while the text
still continues some unfinished candidate. Only the beamWidth best texts
survive a step. A candidate is finished, with score
	log P(rest of name) + log P(name ends here)
when a token completes it and continues with a non-name character (or the
model ends). Without the end factor a name would never lose to its own
extension (at: against at:put:). When the model lists no ending token, the
lowest listed log-probability bounds the unlisted ones. Ollama gives no
probabilities when its top token is an invisible end marker; that step counts
as a certain end and is reported in endsWithoutLogprobs.

The answer is a permutation of the input: finished names by score, then the
names the beam never reached in their original order. Nothing is added or
removed, so top-ten recall equals the heuristic's. The target is never seen.
"
Class {
	#name : 'CooLLMBeamReranker',
	#superclass : 'Object',
	#instVars : [ 'client', 'kind', 'beamWidth', 'topTokens', 'maxSteps' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Hybrid',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Hybrid'
}

{ #category : 'configuration' }
CooLLMBeamReranker class >> contextPolicy [
	^ 'fim-structural-v1+candidates'
]

{ #category : 'initialization' }
CooLLMBeamReranker >> initialize [
	super initialize.
	kind := #messages.
	beamWidth := 5.
	topTokens := 20.
	maxSteps := 12
]

{ #category : 'accessing' }
CooLLMBeamReranker >> client: aClient [
	client := aClient
]

{ #category : 'accessing' }
CooLLMBeamReranker >> kind: aSymbol [
	kind := aSymbol
]

{ #category : 'accessing' }
CooLLMBeamReranker >> beamWidth: anInteger [
	beamWidth := anInteger
]

{ #category : 'accessing' }
CooLLMBeamReranker >> topTokens: anInteger [
	"Ollama answers at most twenty alternatives per step."
	topTokens := anInteger
]

{ #category : 'accessing' }
CooLLMBeamReranker >> maxSteps: anInteger [
	maxSteps := anInteger
]

{ #category : 'prompting' }
CooLLMBeamReranker >> snapshot: snapshot listing: candidates [
	"Show the model the list next to the class context. Names cannot contain
	a double quote, so the comment cannot be closed early."
	^ snapshot copy
		at: #context put: (String streamContents: [ :out |
			out nextPutAll: (snapshot at: #context);
				nextPutAll: '"Completion candidates:'.
			candidates do: [ :each | out space; nextPutAll: each ].
			out nextPut: $"; lf ]);
		at: #contextPolicy put: self class contextPolicy;
		yourself
]

{ #category : 'scoring' }
CooLLMBeamReranker >> isNameCharacter: aCharacter after: aName [
	"A binary selector continues with special characters, any other name with
	letters, digits, underscores and (for selectors) keyword colons."
	(aName notEmpty and: [ aName first isSpecial ]) ifTrue: [ ^ aCharacter isSpecial ].
	^ aCharacter isAlphaNumeric or: [ aCharacter = $_ or: [ kind = #messages and: [ aCharacter = $: ] ] ]
]

{ #category : 'scoring' }
CooLLMBeamReranker >> endMassOf: remainder name: aName beam: beam tokens: tokens [
	"Probability, among the listed tokens, that the text after beam completes
	remainder and the name stops there. A token that merely reaches the end
	of remainder says nothing yet: the name could continue in the next one."
	| mass |
	(remainder beginsWith: beam key) ifFalse: [ ^ 0 ].
	mass := 0.
	tokens do: [ :token |
		| text |
		text := beam key , token key.
		((text beginsWith: remainder) and: [
			text size = remainder size
				ifTrue: [ token key isEmpty ]
				ifFalse: [ (self isNameCharacter: (text at: remainder size + 1) after: aName) not ] ])
			ifTrue: [ mass := mass + token value exp ] ].
	^ mass
]

{ #category : 'ranking' }
CooLLMBeamReranker >> rerank: candidates prefix: prefix snapshot: snapshot [
	| unique remainders prompt finished requests beams steps scored blindEnds |
	unique := OrderedCollection new.
	candidates do: [ :each | (unique includes: each) ifFalse: [ unique add: each ] ].
	unique := unique asArray.
	remainders := OrderedDictionary new.
	unique do: [ :each |
		(each beginsWith: prefix) ifTrue: [ remainders at: each put: (each allButFirst: prefix size) ] ].
	prompt := self snapshot: snapshot listing: unique.
	finished := Dictionary new.
	requests := OrderedCollection new.
	beams := remainders ifEmpty: [ #() ] ifNotEmpty: [ { '' -> 0 } ].
	steps := 0.
	blindEnds := 0.
	[ beams notEmpty and: [ steps < maxSteps ] ] whileTrue: [
		| expansions |
		steps := steps + 1.
		expansions := Dictionary new.
		beams do: [ :beam |
			| answer tokens |
			answer := client topTokensFor: prompt continuation: beam key count: topTokens.
			tokens := answer at: #tokens.
			(answer at: #endWithoutLogprobs ifAbsent: [ false ]) ifTrue: [ blindEnds := blindEnds + 1 ].
			requests add: beam key.
			self finish: beam tokens: tokens remainders: remainders into: finished.
			tokens do: [ :token |
				| text score |
				text := beam key , token key.
				score := beam value + token value.
				(token key notEmpty and: [
					remainders keys anySatisfy: [ :name |
						(finished includesKey: name) not and: [ (remainders at: name) beginsWith: text ] ] ])
					ifTrue: [ expansions at: text put: ((expansions at: text ifAbsent: [ score ]) max: score) ] ] ].
		beams := (expansions associations asSortedCollection: [ :a :b |
			a value > b value or: [ a value = b value and: [ a key <= b key ] ] ]) asArray.
		beams := beams first: (beamWidth min: beams size) ].
	scored := (unique select: [ :each | finished includesKey: each ]) withIndexCollect: [ :each :index |
		{ each. finished at: each. index } ].
	scored := scored asSortedCollection: [ :a :b |
		a second > b second or: [ a second = b second and: [ a third <= b third ] ] ].
	^ Dictionary new
		at: #ranking put: (scored asArray collect: #first) , (unique reject: [ :each | finished includesKey: each ]);
		at: #scores put: finished;
		at: #requests put: requests asArray;
		at: #steps put: steps;
		at: #endsWithoutLogprobs put: blindEnds;
		at: #contextPolicy put: self class contextPolicy;
		yourself
]

{ #category : 'ranking' }
CooLLMBeamReranker >> finish: beam tokens: tokens remainders: remainders into: finished [
	tokens ifEmpty: [ ^ self ].
	remainders keysAndValuesDo: [ :name :remainder |
		(finished includesKey: name) ifFalse: [
			| mass |
			mass := self endMassOf: remainder name: name beam: beam tokens: tokens.
			mass > 0
				ifTrue: [ finished at: name put: beam value + mass ln ]
				ifFalse: [ remainder = beam key ifTrue: [
					finished at: name put: beam value + (tokens inject: 0 into: [ :min :token | min min: token value ]) ] ] ] ]
]
