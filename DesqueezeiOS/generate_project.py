"""Generate DesqueezeiOS/Desqueeze.xcodeproj/project.pbxproj from the files on disk.

The project links DesqueezeCore as a local Swift package. Object ids are
derived from names so regenerating is stable and diffs stay readable.
"""
import hashlib, pathlib, sys

ROOT = pathlib.Path(sys.argv[1])           # .../DesqueezeiOS
APP = ROOT / "Desqueeze"

def oid(*parts):
    return hashlib.sha1("/".join(parts).encode()).hexdigest()[:24].upper()

sources = sorted(p.relative_to(APP) for p in APP.rglob("*.swift"))
groups = sorted({s.parent for s in sources if str(s.parent) != "."})

L = []
w = L.append
w("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 60;\n\tobjects = {\n")

w("/* Begin PBXBuildFile section */")
for s in sources:
    w(f"\t\t{oid('build', str(s))} /* {s.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {oid('file', str(s))} /* {s.name} */; }};")
w(f"\t\t{oid('build','assets')} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {oid('file','assets')} /* Assets.xcassets */; }};")
w(f"\t\t{oid('build','privacy')} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {oid('file','privacy')} /* PrivacyInfo.xcprivacy */; }};")
w(f"\t\t{oid('build','core')} /* DesqueezeCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {oid('dep','core')} /* DesqueezeCore */; }};")
w("/* End PBXBuildFile section */\n")

