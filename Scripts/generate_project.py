#!/usr/bin/env python3
"""Regenerates Creativo.xcodeproj/project.pbxproj from the folder tree.

The project uses explicit file references rather than Xcode 16's file-system
synchronized groups, so the project opens in Xcode 15 as well as 16. Run this
after adding, moving or deleting source files:

    python3 Scripts/generate_project.py

It is deterministic: identifiers are derived from paths, so regenerating
produces no spurious diff.
"""
from __future__ import annotations

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_NAME = "Creativo"
TEST_NAME = "CreativoTests"
BUNDLE_ID = "com.creativo.studio"
MARKETING_VERSION = "0.1.0"
MACOS_TARGET = "14.0"
IOS_TARGET = "17.0"
SWIFT_VERSION = "5.0"

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcassets": "folder.assetcatalog",
    ".entitlements": "text.plist.entitlements",
    ".md": "net.daringfireball.markdown",
    ".json": "text.json",
    ".plist": "text.plist.xml",
}


def oid(*parts: str) -> str:
    """Deterministic 24-hex-character object identifier."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


class Node:
    """A group in the project navigator."""

    def __init__(self, name: str, path: pathlib.Path):
        self.name = name
        self.path = path
        self.children: dict[str, "Node"] = {}
        self.files: list[pathlib.Path] = []


def build_tree(root: pathlib.Path, files: list[pathlib.Path]) -> Node:
    node = Node(root.name, root)
    for file in files:
        relative = file.relative_to(root)
        cursor = node
        for part in relative.parts[:-1]:
            if part not in cursor.children:
                cursor.children[part] = Node(part, cursor.path / part)
            cursor = cursor.children[part]
        cursor.files.append(file)
    return node


def collect(directory: pathlib.Path) -> list[pathlib.Path]:
    """Source and resource files of a target, asset catalogs kept whole."""
    result: list[pathlib.Path] = []
    for path in sorted(directory.rglob("*")):
        if any(part.startswith(".") for part in path.parts):
            continue
        if any(part.endswith(".xcassets") for part in path.parts[:-1]):
            continue  # already covered by the catalog itself
        if path.is_dir():
            if path.suffix == ".xcassets":
                result.append(path)
            continue
        if path.suffix in (".swift",):
            result.append(path)
    return sorted(set(result))


def file_ref_lines(files: list[pathlib.Path]) -> list[str]:
    lines = []
    for file in files:
        rel = file.relative_to(ROOT).as_posix()
        ftype = FILE_TYPES.get(file.suffix, "text")
        lines.append(
            f'\t\t{oid("ref", rel)} /* {file.name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = {ftype}; path = "{file.name}"; sourceTree = "<group>"; }};'
        )
    return lines


def group_lines(node: Node, target: str) -> list[str]:
    lines: list[str] = []
    for child in node.children.values():
        lines += group_lines(child, target)

    children_refs = []
    for child in node.children.values():
        rel = child.path.relative_to(ROOT).as_posix()
        children_refs.append(f'\t\t\t\t{oid("group", target, rel)} /* {child.name} */,')
    for file in node.files:
        rel = file.relative_to(ROOT).as_posix()
        children_refs.append(f'\t\t\t\t{oid("ref", rel)} /* {file.name} */,')

    rel = node.path.relative_to(ROOT).as_posix()
    lines.append(f'\t\t{oid("group", target, rel)} /* {node.name} */ = {{')
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines += children_refs
    lines.append("\t\t\t);")
    lines.append(f'\t\t\tpath = "{node.name}";')
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
    return lines


def build_file_lines(files: list[pathlib.Path], target: str) -> list[str]:
    lines = []
    for file in files:
        rel = file.relative_to(ROOT).as_posix()
        lines.append(
            f'\t\t{oid("build", target, rel)} /* {file.name} in {"Sources" if file.suffix == ".swift" else "Resources"} */ '
            f'= {{isa = PBXBuildFile; fileRef = {oid("ref", rel)} /* {file.name} */; }};'
        )
    return lines


def phase_children(files: list[pathlib.Path], target: str, suffixes: tuple[str, ...]) -> list[str]:
    return [
        f'\t\t\t\t{oid("build", target, f.relative_to(ROOT).as_posix())} /* {f.name} */,'
        for f in files
        if f.suffix in suffixes
    ]


def common_settings(debug: bool) -> str:
    shared = f"""				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = {IOS_TARGET};
				MACOSX_DEPLOYMENT_TARGET = {MACOS_TARGET};
				SDKROOT = auto;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_VERSION = {SWIFT_VERSION};
				TARGETED_DEVICE_FAMILY = 2;"""
    if debug:
        return shared + """
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";"""
    return shared + """
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;"""


