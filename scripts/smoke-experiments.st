"Offline integration smoke: both kinds, two model identities, all ablations,
shared static results, JSONL/CSV/PNG exports. Uses deterministic fake responses.
Run only in a disposable image; never saves it or contacts Ollama."
| source fixture original transport matrix files |
source := FileLocator workingDirectory / 'src'.
#('ExtendedHeuristicCompletion-Benchmarks' 'ExtendedHeuristicCompletion-Benchmarks-Tests')
	do: [ :package | (TonelReader on: source fileName: package) snapshot install ].
fixture := (Object << #CooExperimentSmokeFixture) package: 'CooExperiment-Smoke'; install.
fixture compile: 'example | collection | collection := OrderedCollection new. ^ collection yourself'.
transport := (Smalltalk globals at: #CooLLMTestTransport) new responseBlock: [ :payload |
	Dictionary newFrom: {
		'response' -> ((payload includesKey: 'format')
			ifTrue: [ STONJSON toString: ((((payload at: 'format') at: 'items') at: 'enum') reversed) ]
			ifFalse: [ '' ]).
		'done' -> true. 'eval_count' -> 0.
		'total_duration' -> 100. 'load_duration' -> 10.
		'prompt_eval_duration' -> 30. 'eval_duration' -> 50.
		'prompt_eval_count' -> 10 } ]; yourself.
original := (Smalltalk globals at: #CooLLMClient) default.
[
	(Smalltalk globals at: #CooLLMClient) default: (original copy transport: transport; yourself).
	matrix := CooBenchRunner compareModels: #('offline:small' 'offline:large')
		messagesAndVariablesFor: #('CooExperiment-Smoke')
		strategies: #(llmCompletion hybridCompletion llmNameCompletion hybridNameCompletion
			rerankingCompletion neuralRerankingCompletion dependencyRerankingCompletion)
		latencyCondition: #warm.
	files := CooBenchRunner exportModels: matrix to: 'benchmark-smoke-results/experiments'.
	matrix valuesDo: [ :comparison |
		#(messages variables) do: [ :kind |
			| runner baseline |
			runner := (comparison at: kind) first first.
			baseline := runner results at: #heuristicsBaseline.
			runner results valuesDo: [ :benchmark |
				2 to: 8 do: [ :prefix |
					(benchmark totalEntriesPerPrefixSize: prefix) = (baseline totalEntriesPerPrefixSize: prefix)
						ifFalse: [ Error signal: 'Experiment populations differ' ] ] ] ] ].
	Stdio stdout print: files size; nextPutAll: ' integration artifacts exported'; lf
] ensure: [ (Smalltalk globals at: #CooLLMClient) default: original ].
