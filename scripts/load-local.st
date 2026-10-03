"Run in an image which already has the existing benchmark prerequisites.
Start Pharo with the repository as working directory. No image is saved."
| source |
source := FileLocator workingDirectory / 'src'.
#('ExtendedHeuristicCompletion-Benchmarks' 'ExtendedHeuristicCompletion-Benchmarks-Tests')
	do: [ :package | (TonelReader on: source fileName: package) snapshot install ].