APP_SETTINGS = f"""				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Config/Creativo.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Creativo;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.video";
				"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]" = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks";
				"LD_RUNPATH_SEARCH_PATHS[sdk=macosx*]" = "@executable_path/../Frameworks";
				MARKETING_VERSION = {MARKETING_VERSION};
				PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;"""

TEST_SETTINGS = f"""				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = {MARKETING_VERSION};
				PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/{APP_NAME}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP_NAME}";"""


def main() -> int:
    app_files = collect(ROOT / APP_NAME)
    test_files = collect(ROOT / TEST_NAME)
    entitlements = ROOT / "Config" / "Creativo.entitlements"

    app_tree = build_tree(ROOT / APP_NAME, app_files)
    test_tree = build_tree(ROOT / TEST_NAME, test_files)

    ids = {
        "project": oid("project"),
        "main_group": oid("maingroup"),
        "products": oid("products"),
        "config_group": oid("configgroup"),
        "app_target": oid("target", APP_NAME),
        "test_target": oid("target", TEST_NAME),
        "app_product": oid("product", APP_NAME),
        "test_product": oid("product", TEST_NAME),
        "app_sources": oid("phase", APP_NAME, "sources"),
        "app_frameworks": oid("phase", APP_NAME, "frameworks"),
        "app_resources": oid("phase", APP_NAME, "resources"),
        "test_sources": oid("phase", TEST_NAME, "sources"),
        "test_frameworks": oid("phase", TEST_NAME, "frameworks"),
        "test_resources": oid("phase", TEST_NAME, "resources"),
        "dependency": oid("dependency"),
        "proxy": oid("proxy"),
        "project_configs": oid("configlist", "project"),
        "app_configs": oid("configlist", APP_NAME),
        "test_configs": oid("configlist", TEST_NAME),
        "entitlements": oid("ref", "Config/Creativo.entitlements"),
    }
    for scope in ("project", APP_NAME, TEST_NAME):
        ids[f"{scope}_debug"] = oid("config", scope, "Debug")
        ids[f"{scope}_release"] = oid("config", scope, "Release")

    out: list[str] = []
    add = out.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")

    add("\n/* Begin PBXBuildFile section */")
    for line in build_file_lines(app_files, APP_NAME) + build_file_lines(test_files, TEST_NAME):
        add(line)
    add("/* End PBXBuildFile section */")

    add("\n/* Begin PBXContainerItemProxy section */")
    add(f'\t\t{ids["proxy"]} /* PBXContainerItemProxy */ = {{')
    add("\t\t\tisa = PBXContainerItemProxy;")
    add(f'\t\t\tcontainerPortal = {ids["project"]} /* Project object */;')
    add("\t\t\tproxyType = 1;")
    add(f'\t\t\tremoteGlobalIDString = {ids["app_target"]};')
    add(f"\t\t\tremoteInfo = {APP_NAME};")
    add("\t\t};")
    add("/* End PBXContainerItemProxy section */")

    add("\n/* Begin PBXFileReference section */")
    for line in file_ref_lines(app_files) + file_ref_lines(test_files):
        add(line)
    add(
        f'\t\t{ids["entitlements"]} /* Creativo.entitlements */ = {{isa = PBXFileReference; '
        'lastKnownFileType = text.plist.entitlements; path = "Creativo.entitlements"; sourceTree = "<group>"; };'
    )
    add(
        f'\t\t{ids["app_product"]} /* {APP_NAME}.app */ = {{isa = PBXFileReference; '
        f'explicitFileType = wrapper.application; includeInIndex = 0; path = "{APP_NAME}.app"; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )
    add(
        f'\t\t{ids["test_product"]} /* {TEST_NAME}.xctest */ = {{isa = PBXFileReference; '
        f'explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = "{TEST_NAME}.xctest"; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )
    add("/* End PBXFileReference section */")

    add("\n/* Begin PBXFrameworksBuildPhase section */")
    for key in ("app_frameworks", "test_frameworks"):
        add(f'\t\t{ids[key]} /* Frameworks */ = {{')
        add("\t\t\tisa = PBXFrameworksBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")

    add("\n/* Begin PBXGroup section */")
    for line in group_lines(app_tree, APP_NAME) + group_lines(test_tree, TEST_NAME):
        add(line)

    add(f'\t\t{ids["config_group"]} /* Config */ = {{')
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f'\t\t\t\t{ids["entitlements"]} /* Creativo.entitlements */,')
    add("\t\t\t);")
    add('\t\t\tpath = "Config";')
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")

    add(f'\t\t{ids["main_group"]} = {{')
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f'\t\t\t\t{oid("group", APP_NAME, APP_NAME)} /* {APP_NAME} */,')
    add(f'\t\t\t\t{oid("group", TEST_NAME, TEST_NAME)} /* {TEST_NAME} */,')
    add(f'\t\t\t\t{ids["config_group"]} /* Config */,')
    add(f'\t\t\t\t{ids["products"]} /* Products */,')
    add("\t\t\t);")
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")

    add(f'\t\t{ids["products"]} /* Products */ = {{')
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f'\t\t\t\t{ids["app_product"]} /* {APP_NAME}.app */,')
    add(f'\t\t\t\t{ids["test_product"]} /* {TEST_NAME}.xctest */,')
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")
    add("/* End PBXGroup section */")

    add("\n/* Begin PBXNativeTarget section */")
    add(f'\t\t{ids["app_target"]} /* {APP_NAME} */ = {{')
    add("\t\t\tisa = PBXNativeTarget;")
    add(f'\t\t\tbuildConfigurationList = {ids["app_configs"]};')
    add("\t\t\tbuildPhases = (")
    add(f'\t\t\t\t{ids["app_sources"]} /* Sources */,')
    add(f'\t\t\t\t{ids["app_frameworks"]} /* Frameworks */,')
    add(f'\t\t\t\t{ids["app_resources"]} /* Resources */,')
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add(f"\t\t\tname = {APP_NAME};")
    add(f"\t\t\tproductName = {APP_NAME};")
    add(f'\t\t\tproductReference = {ids["app_product"]} /* {APP_NAME}.app */;')
    add('\t\t\tproductType = "com.apple.product-type.application";')
    add("\t\t};")

    add(f'\t\t{ids["test_target"]} /* {TEST_NAME} */ = {{')
    add("\t\t\tisa = PBXNativeTarget;")
    add(f'\t\t\tbuildConfigurationList = {ids["test_configs"]};')
    add("\t\t\tbuildPhases = (")
    add(f'\t\t\t\t{ids["test_sources"]} /* Sources */,')
    add(f'\t\t\t\t{ids["test_frameworks"]} /* Frameworks */,')
    add(f'\t\t\t\t{ids["test_resources"]} /* Resources */,')
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add(f'\t\t\t\t{ids["dependency"]} /* PBXTargetDependency */,')
    add("\t\t\t);")
    add(f"\t\t\tname = {TEST_NAME};")
    add(f"\t\t\tproductName = {TEST_NAME};")
    add(f'\t\t\tproductReference = {ids["test_product"]} /* {TEST_NAME}.xctest */;')
    add('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
    add("\t\t};")
    add("/* End PBXNativeTarget section */")

    add("\n/* Begin PBXProject section */")
    add(f'\t\t{ids["project"]} /* Project object */ = {{')
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    add("\t\t\t\tLastUpgradeCheck = 1500;")
    add("\t\t\t\tTargetAttributes = {")
    add(f'\t\t\t\t\t{ids["app_target"]} = {{')
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add("\t\t\t\t\t};")
    add(f'\t\t\t\t\t{ids["test_target"]} = {{')
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add(f'\t\t\t\t\t\tTestTargetID = {ids["app_target"]};')
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f'\t\t\tbuildConfigurationList = {ids["project_configs"]};')
    add("\t\t\tdevelopmentRegion = fr;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\tfr,")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f'\t\t\tmainGroup = {ids["main_group"]};')
    add(f'\t\t\tproductRefGroup = {ids["products"]} /* Products */;')
    add('\t\t\tprojectDirPath = "";')
    add('\t\t\tprojectRoot = "";')
    add("\t\t\ttargets = (")
    add(f'\t\t\t\t{ids["app_target"]} /* {APP_NAME} */,')
    add(f'\t\t\t\t{ids["test_target"]} /* {TEST_NAME} */,')
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")

    add("\n/* Begin PBXResourcesBuildPhase section */")
    for key, files, target in (
        ("app_resources", app_files, APP_NAME),
        ("test_resources", test_files, TEST_NAME),
    ):
        add(f'\t\t{ids[key]} /* Resources */ = {{')
        add("\t\t\tisa = PBXResourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for line in phase_children(files, target, (".xcassets",)):
            add(line)
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")

    add("\n/* Begin PBXSourcesBuildPhase section */")
    for key, files, target in (
        ("app_sources", app_files, APP_NAME),
        ("test_sources", test_files, TEST_NAME),
    ):
        add(f'\t\t{ids[key]} /* Sources */ = {{')
        add("\t\t\tisa = PBXSourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for line in phase_children(files, target, (".swift",)):
            add(line)
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")

    add("\n/* Begin PBXTargetDependency section */")
    add(f'\t\t{ids["dependency"]} /* PBXTargetDependency */ = {{')
    add("\t\t\tisa = PBXTargetDependency;")
    add(f'\t\t\ttarget = {ids["app_target"]} /* {APP_NAME} */;')
    add(f'\t\t\ttargetProxy = {ids["proxy"]} /* PBXContainerItemProxy */;')
    add("\t\t};")
    add("/* End PBXTargetDependency section */")

    add("\n/* Begin XCBuildConfiguration section */")
    for scope, extra in (("project", None), (APP_NAME, APP_SETTINGS), (TEST_NAME, TEST_SETTINGS)):
        for name, debug in (("Debug", True), ("Release", False)):
            key = f'{scope}_{name.lower()}'
            add(f'\t\t{ids[key]} /* {name} */ = {{')
            add("\t\t\tisa = XCBuildConfiguration;")
            add("\t\t\tbuildSettings = {")
            if scope == "project":
                add(common_settings(debug))
            else:
                add(extra)
            add("\t\t\t};")
            add(f"\t\t\tname = {name};")
            add("\t\t};")
    add("/* End XCBuildConfiguration section */")

    add("\n/* Begin XCConfigurationList section */")
    for scope, key in (("project", "project_configs"), (APP_NAME, "app_configs"), (TEST_NAME, "test_configs")):
        add(f'\t\t{ids[key]} = {{')
        add("\t\t\tisa = XCConfigurationList;")
        add("\t\t\tbuildConfigurations = (")
        add(f'\t\t\t\t{ids[f"{scope}_debug"]} /* Debug */,')
        add(f'\t\t\t\t{ids[f"{scope}_release"]} /* Release */,')
        add("\t\t\t);")
        add("\t\t\tdefaultConfigurationIsVisible = 0;")
        add("\t\t\tdefaultConfigurationName = Release;")
        add("\t\t};")
    add("/* End XCConfigurationList section */")

    add("\t};")
    add(f'\trootObject = {ids["project"]} /* Project object */;')
    add("}")

    target_file = ROOT / f"{APP_NAME}.xcodeproj" / "project.pbxproj"
    target_file.parent.mkdir(parents=True, exist_ok=True)
    target_file.write_text("\n".join(out) + "\n")

    scheme = ROOT / f"{APP_NAME}.xcodeproj" / "xcshareddata" / "xcschemes" / f"{APP_NAME}.xcscheme"
    scheme.parent.mkdir(parents=True, exist_ok=True)
    scheme.write_text(SCHEME_TEMPLATE.format(app=ids["app_target"], test=ids["test_target"], name=APP_NAME, tests=TEST_NAME))

    print(f"{target_file.relative_to(ROOT)}: {len(app_files)} app files, {len(test_files)} test files.")
    return 0


SCHEME_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
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
               BlueprintIdentifier = "{app}"
               BuildableName = "{name}.app"
               BlueprintName = "{name}"
               ReferencedContainer = "container:{name}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test}"
               BuildableName = "{tests}.xctest"
               BlueprintName = "{tests}"
               ReferencedContainer = "container:{name}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
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
            BlueprintIdentifier = "{app}"
            BuildableName = "{name}.app"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{name}.xcodeproj">
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
            BlueprintIdentifier = "{app}"
            BuildableName = "{name}.app"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{name}.xcodeproj">
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

if __name__ == "__main__":
    sys.exit(main())
