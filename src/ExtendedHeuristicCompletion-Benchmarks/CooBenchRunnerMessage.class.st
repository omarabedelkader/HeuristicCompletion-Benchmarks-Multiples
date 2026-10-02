"
```smalltalk
runMessageOnNeCompletionPackage

	<script>
	^ (CooStaticBenchmarksMessage
		   runOnPackage:
		   (PackageOrganizer default packageNamed: 'NECompletion')
		   heuristics: [ :b | b ]) inspect
	
```



```smalltalk
CooBenchRunner new
   package: CompletionContextTest package;
   baseline: #WithoutPackageScope;
   others: { #WithOllamaReRank };
   run.

```
"
Class {
	#name : 'CooBenchRunnerMessage',
	#superclass : 'CooBenchRunner',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Benchmarks',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Benchmarks'
}

{ #category : 'examples' }
CooBenchRunnerMessage class >> iceberg [

	<script>
	^ (self allResultsFor:
		   { 'Iceberg'. 'Iceberg-ArchitecturalRules'.'Iceberg-Libgit'. 'Iceberg-Libgit-Filetree'.
		   'Iceberg-Libgit-Tonel'.'Iceberg-Memory'. 'Iceberg-Metacello-Integration'.'Iceberg-Playground-Plugin-Gist'.
		   'Iceberg-Plugin'. 'Iceberg-Plugin-Github'.'Iceberg-Plugin-Metacello'. 'Iceberg-Plugin-Migration'.
		   'Iceberg-Plugin-Pharo'. 'Iceberg-TipUI'. 'Iceberg-TipUI-SnapShotBrowser' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> icebergTest [

	<script>
	^ (self allResultsFor:
		   { 'Iceberg-Plugin-Migration-Tests'.
		   'Iceberg-Tests'. 'Iceberg-Tests-MetacelloIntegration' .'Iceberg-TipUI-SnapshotBrowser-Tests'. 'Iceberg-UI-Tests'}) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> moose [

	<script>
	^ (self allResultsFor: { 'Moose-Blueprint-Invocations-Models'.
		   'Moose-Blueprint-Models'. 'Moose-Blueprint-Visualization-Models'.
		   'Moose-Configuration'. 'Moose-Core'. 'Moose-Core-Generator'.
		   'Moose-Importers'. 'Moose-Query'. 'Moose-Query-Extensions'.
		   'Moose-SmalltalkImporter'. 'MooseIDE-WelcomeBrowser'.
		   'MooseIDE-Analysis'. 'MooseIDE-AttributedText'.
		   'MooseIDE-ButterflyMap'. 'MooseIDE-ClassBlueprint'.
		   'MooseIDE-CoUsageMap'. 'MooseIDE-Core'. 'MooseIDE-Core-Reporter'.
		   'MooseIDE-CriticBrowser'. 'MooseIDE-Dependency'.
		   'MooseIDE-Duplication'. 'MooseIDE-Export'. 'MooseIDE-Famix'.
		   'MooseIDE-LayerVisualization'. 'MooseIDE-Meta'. 'MooseIDE-NewTools'.
		   'MooseIDE-QueriesBrowser'. 'MooseIDE-QueriesDashboard'.
		   'MooseIDE-Spotter'. 'MooseIDE-Tagging'. 'MooseIDE-Visualization' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> mooseTests [

	<script>
	^ (self allResultsFor:
		   { 'Moose-Blueprint-Models-Tests'. 'Moose-Core-Tests'.
		   'Moose-Core-Tests-Entities'. 'Moose-Importers-Tests'.
		   'Moose-Query-Test'. 'Moose-SmalltalkImporter-Core-Tests'.
		   'Moose-SmalltalkImporter-KGB-Tests'.
		   'Moose-SmalltalkImporter-LAN-Tests'.
		   'Moose-TestResources-KGB-P10InteractedReferee'.
		   'Moose-TestResources-KGB-P11FullReferee'.
		   'Moose-TestResources-KGB-P12FullReferencer'.
		   'Moose-TestResources-KGB-P13FullReferencer'.
		   'Moose-TestResources-KGB-P14FullReferee'.
		   'Moose-TestResources-KGB-P1FullReferencer'.
		   'Moose-TestResources-KGB-P2InteractedReferencerReferee'.
		   'Moose-TestResources-KGB-P3InteractedReferencer'.
		   'Moose-TestResources-KGB-P4FullInteracted'.
		   'Moose-TestResources-KGB-P5FullReferee'.
		   'Moose-TestResources-KGB-P6InteractedReferee'.
		   'Moose-TestResources-KGB-P7ReferencerReferee'.
		   'Moose-TestResources-KGB-P8FullReferencer'.
		   'Moose-TestResources-KGB-P9FullReferencer'.
		   'Moose-TestResources-KGB-PExtensions'.
		   'Moose-TestResources-LAN'. 'Moose-TestResources-LCOM'.
		   'Moose-TestResources-PackageBlueprint-P1'.
		   'Moose-TestResources-PackageBlueprint-P2'.
		   'Moose-TestResources-PackageBlueprint-P3'.
		   'Moose-TestResources-PackageBlueprint-P4'.
		   'Moose-TestResources-Reference-Core'.
		   'Moose-TestResources-Reference-External'.
		   'Moose-TestResources-Reference-PackageOne'.
		   'Moose-TestResources-Reference-PackageTwo'.
		   'MooseIDE-ButterflyMap-Tests'. 'MooseIDE-CoUsageMap-Tests'.
		   'MooseIDE-CriticBrowser-Tests'. 'MooseIDE-NewTools-Tests'.
		   'MooseIDE-QueriesBrowser-Tests'. 'MooseIDE-Spotter-Tests'.
		   'MooseIDE-Tagging-Tests'. 'MooseIDE-Tests' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> nec [

	<script>
	^ (self allResultsFor: { 'NECompletion' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> necTests [

	<script>
	^ (self allResultsFor: { 'NECompletion-Tests' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> roassal [

	<script>
	^ (self allResultsFor:
		   { 'Roassal'. 'Roassal-Animation'. 'Roassal-BaselineMap'.
		   'Roassal-Builders'. 'Roassal-Chart'. 'Roassal-Chart-Examples'.
		   'Roassal-Class-Examples'. 'Roassal-Colors'. 'Roassal-DSM'.
		   'Roassal-Event'. 'Roassal-Examples'. 'Roassal-Experimental'.
		   'Roassal-Exporters'. 'Roassal-Exporters-Examples'.
		   'Roassal-FlameGraph-Examples'. 'Roassal-Inspector'.
		   'Roassal-Interaction'. 'Roassal-LayoutStudio'.
		   'Roassal-Layouts'. 'Roassal-Layouts-Util'. 'Roassal-Legend'.
		   'Roassal-Legend-Examples'. 'Roassal-Menu'. 'Roassal-Mondrian'.
		   'Roassal-Pie'. 'Roassal-Pie-Examples'. 'Roassal-SVG'.
		   'Roassal-SVG-Examples'. 'Roassal-Shapes'. 'Roassal-Spec'.
		   'Roassal-Spec-Examples'. 'Roassal-Spec-Morphic'.
		   'Roassal-Sunburst'. 'Roassal-Sunburst-Examples'.
		   'Roassal-TreeMap'. 'Roassal-TreeMap-Examples'.
		   'Roassal-UML'. 'Roassal-UML-Calypso'. 'Roassal-UML-Examples' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> roassalTests [

	<script>
	^ (self allResultsFor:
		   { 'Roassal-Animation-Tests'. 'Roassal-BaselineMap-Tests'.
		   'Roassal-Chart-Tests'. 'Roassal-Exporters-Tests'.
		   'Roassal-Global-Tests'. 'Roassal-Inspector-Tests'.
		   'Roassal-Interaction-Tests'. 'Roassal-LayoutStudio-Tests'.
		   'Roassal-Layouts-Tests'. 'Roassal-Shapes-Tests'.
		   'Roassal-Spec-Tests'. 'Roassal-SVG-Tests'. 'Roassal-UML-Tests' })
		  inspect
]

{ #category : 'benchmarks' }
CooBenchRunnerMessage class >> runComparisonForPackages: aCol [

	^ aCol collect: [ :pack |
			  self new
				  package: pack;
				  baseline: #completeBaseline;
				  others: { #completeDependency };
				  run ]
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> seaside [

	<script>
	^ (self allResultsFor:
		   { 'Seaside-Ajaxifier-Core'. 'Seaside-Canvas'. 'Seaside-Component'.
		   'Seaside-Continuation'. 'Seaside-Core'. 'Seaside-Development'.
		   'Seaside-Email'. 'Seaside-Environment'. 'Seaside-Examples'.
		   'Seaside-Flow'. 'Seaside-JSON-Core'. 'Seaside-Pharo-Canvas'.
		   'Seaside-Pharo-Continuation'. 'Seaside-Pharo-Core'.
		   'Seaside-Pharo-Development'. 'Seaside-Pharo-Email'.
		   'Seaside-Pharo-Environment'. 'Seaside-Pharo-Flow'.
		   'Seaside-Pharo-JSON-Core'. 'Seaside-Pharo-Tools-Web'.
		   'Seaside-Pharo-Welcome'. 'Seaside-REST-Core'. 'Seaside-RenderLoop'.
		   'Seaside-Session'. 'Seaside-Tools-Core'. 'Seaside-Tools-Web'.
		   'Seaside-Welcome'. 'Seaside-Widgets'. 'Seaside-Zinc-Core'.
		   'Seaside-Zinc-Pharo' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> seasideTests [

	<script>
	^ (self allResultsFor:
		   { 'Seaside-Tests-Canvas'. 'Seaside-Tests-Component'.
		   'Seaside-Tests-Core'. 'Seaside-Tests-Environment'.
		   'Seaside-Tests-Flow'. 'Seaside-Tests-Functional'.
		   'Seaside-Tests-Pharo-Canvas'. 'Seaside-Tests-Pharo-Continuation'.
		   'Seaside-Tests-Pharo-Core'. 'Seaside-Tests-Pharo-Functional'.
		   'Seaside-Tests-RenderLoop'. 'Seaside-Tests-Session' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> spec [

	<script>
	^ (self allResultsFor:
		   { 'Spec2-Adapters-Morphic'. 'Spec2-Adapters-Morphic-ListView'.
		   'Spec2-Adapters-Stub'. 'Spec2-Code'. 'Spec2-Code-Commands'.
		   'Spec2-Code-Diff'. 'Spec2-Code-Diff-Morphic'.
		   'Spec2-Code-Morphic'. 'Spec2-CommandLine'. 'Spec2-Commander2'.
		   'Spec2-Commands'. 'Spec2-CommonWidgets'. 'Spec2-Core'.
		   'Spec2-Dialogs'. 'Spec2-Examples'. 'Spec2-Interactions'.
		   'Spec2-Layout'. 'Spec2-ListView'. 'Spec2-Microdown'.
		   'Spec2-Morphic'. 'Spec2-Morphic-Examples'.
		   'Spec2-Transmission' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> specTEST [

	<script>
	^ (self allResultsFor:
		   { 'Spec2-Core' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerMessage class >> specTests [

	<script>
	^ (self allResultsFor:
		   { 'Spec2-Adapters-Morphic-Tests'. 'Spec2-Adapters-Stub'.
		   'Spec2-Backend-Tests'. 'Spec2-Code-Backend-Tests'.
		   'Spec2-Code-Diff-Tests'. 'Spec2-Code-Tests'. 'Spec2-Commander2-Tests'.
		   'Spec2-Dialogs-Tests'. 'Spec2-Morphic-Backend-Tests'.
		   'Spec2-Morphic-Tests'. 'Spec2-Tests' }) inspect
]

{ #category : 'COMPLETE' }
CooBenchRunnerMessage >> completeBaseline [
	"self new 
		package: CompletionSorter package;
		completeBaseline"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder messagesHeuristic: (builder newHeuristicBuilder
			 add: CoUnknownMessageHeuristic new;
			 build).
	benchmark := CooStaticBenchmarksMessage new
		             name: 'Baseline';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'COMPLETE' }
CooBenchRunnerMessage >> completeDependency [

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder messagesHeuristic: (builder newHeuristicBuilder
			 add: CoSelfMessageHeuristic new;
			 add: CoSuperMessageHeuristic new;
			 add: CoTypedReceiverMessageHeuristic new;
			 add: CoInitializeInferencedMessageHeuristic new;
			 add: CoLiteralMessageHeuristic new;
			 add: CoGlobalVariableMessageHeuristic new;
			 add: CoVariableWithTypeNameMessageHeuristic new;
			 add: CoDependencyMessageHeuristics new;
			 add: CoUnknownMessageHeuristic new;
			 build).
	benchmark := CooStaticBenchmarksMessage new
		             name: 'Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]
