"
```smalltalk
runVariableOnNeCompletionPackage

	<script>
	^ (CooStaticBenchmarksVariables
		   runOnPackage:
		   (PackageOrganizer default packageNamed: 'NECompletion')
		   heuristics: [ :b | b ]) inspect
```


```smalltalk
comparingSpecTest

	<script>
	CooBenchRunnerVariables new
		package: (PackageOrganizer default packageNamed: 'Spec2-Tests');
		baseline: #withoutPackageScope;
		others: { #withPackageScope };
		run
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
	#name : 'CooBenchRunnerVariables',
	#superclass : 'CooBenchRunner',
	#category : 'ExtendedHeuristicCompletion-Benchmarks-Benchmarks',
	#package : 'ExtendedHeuristicCompletion-Benchmarks',
	#tag : 'Benchmarks'
}

{ #category : 'examples' }
CooBenchRunnerVariables class >> iceberg [

	<script>
	^ (self allResultsFor:
		   { 'Iceberg'. 'Iceberg-ArchitecturalRules'.'Iceberg-Libgit'. 'Iceberg-Libgit-Filetree'.
		   'Iceberg-Libgit-Tonel'.'Iceberg-Memory'. 'Iceberg-Metacello-Integration'.'Iceberg-Playground-Plugin-Gist'.
		   'Iceberg-Plugin'. 'Iceberg-Plugin-Github'.'Iceberg-Plugin-Metacello'. 'Iceberg-Plugin-Migration'.
		   'Iceberg-Plugin-Pharo'. 'Iceberg-TipUI'. 'Iceberg-TipUI-SnapShotBrowser' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> icebergTest [

	<script>
	^ (self allResultsFor:
		   { 'Iceberg-Plugin-Migration-Tests'.
		   'Iceberg-Tests'. 'Iceberg-Tests-MetacelloIntegration' .'Iceberg-TipUI-SnapshotBrowser-Tests'. 'Iceberg-UI-Tests'}) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> moose [

	<script>
	^ (self allResultsFor: {  'Moose-Blueprint-Invocations-Models'.
 'Moose-Blueprint-Models'.
 'Moose-Blueprint-Visualization-Models'.
 'Moose-Configuration'.
 'Moose-Core'.
 'Moose-Core-Generator'.
 'Moose-Importers'.
 'Moose-Query'.
 'Moose-Query-Extensions'.
 'Moose-SmalltalkImporter'.
 'MooseIDE-WelcomeBrowser'.
 'MooseIDE-Analysis'.
 'MooseIDE-AttributedText'.
 'MooseIDE-ButterflyMap'.
 'MooseIDE-ClassBlueprint'.
 'MooseIDE-CoUsageMap'.
 'MooseIDE-Core'.
 'MooseIDE-Core-Reporter'.
 'MooseIDE-CriticBrowser'.
 'MooseIDE-Dependency'.
 'MooseIDE-Duplication'.
 'MooseIDE-Export'.
 'MooseIDE-Famix'.
 'MooseIDE-LayerVisualization'.
 'MooseIDE-Meta'.
 'MooseIDE-NewTools'.
 'MooseIDE-QueriesBrowser'.
 'MooseIDE-QueriesDashboard'.
 'MooseIDE-Spotter'.
 'MooseIDE-Tagging'.
 'MooseIDE-Visualization' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> mooseTests [

	<script>
	^ (self allResultsFor: {  'Moose-Blueprint-Models-Tests'.
 'Moose-Core-Tests'.
 'Moose-Core-Tests-Entities'.
 'Moose-Importers-Tests'.
 'Moose-Query-Test'.
 'Moose-SmalltalkImporter-Core-Tests'.
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
 'Moose-TestResources-LAN'.
 'Moose-TestResources-LCOM'.
 'Moose-TestResources-PackageBlueprint-P1'.
 'Moose-TestResources-PackageBlueprint-P2'.
 'Moose-TestResources-PackageBlueprint-P3'.
 'Moose-TestResources-PackageBlueprint-P4'.
 'Moose-TestResources-Reference-Core'.
 'Moose-TestResources-Reference-External'.
 'Moose-TestResources-Reference-PackageOne'.
 'Moose-TestResources-Reference-PackageTwo'.
 'MooseIDE-ButterflyMap-Tests'.
 'MooseIDE-CoUsageMap-Tests'.
 'MooseIDE-CriticBrowser-Tests'.
 'MooseIDE-NewTools-Tests'.
 'MooseIDE-QueriesBrowser-Tests'.
 'MooseIDE-Spotter-Tests'.
 'MooseIDE-Tagging-Tests'.
 'MooseIDE-Tests' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> nec [

	<script>
	^ (self allResultsFor: {'NECompletion' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> necTests [

	<script>
	^ (self allResultsFor: {'NECompletion-Tests' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> roassal [

	<script>
	^ (self allResultsFor:
		   {  'Roassal'.
 'Roassal-Animation'.
 'Roassal-BaselineMap'.
 'Roassal-Builders'.
 'Roassal-Chart'.
 'Roassal-Chart-Examples'.
 'Roassal-Class-Examples'.
 'Roassal-Colors'.
 'Roassal-DSM'.
 'Roassal-Event'.
 'Roassal-Examples'.
 'Roassal-Experimental'.
 'Roassal-Exporters'.
 'Roassal-Exporters-Examples'.
 'Roassal-FlameGraph-Examples'.
 'Roassal-Inspector'.
 'Roassal-Interaction'.
 'Roassal-LayoutStudio'.
 'Roassal-Layouts'.
 'Roassal-Layouts-Util'.
 'Roassal-Legend'.
 'Roassal-Legend-Examples'.
 'Roassal-Menu'.
 'Roassal-Mondrian'.
 'Roassal-Pie'.
 'Roassal-Pie-Examples'.
 'Roassal-SVG'.
 'Roassal-SVG-Examples'.
 'Roassal-Shapes'.
 'Roassal-Spec'.
 'Roassal-Spec-Examples'.
 'Roassal-Spec-Morphic'.
 'Roassal-Sunburst'.
 'Roassal-Sunburst-Examples'.
 'Roassal-TreeMap'.
 'Roassal-TreeMap-Examples'.
 'Roassal-UML'.
 'Roassal-UML-Calypso'.
 'Roassal-UML-Examples'}) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> roassalTests [

	<script>
	^ (self allResultsFor:
		   {  'Roassal-Animation-Tests'.
 'Roassal-BaselineMap-Tests'.
 'Roassal-Chart-Tests'.
 'Roassal-Exporters-Tests'.
 'Roassal-Global-Tests'.
 'Roassal-Inspector-Tests'.
 'Roassal-Interaction-Tests'.
 'Roassal-LayoutStudio-Tests'.
 'Roassal-Layouts-Tests'.
 'Roassal-Shapes-Tests'.
 'Roassal-Spec-Tests'.
 'Roassal-SVG-Tests'.
 'Roassal-UML-Tests' }) inspect
]

{ #category : 'benchmarks' }
CooBenchRunnerVariables class >> runComparisonForPackages: aCol [

	^ aCol collect: [ :pack |
			  self new
				  package: pack;
				  baseline: #completeBaseline;
				  others:
					  { #complete2LevelDependency. #completeBaseline. #completeDependency. #completeLateralPackage. #completeReverseDependency. #completeSemantics. #local2LevelDependency. #localDependency. #localLateral. #localReverseDependency. #unit2LevelDependency. #unitDirectDependency. #unitEmpty. #unitLateral. #unitPackageLocal. #unitReverseDependency};
				  run ]
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> seaside [

	<script>
	^ (self allResultsFor:
		   {  'Seaside-Ajaxifier-Core'.
 'Seaside-Canvas'.
 'Seaside-Component'.
 'Seaside-Continuation'.
 'Seaside-Core'.
 'Seaside-Development'.
 'Seaside-Email'.
 'Seaside-Environment'.
 'Seaside-Examples'.
 'Seaside-Flow'.
 'Seaside-JSON-Core'.
 'Seaside-Pharo-Canvas'.
 'Seaside-Pharo-Continuation'.
 'Seaside-Pharo-Core'.
 'Seaside-Pharo-Development'.
 'Seaside-Pharo-Email'.
 'Seaside-Pharo-Environment'.
 'Seaside-Pharo-Flow'.
 'Seaside-Pharo-JSON-Core'.
 'Seaside-Pharo-Tools-Web'.
 'Seaside-Pharo-Welcome'.
 'Seaside-REST-Core'.
 'Seaside-RenderLoop'.
 'Seaside-Session'.
 'Seaside-Tools-Core'.
 'Seaside-Tools-Web'.
 'Seaside-Welcome'.
 'Seaside-Widgets'.
 'Seaside-Zinc-Core'.
 'Seaside-Zinc-Pharo' })
		  inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> seasideTests [

	<script>
	^ (self allResultsFor:
		   { 'Seaside-Tests-Canvas'.
 'Seaside-Tests-Component'.
 'Seaside-Tests-Core'.
 'Seaside-Tests-Environment'.
 'Seaside-Tests-Flow'.
 'Seaside-Tests-Functional'.
 'Seaside-Tests-Pharo-Canvas'.
 'Seaside-Tests-Pharo-Continuation'.
 'Seaside-Tests-Pharo-Core'.
 'Seaside-Tests-Pharo-Functional'.
 'Seaside-Tests-RenderLoop'.
 'Seaside-Tests-Session' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> spec [

	<script>
	^ (self allResultsFor:
		   {  'Spec2-Adapters-Morphic'.
 'Spec2-Adapters-Morphic-ListView'.
 'Spec2-Adapters-Stub'.
 'Spec2-Code'.
 'Spec2-Code-Commands'.
 'Spec2-Code-Diff'.
 'Spec2-Code-Diff-Morphic'.
 'Spec2-Code-Morphic'.
 'Spec2-CommandLine'.
 'Spec2-Commander2'.
 'Spec2-Commands'.
 'Spec2-CommonWidgets'.
 'Spec2-Core'.
 'Spec2-Dialogs'.
 'Spec2-Examples'.
 'Spec2-Interactions'.
 'Spec2-Layout'.
 'Spec2-ListView'.
 'Spec2-Microdown'.
 'Spec2-Morphic'.
 'Spec2-Morphic-Examples'.
 'Spec2-Transmission' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> specTEST [

	<script>
	^ (self allResultsFor:
		   { 'Spec2-Core' }) inspect
]

{ #category : 'examples' }
CooBenchRunnerVariables class >> specTests [

	<script>
	^ (self allResultsFor:
		   { 
		   'Spec2-Adapters-Morphic-Tests'. 'Spec2-Adapters-Stub'.
		   'Spec2-Backend-Tests'.'Spec2-Code-Backend-Tests'.
		  
		   'Spec2-Code-Diff-Tests'. 
		   'Spec2-Code-Tests'.
		   'Spec2-Commander2-Tests'. 
		   'Spec2-Dialogs-Tests'.'Spec2-Morphic-Backend-Tests'.'Spec2-Morphic-Tests'.
		   'Spec2-Tests'}) inspect
]

{ #category : 'COMPLETE' }
CooBenchRunnerVariables >> complete2LevelDependency [
	"self new 
		package: AnalyserData1 package;
		complete2LevelDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass: Co2LevelDependencyWithoutLocalFetcher );
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Conplete 2 Level Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'COMPLETE' }
CooBenchRunnerVariables >> completeBaseline [
	"self new 
		package: NECEntry package;
		completeBaseline"

	| builder benchmark |
	builder := CoGlobalSorterResultSetBuilder new.
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Complete Baseline (Flat Namespace)';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	benchmark inspect.
	^ benchmark
]

{ #category : 'COMPLETE' }
CooBenchRunnerVariables >> completeDependency [
	"self new 
		package: NECEntry package;
		completeDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass: CoDependencyGlobalVariableFetcher );
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Complete Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'COMPLETE' }
CooBenchRunnerVariables >> completeLateralPackage [
	"self new 
		package: AnalyserData1 package;
		completeLateralPackageWithLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoLateralPackageWithLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Complete Lateral Packages (IWST)';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> completeLocalPackage [
	"self new 
		package: AnalyserData1 package;
		completeLocalPackage"

	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		completeLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoGlobalVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoPackageLocalGlobalVariableFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Complete Local Package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'COMPLETE' }
CooBenchRunnerVariables >> completeReverseDependency [

	"self new 
		package: AnalyserData1 package;
		completeReverseDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoReverseDependencyPackageWithLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Complete Reverse Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'COMPLETE' }
CooBenchRunnerVariables >> completeSemantics [
	"self new 
		package: NECEntry package;
		completeSemantics"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.

	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: CoGlobalVariablesHeuristic new;
			 build).

	benchmark := CooStaticBenchmarksVariables new
		             name: 'Complete Semantics';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'LOCAL' }
CooBenchRunnerVariables >> local2LevelDependency [
	"self new 
		package: NECEntry package;
		local2LevelDependencyWithLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoTransitiveDependencyPackageScopedGlobalVariableFetcher );
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: '2 Level Transitive Dependency with local package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'LOCAL' }
CooBenchRunnerVariables >> localDependency [
	"self new 
		package: NECEntry package;
		localDependencyWithLocalPackage"
		
	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		localDependencyWithLocalPackage"	

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoDependencyPackageScopedGlobalVariableFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Only Dependency With LocalPackage';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'LOCAL' }
CooBenchRunnerVariables >> localLateral [
	"self new 
		package: AnalyserData1 package;
		localLateralWithLocalPackage"
		
	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		localLateralWithLocalPackage"		

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoLateralPackageWithLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Only lateral with local package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'LOCAL' }
CooBenchRunnerVariables >> localReverseDependency [
	"self new 
		package: (PackageOrganizer default packageNamed: 'NECompletion-Tests') ;
		localReverseDependencyWithLocalPackage"
	
	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		localReverseDependencyWithLocalPackage"	

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoReverseDependencyPackageWithLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Reverse Dependency with Local Package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'UNIT' }
CooBenchRunnerVariables >> unit2LevelDependency [
	"self new 
		package: NECEntry package;
		unit2LevelDependencyWithoutLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  Co2LevelDependencyWithoutLocalFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: '2 Level Dependency without local package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'UNIT' }
CooBenchRunnerVariables >> unitDirectDependency [
	"self new 
		package: NECEntry package;
		unitDirectDependencyWithoutLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoDependencyPackageWithoutLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'unit Direct Dependency Without Local Package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'UNIT' }
CooBenchRunnerVariables >> unitEmpty [
	"self new 
		package: AnalyserData1 package;
		unitEmptyHeuristic"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoNullFetcherHeuristic new;
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Unit Empty Heuristic';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'UNIT' }
CooBenchRunnerVariables >> unitLateral [
	"self new 
		package: AnalyserData1 package;
		unitLateralsWithoutLocalPackage"

	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		unitLateralsWithoutLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoLateralPackageWithoutLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Unit Lateral Packages Without Local Package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'UNIT' }
CooBenchRunnerVariables >> unitPackageLocal [
	"self new 
		package: (PackageOrganizer default packageNamed: 'NECompletion-Tests') ;
		unitPackageLocal"

	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		unitPackageLocal"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoPackageLocalGlobalVariableFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Unit Package Local';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'UNIT' }
CooBenchRunnerVariables >> unitReverseDependency [
	"self new 
		package: (PackageOrganizer default packageNamed: 'NECompletion-Tests') ;
		unitReverseDependencyWithoutLocalPackage"

	"self new 
		package: (PackageOrganizer default packageNamed: 'Microdown') ;
		unitReverseDependencyWithoutLocalPackage"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoReverseDependencyWithoutLocalPackageFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Unit Reverse Dependency without Local Package';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withAdaptiveWeightedMetaFetcher [
	"self new 
		package: AnalyserData1 package;
		withAdaptiveWeightedMetaFetcher"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoAdaptiveMetaGlobalVariableFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Adaptive Weighted Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withBaselinePrefix [
	"self new 
		package: NECEntry package;
		withGlobalSorterScope"

	| builder benchmark |
	builder := CoGlobalSorterResultSetBuilder new.
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Flat global sorter variable';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	benchmark inspect.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withDependencyPrefix [
	"self new 
		package: NECEntry package;
		withDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoDependencyPackageScopedGlobalVariableFetcherPrefix);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withLateralDependency [
	"self new 
		package: AnalyserData1 package;
		withReverseDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoLateralPackageGlobalVariableFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Lateral Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withLateralDependencyPrefix [ 
	"self new 
		package: AnalyserData1 package;
		withReverseDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoLateralPackageGlobalVariableFetcherPrefix);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Lateral Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withPackageScopePrefix [
	"self new 
		package: AnalyserData1 package;
		withPackageScope"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoRepositoryPackageScopedGlobalVariableFetcherPrefix);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Packages Scope';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withReverseDependencyPrefix [ 
	"self new 
		package: AnalyserData1 package;
		withReverseDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoReverseDependencyPackageScopedGlobalVariableFetcherPrefix);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Reverse Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withTransitiveDependencyPrefix [
	"self new 
		package: AnalyserData1 package;
		withTransitiveDependency"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoTransitiveDependencyPackageScopedGlobalVariableFetcherPrefix);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Transitive Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withWeightedMetaFetcher [
	"self new 
		package: AnalyserData1 package;
		withWeightedMetaFetcher"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoWeightedMetaGlobalVariableFetcher);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Weighted Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]

{ #category : 'unused' }
CooBenchRunnerVariables >> withWeightedMetaFetcherPrefix [
	"self new 
		package: AnalyserData1 package;
		withWeightedMetaFetcher"

	| builder benchmark |
	builder := CoASTHeuristicsResultSetBuilder new.
	builder variablesHeuristic: (builder newHeuristicBuilder
			 add: CoLocalScopeVariablesHeuristic new;
			 add: CoWorkspaceVariablesHeuristic new;
			 add: CoInstanceAccessibleVariablesHeuristic new;
			 add: (CoGlobalVariablesHeuristic new globalVariableFetcherClass:
						  CoWeightedMetaGlobalVariableFetcherPrefix);
			 build).
	benchmark := CooStaticBenchmarksVariables new
		             name: 'Weighted Dependency';
		             scope: (CoBenchmarkPackage on: package);
		             builder: builder;
		             run.
	^ benchmark
]
