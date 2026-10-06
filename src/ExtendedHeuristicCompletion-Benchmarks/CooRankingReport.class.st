Class {
	#name : 'CooRankingReport',
	#superclass : 'Object',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Ranking',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Ranking'
}

{ #category : 'ranking' }
CooRankingReport class >> percentile: fraction values: values [
	values ifEmpty: [ ^ nil ].
	^ values sorted at: ((fraction * values size) ceiling max: 1)
]

{ #category : 'ranking' }
CooRankingReport class >> summaryFor: strategy runs: runs [
	| summary samples observations errors recall fallback |
	summary := CooBenchmarkChart performancePointFor: strategy runs: runs.
	samples := OrderedCollection new.
	observations := OrderedCollection new.
	errors := 0.
	runs do: [ :run | (run results at: strategy ifAbsent: [ nil ]) ifNotNil: [ :bench |
		samples addAll: bench latencySamples.
		(bench respondsTo: #records) ifTrue: [
			errors := errors + (bench records count: [ :row | row includesKey: #error ]) ].
		(bench isKindOf: CooNeuralRerankBenchmarks) ifTrue: [
			observations addAll: (bench records select: [ :row | row includesKey: #rank ]) ] ] ].
	summary at: #errors put: errors.
	#(1 3 10) do: [ :k |
		summary at: ('accuracyAt', k asString) asSymbol
			put: (CooBenchmarkChart accuracyAt: k for: strategy runs: runs) ].
	"Only report percentiles when all observations have raw samples."
	#(50 95 99) do: [ :p |
		summary at: ('p', p asString, 'Ms') asSymbol put:
			(samples size = (summary at: #count)
				ifTrue: [ self percentile: p / 100.0 values: samples ] ifFalse: [ nil ]) ].
	recall := Dictionary new.
	#(10 20 30 50) do: [ :k |
		recall at: k asString put: ((observations isEmpty or: [
			observations anySatisfy: [ :row | (row at: #candidateLimit) < k ] ])
			ifTrue: [ nil ] ifFalse: [
				(observations count: [ :row | (row at: #candidateRank) between: 1 and: k ]) / observations size asFloat ]) ].
	fallback := observations count: [ :row | row at: #fallbackCalled ifAbsent: [ false ] ].
	summary at: #candidateRecall put: recall;
		at: #fallbackCalls put: fallback;
		at: #fallbackRate put: (observations ifEmpty: [ nil ] ifNotEmpty: [ fallback / observations size asFloat ]).
	^ summary
]

{ #category : 'ranking' }
CooRankingReport class >> frontier: summaries [
	| valid |
	valid := summaries select: [ :row | (row at: #count) > 0 and: [ (row at: #errors ifAbsent: [ 0 ]) = 0 ] ].
	^ valid reject: [ :row | valid anySatisfy: [ :other |
		(other at: #performance) >= (row at: #performance) and: [
			(other at: #latencyMs) <= (row at: #latencyMs) and: [
				(other at: #performance) > (row at: #performance) or: [
					(other at: #latencyMs) < (row at: #latencyMs) ] ] ] ] ]
]

{ #category : 'ranking' }
CooRankingReport class >> bestIn: summaries p95Budget: budget memoryBudget: memoryMB [
	| feasible |
	feasible := summaries select: [ :row |
		(row at: #count) > 0 and: [ (row at: #errors ifAbsent: [ 0 ]) = 0 and: [
			(row at: #p95Ms) notNil and: [ (row at: #p95Ms) <= budget and: [
				memoryMB isNil or: [
					(row at: #processMemoryMB ifAbsent: [ nil ]) notNil and: [
						(row at: #processMemoryMB) <= memoryMB ] ] ] ] ] ] ].
	^ feasible ifEmpty: [ nil ] ifNotEmpty: [
		(feasible sorted: [ :a :b | (a at: #performance) > (b at: #performance) ]) first ]
]

{ #category : 'ranking' }
CooRankingReport class >> utilityFor: summary lambda: lambda [
	(summary at: #count) = 0 ifTrue: [ ^ nil ].
	^ (summary at: #performance) - (lambda * (1 + (summary at: #latencyMs)) ln)
]

{ #category : 'exporting' }
CooRankingReport class >> exportStrategies: strategies runs: runs to: path [
	| summaries file |
	summaries := strategies collect: [ :strategy | self summaryFor: strategy runs: runs ].
	file := path asFileReference.
	file writeStreamDo: [ :out | out truncate; nextPutAll: (STONJSON toString: summaries) ].
	^ file
]
