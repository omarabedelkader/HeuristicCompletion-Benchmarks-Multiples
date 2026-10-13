"
Synchronous benchmark-only Ollama client, following pharo-copilot's raw FIM
protocol. One request, at most one generated model token. generateFor: is
greedy (temperature 0, seed 42); a seeded sampled variant serves
CooLLMCandidateSampler, and topTokensFor:continuation:count: answers the
next-token log-probabilities that CooLLMBeamReranker searches. It does not change
Copilot settings, install models, retry failures or fall back to heuristics.
An optional transport implements postJsonAt:body: (e.g. CoPCOAHttpTransport).
"
Class {
	#name : 'CooLLMClient',
	#superclass : 'Object',
	#instVars : [ 'model', 'baseUrl', 'template', 'timeout', 'transport' ],
	#classInstVars : [ 'default' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-LLM',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'LLM'
}

{ #category : 'accessing' }
CooLLMClient class >> default [
	^ default ifNil: [ default := self new ]
]

{ #category : 'accessing' }
CooLLMClient class >> default: aClient [
	default := aClient
]

{ #category : 'initialization' }
CooLLMClient >> initialize [
	super initialize.
	model := 'pharo-llm/Qwen2.5-Coder-SFT:q4_K_M'.
	baseUrl := 'http://localhost:11434'.
	timeout := 120.
	template := '{{ .Context }}<|fim_prefix|>{{ .Prompt }}<|fim_suffix|>{{ .Suffix }}<|fim_middle|>'
]

{ #category : 'accessing' }
CooLLMClient >> model [
	^ model
]

{ #category : 'accessing' }
CooLLMClient >> model: aString [
	model := aString
]

{ #category : 'accessing' }
CooLLMClient >> baseUrl: aString [
	baseUrl := aString withoutSuffix: '/'
]

{ #category : 'accessing' }
CooLLMClient >> template [
	^ template
]

{ #category : 'accessing' }
CooLLMClient >> template: aString [
	(aString includesSubstring: '{{ .Prompt }}') ifFalse: [
		self error: 'FIM template must contain {{ .Prompt }}' ].
	template := aString
]

{ #category : 'accessing' }
CooLLMClient >> timeout: seconds [
	timeout := seconds
]

{ #category : 'accessing' }
CooLLMClient >> transport: anObject [
	transport := anObject
]

{ #category : 'configuration' }
CooLLMClient >> useCopilotConnection [
	"Explicitly opt into the existing Copilot connection, including remote auth."
	| settings transportClass |
	settings := Smalltalk globals at: #CopilotSettings ifAbsent: [
		self error: 'Load pharo-copilot before using its connection' ].
	transportClass := Smalltalk globals at: #CoPCOAHttpTransport.
	model := settings modelName.
	self template: settings fimTemplate.
	transport := transportClass new
]

{ #category : 'generation' }
CooLLMClient >> promptFor: snapshot [
	"Single-pass substitution: placeholders occurring in source are literal data."
	| replacements position marker prompt |
	replacements := Dictionary newFrom: {
		'{{ .Prompt }}' -> (snapshot at: #sourcePrefix).
		'{{ .Suffix }}' -> (snapshot at: #suffix).
		'{{ .Context }}' -> (snapshot at: #context) }.
	prompt := String streamContents: [ :out |
		position := 1.
		[ position <= template size ] whileTrue: [
			marker := replacements keys detect: [ :each |
				(template findString: each startingAt: position) = position ]
				ifNone: [ nil ].
			marker
				ifNil: [ out nextPut: (template at: position). position := position + 1 ]
				ifNotNil: [ out nextPutAll: (replacements at: marker).
					position := position + marker size ] ] ].
	(template includesSubstring: '{{ .Context }}') ifFalse: [
		prompt := (snapshot at: #context) , String lf , prompt ].
	^ CooLLMContextSnapshot normalize: prompt
]

{ #category : 'generation' }
CooLLMClient >> payloadFor: snapshot [
	^ self payloadFor: snapshot temperature: 0 seed: 42
]

{ #category : 'generation' }
CooLLMClient >> payloadFor: snapshot temperature: temperature seed: seed [
	^ Dictionary new
		at: 'model' put: model;
		at: 'prompt' put: (self promptFor: snapshot);
		at: 'raw' put: true;
		at: 'stream' put: false;
		at: 'keep_alive' put: '5m';
		at: 'options' put: (Dictionary newFrom: {
			'num_predict' -> 1. 'temperature' -> temperature. 'seed' -> seed.
			'num_ctx' -> 8192.
			'stop' -> #('<|endoftext|>' '<|fim_prefix|>' '<|fim_suffix|>' '<|fim_middle|>' '<|repo_name|>' '<|file_sep|>') });
		yourself
]

{ #category : 'generation' }
CooLLMClient >> generateFor: snapshot [
	^ self generateFor: snapshot temperature: 0 seed: 42
]

{ #category : 'generation' }
CooLLMClient >> generateFor: snapshot temperature: temperature seed: seed [
	| payload response |
	payload := self payloadFor: snapshot temperature: temperature seed: seed.
	response := self postPayload: payload.
	self validateResponse: response.
	^ Dictionary new
		at: #request put: payload;
		at: #response put: response;
		at: #template put: template copy;
		at: #content put: (response at: 'response');
		yourself
]

{ #category : 'generation' }
CooLLMClient >> topTokensFor: snapshot continuation: aString count: count [
	"One greedy step after prompt , aString. Answers the request and the
	count most likely next tokens as token -> log-probability associations."
	| payload response steps |
	payload := self payloadFor: snapshot.
	payload
		at: 'prompt' put: (payload at: 'prompt') , aString;
		at: 'logprobs' put: true;
		at: 'top_logprobs' put: count.
	response := self postPayload: payload.
	self validateResponse: response.
	steps := response at: 'logprobs' ifAbsent: [
		(response at: 'response') ifNotEmpty: [
			self error: 'Ollama did not return log-probabilities; upgrade the server' ].
		"Ollama drops log-probabilities when the chosen token prints nothing (an
		end-of-text or FIM marker). Only its rank is known: report a certain end."
		^ Dictionary new
			at: #request put: payload;
			at: #tokens put: { '' -> 0.0 };
			at: #endWithoutLogprobs put: true;
			yourself ].
	steps ifNil: [ steps := #() ].
	^ Dictionary new
		at: #request put: payload;
		at: #endWithoutLogprobs put: false;
		at: #tokens put: (steps
			ifEmpty: [ #() ]
			ifNotEmpty: [ (steps first at: 'top_logprobs') collect: [ :each |
				(each at: 'token') -> (each at: 'logprob') ] ]) asArray;
		yourself
]

{ #category : 'private' }
CooLLMClient >> postPayload: payload [
	| http |
	transport ifNotNil: [ ^ transport postJsonAt: 'api/generate' body: payload ].
	http := ZnClient new.
	^ [
		http url: baseUrl , '/api/generate';
			timeout: timeout;
			numberOfRetries: 0;
			enforceHttpSuccess: true;
			entity: (ZnEntity json: (STONJSON toString: payload));
			post.
		STONJSON fromString: http contents
	] ensure: [ http close ]
]

{ #category : 'private' }
CooLLMClient >> validateResponse: response [
	(response isKindOf: Dictionary) ifFalse: [ self error: 'Invalid Ollama response' ].
	(response includesKey: 'error') ifTrue: [ self error: (response at: 'error') asString ].
	((response at: 'done' ifAbsent: [ false ]) = true and: [
		(response at: 'response' ifAbsent: [ nil ]) isString ]) ifFalse: [
		self error: 'Ollama did not return a completed text response' ].
	(response at: 'eval_count' ifAbsent: [ 0 ]) > 1 ifTrue: [
		self error: 'Server violated the one-token generation limit' ]
]