w("/* Begin PBXFileReference section */")
w(f"\t\t{oid('product')} /* Desqueeze.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Desqueeze.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for s in sources:
    w(f"\t\t{oid('file', str(s))} /* {s.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {s.name}; sourceTree = \"<group>\"; }};")
w(f"\t\t{oid('file','assets')} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
w(f"\t\t{oid('file','privacy')} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};")
w(f"\t\t{oid('file','plist')} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
w(f"\t\t{oid('file','corepkg')} /* DesqueezeCore */ = {{isa = PBXFileReference; lastKnownFileType = wrapper; path = DesqueezeCore; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */\n")

w("/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{oid('phase','frameworks')} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t{oid('build','core')} /* DesqueezeCore in Frameworks */,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
w("/* End PBXFrameworksBuildPhase section */\n")

w("/* Begin PBXGroup section */")
w(f"\t\t{oid('group','root')} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{oid('group','app')} /* Desqueeze */,\n\t\t\t\t{oid('file','corepkg')} /* DesqueezeCore */,\n\t\t\t\t{oid('group','products')} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
kids = [f"\t\t\t\t{oid('file', str(s))} /* {s.name} */," for s in sources if str(s.parent) == "."]
kids += [f"\t\t\t\t{oid('group', str(g))} /* {g} */," for g in groups]
kids += [f"\t\t\t\t{oid('file','assets')} /* Assets.xcassets */,", f"\t\t\t\t{oid('file','plist')} /* Info.plist */,", f"\t\t\t\t{oid('file','privacy')} /* PrivacyInfo.xcprivacy */,"]
w(f"\t\t{oid('group','app')} /* Desqueeze */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n" + "\n".join(kids) + f"\n\t\t\t);\n\t\t\tpath = Desqueeze;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
for g in groups:
    kids = [f"\t\t\t\t{oid('file', str(s))} /* {s.name} */," for s in sources if s.parent == g]
    w(f"\t\t{oid('group', str(g))} /* {g} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n" + "\n".join(kids) + f"\n\t\t\t);\n\t\t\tpath = {g};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
w(f"\t\t{oid('group','products')} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{oid('product')} /* Desqueeze.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
w("/* End PBXGroup section */\n")

w("/* Begin PBXNativeTarget section */")
w(f"""\t\t{oid('target')} /* Desqueeze */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {oid('cfglist','target')} /* Build configuration list for PBXNativeTarget "Desqueeze" */;
\t\t\tbuildPhases = (
\t\t\t\t{oid('phase','sources')} /* Sources */,
\t\t\t\t{oid('phase','frameworks')} /* Frameworks */,
\t\t\t\t{oid('phase','resources')} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Desqueeze;
\t\t\tpackageProductDependencies = (
\t\t\t\t{oid('dep','core')} /* DesqueezeCore */,
\t\t\t);
\t\t\tproductName = Desqueeze;
\t\t\tproductReference = {oid('product')} /* Desqueeze.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};""")
w("/* End PBXNativeTarget section */\n")

w("/* Begin PBXProject section */")
w(f"""\t\t{oid('project')} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2700;
\t\t\t\tLastUpgradeCheck = 2700;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{oid('target')} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {oid('cfglist','project')} /* Build configuration list for PBXProject "Desqueeze" */;
\t\t\tcompatibilityVersion = "Xcode 15.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {oid('group','root')};
\t\t\tpackageReferences = (
\t\t\t\t{oid('pkgref','core')} /* XCLocalSwiftPackageReference "DesqueezeCore" */,
\t\t\t);
\t\t\tproductRefGroup = {oid('group','products')} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{oid('target')} /* Desqueeze */,
\t\t\t);
\t\t}};""")
w("/* End PBXProject section */\n")

w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{oid('phase','resources')} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t{oid('build','assets')} /* Assets.xcassets in Resources */,\n\t\t\t\t{oid('build','privacy')} /* PrivacyInfo.xcprivacy in Resources */,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
w("/* End PBXResourcesBuildPhase section */\n")

w("/* Begin PBXSourcesBuildPhase section */")
files = "\n".join(f"\t\t\t\t{oid('build', str(s))} /* {s.name} in Sources */," for s in sources)
w(f"\t\t{oid('phase','sources')} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{files}\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
w("/* End PBXSourcesBuildPhase section */\n")

def cfg(key, name, settings):
    body = "\n".join(f"\t\t\t\t{k} = {v};" for k, v in settings)
    return f"\t\t{oid('cfg', key, name)} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{body}\n\t\t\t}};\n\t\t\tname = {name};\n\t\t}};"

common = [("ALWAYS_SEARCH_USER_PATHS", "NO"), ("CLANG_ENABLE_MODULES", "YES"), ("CLANG_ENABLE_OBJC_ARC", "YES"),
          ("ENABLE_STRICT_OBJC_MSGSEND", "YES"), ("GCC_NO_COMMON_BLOCKS", "YES"),
          ("IPHONEOS_DEPLOYMENT_TARGET", "27.0"), ("SDKROOT", "iphoneos"),
          ("SWIFT_STRICT_CONCURRENCY", "complete"), ("SWIFT_VERSION", "6.0")]
debug = common + [("COPY_PHASE_STRIP", "NO"), ("DEBUG_INFORMATION_FORMAT", "dwarf"), ("ENABLE_TESTABILITY", "YES"),
                  ("GCC_OPTIMIZATION_LEVEL", "0"), ("GCC_PREPROCESSOR_DEFINITIONS", '(\n\t\t\t\t\t"DEBUG=1",\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t)'),
                  ("ONLY_ACTIVE_ARCH", "YES"), ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"), ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"')]
release = common + [("COPY_PHASE_STRIP", "NO"), ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'), ("ENABLE_NS_ASSERTIONS", "NO"),
                    ("SWIFT_COMPILATION_MODE", "wholemodule"), ("SWIFT_OPTIMIZATION_LEVEL", '"-O"'), ("VALIDATE_PRODUCT", "YES")]
target = [("CODE_SIGN_STYLE", "Automatic"), ("CURRENT_PROJECT_VERSION", "2"), ("DEVELOPMENT_TEAM", "FZ6W4MM7UN"),
          ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"), ("ENABLE_PREVIEWS", "YES"), ("GENERATE_INFOPLIST_FILE", "NO"), ("INFOPLIST_FILE", "Desqueeze/Info.plist"),
          ("LD_RUNPATH_SEARCH_PATHS", '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'),
          ("MARKETING_VERSION", "1.0"), ("PRODUCT_BUNDLE_IDENTIFIER", "com.chambersandlight.stillscope"),
          ("PRODUCT_NAME", '"$(TARGET_NAME)"'), ("SWIFT_EMIT_LOC_STRINGS", "YES"), ("TARGETED_DEVICE_FAMILY", '"1,2"')]

w("/* Begin XCBuildConfiguration section */")
w(cfg("project", "Debug", debug)); w(cfg("project", "Release", release))
w(cfg("target", "Debug", target)); w(cfg("target", "Release", target))
w("/* End XCBuildConfiguration section */\n")

w("/* Begin XCConfigurationList section */")
for key, label in (("project", 'PBXProject "Desqueeze"'), ("target", 'PBXNativeTarget "Desqueeze"')):
    w(f"\t\t{oid('cfglist', key)} /* Build configuration list for {label} */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{oid('cfg', key, 'Debug')} /* Debug */,\n\t\t\t\t{oid('cfg', key, 'Release')} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
w("/* End XCConfigurationList section */\n")

w("/* Begin XCLocalSwiftPackageReference section */")
w(f"\t\t{oid('pkgref','core')} /* XCLocalSwiftPackageReference \"DesqueezeCore\" */ = {{\n\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = DesqueezeCore;\n\t\t}};")
w("/* End XCLocalSwiftPackageReference section */\n")

w("/* Begin XCSwiftPackageProductDependency section */")
w(f"\t\t{oid('dep','core')} /* DesqueezeCore */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tproductName = DesqueezeCore;\n\t\t}};")
w("/* End XCSwiftPackageProductDependency section */")

w(f"\t}};\n\trootObject = {oid('project')} /* Project object */;\n}}")
(ROOT / "Desqueeze.xcodeproj" / "project.pbxproj").write_text("\n".join(L) + "\n")
print("sources:", len(sources), "groups:", [str(g) for g in groups])

# A shared scheme, committed with the project. Xcode Cloud and any other
# machine can only build a scheme that is shared; Xcode's automatic ones are
# per-user and never leave the Mac that made them.
ref = f'''<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{oid('target')}"
               BuildableName = "Desqueeze.app"
               BlueprintName = "Desqueeze"
               ReferencedContainer = "container:Desqueeze.xcodeproj">
            </BuildableReference>'''
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
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
            {ref}
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
         {ref}
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
         {ref}
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
'''
schemes = ROOT / "Desqueeze.xcodeproj" / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
(schemes / "Desqueeze.xcscheme").write_text(scheme)
