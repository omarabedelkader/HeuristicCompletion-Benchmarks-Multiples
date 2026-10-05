Class {
	#name : 'CooNeuralRankerClient',
	#superclass : 'Object',
	#instVars : [ 'baseUrl', 'timeout', 'transport' ],
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooNeuralRankerClient >> initialize [
	super initialize.
	baseUrl := 'http://127.0.0.1:8765'.
	timeout := 5
]

{ #category : 'ranking' }
CooNeuralRankerClient >> baseUrl: url [
	baseUrl := url withoutSuffix: '/'
]

{ #category : 'ranking' }
CooNeuralRankerClient >> timeout: seconds [
	timeout := seconds
]

{ #category : 'ranking' }
CooNeuralRankerClient >> transport: object [
	transport := object
]

{ #category : 'ranking' }
CooNeuralRankerClient >> rank: candidates context: context [
	| payload start encoded serializationMs response http transportMs decodeStart |
	start := Time microsecondClockValue.
	payload := context copy.
	payload at: 'candidates' put: (candidates collect: #asDictionary).
	encoded := STONJSON toString: payload.
	serializationMs := (Time microsecondClockValue - start) / 1000.0.
	start := Time microsecondClockValue.
	transport
		ifNotNil: [ response := transport postJsonAt: 'rank' body: payload.
			transportMs := (Time microsecondClockValue - start) / 1000.0 ]
		ifNil: [
			http := ZnClient new.
			[
				http url: baseUrl , '/rank'; timeout: timeout; numberOfRetries: 0;
					enforceHttpSuccess: true; entity: (ZnEntity json: encoded); post.
				transportMs := (Time microsecondClockValue - start) / 1000.0.
				decodeStart := Time microsecondClockValue.
				response := STONJSON fromString: http contents.
				serializationMs := serializationMs + ((Time microsecondClockValue - decodeStart) / 1000.0)
			] ensure: [ http close ] ].
	self validate: response candidates: candidates.
	response at: 'serializationMs' put: serializationMs;
		at: 'requestRoundTripMs' put: transportMs;
		at: 'transportAndServerOverheadMs' put:
			((transportMs - (response at: 'inference_ms') - (response at: 'feature_ms')) max: 0.0).
	^ response
]

{ #category : 'ranking' }
CooNeuralRankerClient >> validate: response candidates: candidates [
	| scores names sum previous |
	(response isKindOf: Dictionary) ifFalse: [ self error: 'Invalid ranker response' ].
	(response at: 'schema') = 'coo-ranking-v1' ifFalse: [ self error: 'Ranker schema mismatch' ].
	(response at: 'modelId') isString ifFalse: [ self error: 'Missing model identity' ].
	scores := response at: 'scores'.
	names := candidates collect: #name.
	(scores size = names size and: [ (scores collect: #first) asSet = names asSet ])
		ifFalse: [ self error: 'Ranker must return exactly the supplied candidates' ].
	sum := 0. previous := 1.0.
	scores do: [ :pair |
		(pair size = 2 and: [ pair second isNumber and: [
			pair second >= 0 and: [ pair second <= previous ] ] ])
			ifFalse: [ self error: 'Invalid or unsorted ranker probabilities' ].
		previous := pair second. sum := sum + pair second ].
	(scores notEmpty and: [ (sum - 1) abs > 0.00001 ]) ifTrue: [ self error: 'Probabilities must sum to one' ].
	#('inference_ms' 'feature_ms') do: [ :key |
		| value |
		value := response at: key.
		(value isNumber and: [ value >= 0 and: [ value < 1.0e12 ] ])
			ifFalse: [ self error: 'Invalid ranker timing' ] ]
]
