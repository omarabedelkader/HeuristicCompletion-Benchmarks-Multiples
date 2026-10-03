"Usage: pharo --headless /path/to/disposable.image st --quit scripts/test.st
Run from the repository root. Loads local code without saving the image."
| source suite result |
source := FileLocator workingDirectory / 'src'.
#('ExtendedHeuristicCompletion-Benchmarks' 'ExtendedHeuristicCompletion-Benchmarks-Tests')
	do: [ :package | (TonelReader on: source fileName: package) snapshot install ].
suite := TestSuite named: 'Extended completion benchmarks'.
(PackageOrganizer default packageNamed: 'ExtendedHeuristicCompletion-Benchmarks-Tests')
	definedClasses do: [ :class |
		(class inheritsFrom: TestCase) ifTrue: [ suite addTest: class suite ] ].
result := suite run.
Stdio stdout nextPutAll: result printString; lf.
result failures do: [ :test | Stdio stdout nextPutAll: 'FAIL: ', test printString; lf ].
result errors do: [ :test |
	Stdio stdout nextPutAll: 'ERROR: ', test printString; lf.
	[ test debug ] on: Error do: [ :error |
		Stdio stdout nextPutAll: error description; lf.
		Stdio stdout nextPutAll: (String streamContents: [ :out | error signalerContext shortDebugStackOn: out ]) ] ].
result hasPassed ifFalse: [ Smalltalk exit: 1 ].
