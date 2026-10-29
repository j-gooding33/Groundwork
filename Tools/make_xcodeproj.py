#!/usr/bin/env python3
"""Writes Groundwork.xcodeproj (Xcode 16 format) at the repo root.

The app sources are a synced folder (App/Groundwork): Swift files added there
join the app without touching the project. The local package GroundworkCore
provides the GroundworkCore and GroundworkView libraries. Data/ and
Art/generated/ are bundled as folder references.

Re-run after changing settings here: python3 Tools/make_xcodeproj.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJ = ROOT / "Groundwork.xcodeproj"
BUNDLE_ID = "com.groundwork.Groundwork"

_n = [0]
def oid():
    _n[0] += 1
    return f"6A0D{_n[0]:020X}"

project, main_group, app_group, sync_group, products_group = oid(), oid(), oid(), oid(), oid()
data_ref, generated_ref, app_product = oid(), oid(), oid()
data_bf, generated_bf, core_bf, view_bf = oid(), oid(), oid(), oid()
sources_phase, frameworks_phase, resources_phase = oid(), oid(), oid()
target, package_ref, core_dep, view_dep = oid(), oid(), oid(), oid()
proj_debug, proj_release, proj_list = oid(), oid(), oid()
tgt_debug, tgt_release, tgt_list = oid(), oid(), oid()

COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "SDKROOT": "iphoneos",
}
PROJ_DEBUG = {**COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"',
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}
PROJ_RELEASE = {**COMMON,
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}
LANDSCAPE = '"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'
TARGET = {
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": '""',
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "INFOPLIST_KEY_CFBundleDisplayName": "Groundwork",
    "INFOPLIST_KEY_LSApplicationCategoryType": '"public.app-category.simulation-games"',
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UIRequiresFullScreen": "YES",
    "INFOPLIST_KEY_UIStatusBarHidden": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": LANDSCAPE,
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": LANDSCAPE,
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)',
    "MARKETING_VERSION": "0.1",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}

def settings(d):
    return "".join(f"\t\t\t\t{k} = {v};\n" for k, v in sorted(d.items()))

def config(i, name, d):
    return (f"\t\t{i} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n"
            f"{settings(d)}\t\t\t}};\n\t\t\tname = {name};\n\t\t}};\n")

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 77;
	objects = {{

/* Begin PBXBuildFile section */
		{data_bf} /* Data in Resources */ = {{isa = PBXBuildFile; fileRef = {data_ref} /* Data */; }};
		{generated_bf} /* generated in Resources */ = {{isa = PBXBuildFile; fileRef = {generated_ref} /* generated */; }};
		{core_bf} /* GroundworkCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {core_dep} /* GroundworkCore */; }};
		{view_bf} /* GroundworkView in Frameworks */ = {{isa = PBXBuildFile; productRef = {view_dep} /* GroundworkView */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		{app_product} /* Groundwork.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Groundwork.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{data_ref} /* Data */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = Data; sourceTree = "<group>"; }};
		{generated_ref} /* generated */ = {{isa = PBXFileReference; lastKnownFileType = folder; name = generated; path = Art/generated; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{sync_group} /* Groundwork */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = Groundwork;
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{core_bf} /* GroundworkCore in Frameworks */,
				{view_bf} /* GroundworkView in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group} = {{
			isa = PBXGroup;
			children = (
				{app_group} /* App */,
				{data_ref} /* Data */,
				{generated_ref} /* generated */,
				{products_group} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{app_group} /* App */ = {{
			isa = PBXGroup;
			children = (
				{sync_group} /* Groundwork */,
			);
			path = App;
			sourceTree = "<group>";
		}};
		{products_group} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_product} /* Groundwork.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* Groundwork */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {tgt_list} /* Build configuration list for PBXNativeTarget "Groundwork" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				{sync_group} /* Groundwork */,
			);
			name = Groundwork;
			packageProductDependencies = (
				{core_dep} /* GroundworkCore */,
				{view_dep} /* GroundworkView */,
			);
			productName = Groundwork;
			productReference = {app_product} /* Groundwork.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{target} = {{
						CreatedOnToolsVersion = 16.0;
					}};
				}};
			}};
			buildConfigurationList = {proj_list} /* Build configuration list for PBXProject "Groundwork" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group};
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				{package_ref} /* XCLocalSwiftPackageReference "GroundworkCore" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* Groundwork */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{data_bf} /* Data in Resources */,
				{generated_bf} /* generated in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{config(proj_debug, "Debug", PROJ_DEBUG)}{config(proj_release, "Release", PROJ_RELEASE)}{config(tgt_debug, "Debug", TARGET)}{config(tgt_release, "Release", TARGET)}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{proj_list} /* Build configuration list for PBXProject "Groundwork" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_debug} /* Debug */,
				{proj_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{tgt_list} /* Build configuration list for PBXNativeTarget "Groundwork" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{tgt_debug} /* Debug */,
				{tgt_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{package_ref} /* XCLocalSwiftPackageReference "GroundworkCore" */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = GroundworkCore;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{core_dep} /* GroundworkCore */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {package_ref} /* XCLocalSwiftPackageReference "GroundworkCore" */;
			productName = GroundworkCore;
		}};
		{view_dep} /* GroundworkView */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {package_ref} /* XCLocalSwiftPackageReference "GroundworkCore" */;
			productName = GroundworkView;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {project} /* Project object */;
}}
"""

scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "Groundwork.app"
               BlueprintName = "Groundwork"
               ReferencedContainer = "container:Groundwork.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "Groundwork.app"
            BlueprintName = "Groundwork"
            ReferencedContainer = "container:Groundwork.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "Groundwork.app"
            BlueprintName = "Groundwork"
            ReferencedContainer = "container:Groundwork.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

workspace = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

(PROJ / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
(PROJ / "xcshareddata" / "xcschemes").mkdir(parents=True, exist_ok=True)
(PROJ / "project.pbxproj").write_text(pbx)
(PROJ / "project.xcworkspace" / "contents.xcworkspacedata").write_text(workspace)
(PROJ / "xcshareddata" / "xcschemes" / "Groundwork.xcscheme").write_text(scheme)
print(f"Wrote {PROJ.relative_to(ROOT)}")
