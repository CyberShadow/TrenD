module dietbench;

import core.vararg;
import std.algorithm;
import std.ascii : isAlpha;
import std.array;
import std.conv;
import std.format;
import std.range;
import std.string;
import std.traits;
import std.typecons;
import std.typetuple;
import std.variant;

class OutputStream
{
    void write(string str)
    {
    }

    void write(in ubyte[] bytes)
    {
    }
}

void main()
{
    enum src = `doctype 5
html
	- auto title = "Package format";
	title= title
body
	h2 Introduction

	p Every DUB package <em>should</em> contain a <code>dub.json</code> (was <code>package.json</code> in earlier versions) file in its root folder. This file contains meta-information about the project and its dependencies. This information is used for building the project and for deploying it using the registry. The following sections give an overview of the recognized fields and their meaning. Note that any unknown fields are ignored for backwards compatibility reasons.

	p A typical example of a simple application that requires no platform specific setup:

	pre.code
		|{
		|	"name": "myproject",
		|	"description": "A little web service of mine.",
		|	"authors": ["Peter Parker"],
		|	"homepage": "http://myproject.example.com",
		|	"license": "GPL-2.0",
		|	"dependencies": {
		|		"vibe-d": "~>0.7.23"
		|	}
		|}

	p Please keep the description concise (not more than 100 characters) and avoid including unspecific information such as the fact that the package is written in D. The same goes for the package name - since <em>all</em> DUB packages are written in D, it's usually better to avoid mentioning D explicitly, unless the package is for example a high-level wrapper around a C/C++ library.

	h2 Contents

	nav
		ul
			li
				a(href="#standard-fields") Global Fields
				ul
					li
						a(href="#sub-packages") Sub packages
					li
						a(href="#licenses") License specifications
			li
				a(href="#build-settings") Build settings
				ul
					li
						a(href="#version-specs") Version specifications
					li
						a(href="#target-types") Target types
					li
						a(href="#build-requirements") Build requirements
					li
						a(href="#build-options") Build options
			li
				a(href="#configurations") Configurations
				ul
					li
						a(href="#configuration-fields") Specific fields
			li
				a(href="#build-types") Build types



	h2#standard-fields Global fields

	p In addition to the fields listed here, all <a href="#build-settings">build settings fields</a> are allowed at the global scope.

	table
		tr
			th Name
			th Type
			th Description

		tr
			td name [required]
			td
				code string
			td Name of the package, used to uniquely identify the package. Must be comprised of only lower case ASCII alpha-numeric characters, "-" or "_".

		tr
			td description [required for publishing]
			td
				code string
			td Brief description of the package

		tr
			td homepage
			td
				code string
			td URL of the project website

		tr
			td authors
			td
				code string[]
			td List of project authors

		tr
			td copyright
			td
				code string
			td Copyright declaration string

		tr
			td license [required for publishing]
			td
				code string
			td License(s) under which the project can be used - see the <a href="#licenses">license specification</a> section for possible values

		tr
			td subPackages
			td
				code T[]
			td Defines an array of sub-packages defined in the same directory as the root project, where each entry is either a path of a sub folder or an object of the same formatas a dub.json file - see the <a href="#sub-packages">sub package section</a> for more information

		tr
			td configurations
			td
				code T[]
			td Speficies an optional list of build configurations (specified using "--config=...") - see the <a href="#configurations">configurations section</a> for more details

		tr
			td buildTypes
			td
				code T[string]
			td Defines additional custom build types or overrides the default ones (specified using "--build=...") - see the <a href="#build-types">build types section</a> for an example

		tr
			td -ddoxFilterArgs
			td
				code string[]
			td Specifies a list of command line flags usable for controlling filter behavior for --build=ddox <span style="color: red;">[experimental]</span>


	h3#sub-packages Sub packages

	p A package may contain an arbitrary number of additional publicly visible packages. These packages can be defined in the <code>"subPackages"</code> field of the main dub.json file. They can be referenced by concatenating their name with the name of the main package using a colon as a delimiter (i.e. <code>"main-package-name:sub-package-name"</code>).

	p The typical use for this feature is to split up a library into a number of parts without breaking it up into different code repositories:

	pre.code
		|{
		|	"name": "mylib",
		|	"targetType": "none",
		|	"dependencies": {
		|		"mylib:component1": "*",
		|		"mylib:component2": "*"
		|	},
		|	"subPackages": [
		|		"./component1/",
		|		"./component2/"
		|	]
		|}
	p <code>/dub.json</code>

	pre.code
		|{
		|	"name": "component1",
		|	"targetType": "library"
		|}
	p <code>/component1/dub.json</code>

	p The sub directories /component1 and /component2 then contain normal packages and can be referred to as "mylib:component1" and "mylib:component2" from outside projects. To refer to sub packages within the same repository use the <code>"*"</code> version specifier.

	p It is also possible to define the sub packages within the root package file, but note that it is generally discouraged to put the source code of multiple sub packages into the same source folder. Doing so can lead to hidden dependencies to sub packages that haven't been explicitly stated in the "dependencies" section. These hidden dependencies can then result in build errors in conjunction with certain build modes or dependency trees that may be hard to understand.

	pre.code
		|{
		|	"name": "mylib",
		|	"targetType": "none",
		|	"dependencies": {
		|		"mylib:component1": "*",
		|		"mylib:component2": "*"
		|	},
		|	"subPackages": [
		|		{
		|			"name": "component1",
		|			"targetType": "library",
		|			"sourcePaths": ["component1/source"],
		|			"importPaths": ["component1/source"]
		|		}
		|	]
		|}
	p <code>/dub.json</code>


	h3#licenses License specifications

	p The license field should only contain one of the standard license identifiers if possible. At a later point in time, DUB may use this information to validate proper licensing in dependency hierarchies and output warnings when licenses don't match up. Multiple licenses can be separated using the term "or" and for versioned licenses, the postfix "or later" is allowed to also include any later version of the same license.

	p The standard license identifiers are:
		|<code>public domain</code>,
		|<code>AFL-3.0</code> (Academic Free License 3.0),
		|<code>AGPL-3.0</code> (Affero GNU Public License 3.0),
		|<code>Apache-2.0</code>,
		|<code>APSL-2.0</code> (Apple Public Source License),
		|<code>Artistic-2.0</code>,
		|<code>BSL-1.0</code> (Boost Software License),
		|<code>BSD 2-clause</code>,
		|<code>BSD 3-clause</code>,
		|<code>EPL-1.0</code> (Eclipse Public License),
		|<code>GPL-2.0</code>,
		|<code>GPL-3.0</code>,
		|<code>ISC</code>,
		|<code>LGPL-2.1</code>,
		|<code>LGPL-3.0</code>,
		|<code>MIT</code>,
		|<code>MPL-2.0</code> (Mozilla Public License 2.0),
		|<code>MS-PL</code> (Microsoft Public License),
		|<code>MS-RL</code> (Microsoft Reciprocal License),
		|<code>OpenSSL</code> (OpenSSL License),
		|<code>SSLeay</code> (SSLeay License),
		|<code>Zlib</code> (zlib/libpng License)

	p Any other value is considered to be a proprietary license, which is assumed to be incompatible with any other license. If you think there is a license that should be included in this list, please file a quick <a href="https://github.com/rejectedsoftware/dub-registry/issues/new">bug report</a>. Please also note that pure D bindings of C/C++ libraries <em>should</em> specify the same license as the original library, although a stricter but compatible license can be used, too.

	p Some example license specifications:
	pre.code
		|"GPL-3.0"
		|"GPL-2.0 or later"
		|"GPL-2.0 or later or proprietary"
		|"GPL-2.0 or LGPL-3.0"
		|"LGPL-2.1 or proprietary"

	h2#build-settings Build settings

	p Build settings fields influence the command line options passed to the compiler and linker. All fields are optional.

	p Platform specific settings are supported through the use of field name suffixes. Suffixes are dash separated platform identifiers, as defined in the <a href="http://dlang.org/version.html#PredefinedVersions">D language reference</a>, but converted to lower case. The order of these suffixes is <code>os-architecture-compiler</code>, where any of these parts can be left off. Examples:

	pre.code
		|{
		|	"versions": ["PrintfDebugging"],
		|	"dflags-dmd": ["-vtls"],
		|	"versions-x86_64": ["UseAmd64Impl"]
		|	"libs-posix": ["ssl", "crypto"],
		|	"sourceFiles-windows-x86_64-dmd": ["lib/win32/mylib.lib"],
		|}

	table
		tr
			th Name
			th Type
			th Description

		tr
			td dependencies
			td
				code T[string]
			td List of project dependencies given as pairs of <code>"&lt;name&gt;" : &lt;version-spec&gt;</code> - see <a href="#version-specs">next section</a> for how version specifications look like

		tr
			td systemDependencies
			td
				code string
			td A textual description of the required system dependencies (external C libraries) required by the package. This will be visible on the registry and will be displayed in case of linker errors.

		tr
			td targetType
			td
				code string
			td Specifies a specific <a href="#target-types">target type</a> - this field does not support platform suffixes

		tr
			td targetName
			td
				code string
			td Sets the base name of the output file; type and platform specific pre- and suffixes are added automatically - this field does not support platform suffixes

		tr
			td targetPath
			td
				code string
			td The destination path of the output binary - this field does not support platform suffixes

		tr
			td workingDirectory
			td
				code string
			td A fixed working directory from which the generated executable will be run - this field does not support platform suffixes

		tr
			td subConfigurations
			td
				code string[string]
			td Locks the dependencies to specific configurations; a map from package name to configuration name, see also the <a href="#configurations">configurations section</a> - this field does not support platform suffixes

		tr
			td buildRequirements
			td
				code string[]
			td List of required settings for the build process. See the <a href="#build-requirements">build requirements section</a> for details.

		tr
			td buildOptions
			td
				code string[]
			td List of build option identifiers (corresponding to compiler flags) - see the <a href="#build-options">build options section</a> for details.

		tr
			td libs
			td
				code string[]
			td A list of external library names - depending on the compiler, these will be converted to the proper linker flag (e.g. "ssl" might get translated to "-L-lssl")

		tr
			td sourceFiles
			td
				code string[]
			td Additional files passed to the compiler - can be useful to add certain configuration dependent source files that are not contained in the general source folder

		tr
			td sourcePaths
			td
				code string[]
			td Allows to customize the path where to look for source files (any folder "source" or "src" is automatically used as a source path if no <code>sourcePaths</code> field is given) - note that you usually also need to define <code>"importPaths"</code> as <code>"sourcePaths"</code> don't influence those

		tr
			td excludedSourceFiles
			td
				code string[]
			td Files that should be removed for the set of already added source files (takes precedence over "sourceFiles" and "sourcePaths") - <a href="http://dlang.org/phobos/std_path.html#.globMatch">Glob matching</a> can be used to pattern match multiple files at once

		tr
			td mainSourceFile
			td
				code string
			td Determines the file that contains the <code>main()</code> function. This field can be used by dub to exclude this file in situations where a different main function is defined (e.g. for "dub test") - this field does not support platform suffixes

		tr
			td copyFiles
			td
				code string[]
			td A list of <a href="http://dlang.org/phobos/std_path.html#.globMatch">globs</a> matching files or directories to be copied to <code>targetPath</code>. Matching directories are copied recursively, i.e. <code>"copyFiles": ["path/to/dir"]"</code> recursively copies <code>dir</code>, while <code>"copyFiles": ["path/to/dir/*"]"</code> only copies files within <code>dir</code>.

		tr
			td versions
			td
				code string[]
			td A list of D versions to be defined during compilation

		tr
			td debugVersions
			td
				code string[]
			td A list of D debug identifiers to be defined during compilation

		tr
			td importPaths
			td
				code string[]
			td Additional import paths to search for D modules (the <code>source/</code> folder is used by default as a source folder, if it exists)

		tr
			td stringImportPaths
			td
				code string[]
			td Additional import paths to search for string imports/views (the <code>views/</code> folder is used by default as a string import folder, if it exists)
		tr
			td preGenerateCommands
			td
				code string[]
			td A list of shell commands that is executed before project generation is started
		tr
			td postGenerateCommands
			td
				code string[]
			td A list of shell commands that is executed after project generation is finished
		tr
			td preBuildCommands
			td
				code string[]
			td A list of shell commands that is executed always before the project is built
		tr
			td postBuildCommands
			td
				code string[]
			td A list of shell commands that is executed always after the project is built

		tr
			td dflags
			td
				code string[]
			td Additional flags passed to the D compiler - note that these flags are usually specific to the compiler in use, but a set of flags is automatically translated from DMD to the selected compiler

		tr
			td lflags
			td
				code string[]
			td Additional flags passed to the linker - note that these flags are usually specific to the linker in use

	p Inside of build setting values, it is possible to use variables using dollar notation. Any variable not matching a predefined name will be taken from the program environment. To denote a literal dollar sign, use <code>$$</code>. The predefined variables are:
	table
		tr
			th Variable
			th Contents
		tr
			td <code>$PACKAGE_DIR</code>
			td Path to the package itself
		tr
			td <code>$ROOT_PACKAGE_DIR</code>
			td Path to the root package of the build dependency tree
		tr
			td <code>$&lt;name&gt;_PACKAGE_DIR</code>
			td Path to the package named <code>&lt;name&gt;</code> (needs to be part of the build dependency tree)


	h3#version-specs Version specifications
	p A version specification can either be a simple declaration or a more complex variant, allowing more control.

	ul
		li Simple variant:
			p <code>"&lt;name&gt;" : "&lt;version-specifier&gt;"</code>
			p This is the usual way to specify a dependency.

		li Complex variant:
			p <code>"&lt;name&gt;" : { "&lt;field&gt;": "&lt;value&gt;"[, ...] }</code>
			p The following fields can be used to to control how a dependency is resolved:
			ul
				li
					p <code>"version": "&lt;version-specifier&gt;"</code> - The version specification as used for the simple form
					p A version specification should only be specified when no <code>"path"</code> field is present, or when compatibility with older versions of DUB (&lt; 0.9.22) is desired.
				li
					p <code>"path": "&lt;path-to-package&gt;"</code> - Use a folder to source a package from.
					p References a package in a specific path. This can be used in situations where a specific copy of a package needs to be used. Examples of this include packages that are included as GIT submodules, or packages in sub folders of the main package, such as example projects.
				li
					p <code>"optional": true</code> - Indicate an optional dependency.
					p With this specified, the dependency will only be used, if it is already available on the local machine.

	p Version specifiers define a range of acceptable versions. They can be specified in any of the following ways:
	ul
		li Restrict to a certain minor version: <code>"~&gt;2.2.13"</code>, equivalent to <code>"&gt;=2.2.13 &lt;2.3.0"</code>
		li Restrict to a certain major version: <code>"~&gt;2.2"</code>, equivalent to <code>"&gt;=2.2.0 &lt;3.0.0"</code>
		li Require a certain version: <code>"==1.3.0"</code>
		li Require a minimum version: <code>"&gt;=1.3.0"</code>
		li Require a version range: <code>"&gt;=1.3.0 &lt;=1.3.4"</code>
		li Match any released version (equivalent to <code>">=0.0.0"</code>): <code>"*"</code>
		li Use a GIT branch (deprecated): <code>"~master"</code>
	
	p Numbered versions are formatted and compared according to the <a href="http://semver.org/">SemVer specification</a>. The recommended way to specify versions is using the <code>~&gt;</code> operator as a way to balance between flexible upgrades and reducing the risk of code breakage.

	p Whenever you refer to (sub) packages within the same repository, use the "any version" version specifier: <code>"*"</code>


	h3#target-types Target types

	p The following values are recognized for the <code>"targetType"</code> field:

	table
		tr
			th Value
			th Description
		tr
			td "autodetect"
			td Automatically detects the target type. This is the default global value and causes dub to try and generate "application" and "library" <a href="#configurations">configurations</a>. Use of other values limits the auto-generated configurations to either of the two. This value is not allowed inside of a configuration block.

		tr
			td "none"
			td Does not generate an output file. This is useful for packages that are supposed to drag in other packages using its "dependencies" field.

		tr
			td "executable"</code>
			td Generates an executable binary

		tr
			td "library"</code>
			td Specifies that the package is to be used as a library, without limiting the actual type of library. This should be the default for most libraries.

		tr
			td "sourceLibrary"</code>
			td This target type does not generate a binary, but rather forces dub to add all source files directly to the same compiler invocation as the dependent project.

		tr
			td "staticLibrary"</code>
			td Forces output as a static library container.

		tr
			td "dynamicLibrary"</code>
			td Forces output as a dynamic/shared library.

	h3#build-requirements Build requirements

	p The following values are recognized as array items in the "buildRequirements" field:

	table
		tr
			th Value
			th Description
		tr
			td "allowWarnings"
			td Warnings do not abort compilation
		tr
			td "silenceWarnings"
			td Don't show warnings
		tr
			td "disallowDeprecations"
			td Using deprecated features aborts compilation
		tr
			td "silenceDeprecations"
			td Don't show deprecation warnings
		tr
			td "disallowInlining"
			td Avoid function inlining, even in release builds
		tr
			td "disallowOptimization"
			td Avoid optimizations, even in release builds
		tr
			td "requireBoundsCheck"
			td Always perform bounds checks
		tr
			td "requireContracts"
			td Leave assertions and contracts enabled in release builds
		tr
			td "relaxProperties"
			td Do not enforce strict property handling (removes the -property switch) <span style="color: red;">[deprecated, recent versions of DUB never issue -property]</span>
		tr
			td "noDefaultFlags"
			td Does not emit build type specific flags (e.g. -debug, -cov or -unittest). <span style="color: red;">Note that this flag should never be used for released packages and is indended purely as a development/debugging tool. Using "-build=plain" may also be a more appropriate alternative.</span>

	h3#build-options Build options

	p The "buildOptions" field provides a compiler agnostic way to specify common compiler options/flags. Note that many of these options are implicitly managed by the <a href="#build-requirements">"buildRequirements"</a> field and most others usually only occur in <a href="#custom-build-types">"buildTypes"</a> blocks. It supports the following values:

	table
		tr
			th Value
			th Description
			th Corresponding DMD flag
		tr
			td "debugMode"
			td Compile in debug mode (enables contracts)
			td -debug
		tr
			td "releaseMode"
			td Compile in release mode (disables assertions and bounds checks)
			td -release
		tr
			td "coverage"
			td Enable code coverage analysis
			td -cov
		tr
			td "debugInfo"
			td Enable symbolic debug information
			td -g
		tr
			td "debugInfoC"
			td Enable symbolic debug information in C compatible form
			td -gc
		tr
			td "alwaysStackFrame"
			td Always generate a stack frame
			td -gs
		tr
			td "stackStomping"
			td Perform stack stomping
			td -gx
		tr
			td "inline"
			td Perform function inlining
			td -inline
		tr
			td "noBoundsCheck"
			td Disable all bounds checking
			td -noboundscheck
		tr
			td "optimize"
			td Enable optimizations
			td -O
		tr
			td "profile"
			td Emit profiling code
			td -profile
		tr
			td "unittests"
			td Compile unit tests
			td -unittest
		tr
			td "verbose"
			td Verbose compiler output
			td -v
		tr
			td "ignoreUnknownPragmas"
			td Ignores unknown pragmas during compilation
			td -ignore
		tr
			td "syntaxOnly"
			td Don't generate object files
			td -o-
		tr
			td "warnings"
			td Enable warnings, enabled by default (use "buildRequirements" to control this setting)
			td -wi
		tr
			td "warningsAsErrors"
			td Treat warnings as errors (use "buildRequirements" to control this setting)
			td -w
		tr
			td "ignoreDeprecations"
			td Do not warn about using deprecated features (use "buildRequirements" to control this setting)
			td -d
		tr
			td "deprecationWarnings"
			td Warn about using deprecated features, enabled by default (use "buildRequirements" to control this setting)
			td -dw
		tr
			td "deprecationErrors"
			td Stop compilation upon usage of deprecated features (use "buildRequirements" to control this setting)
			td -de
		tr
			td "property"
			td Enforce property syntax - <span style="color: red;">deprecated</span>
			td -property


	h2#configurations Configurations

	p In addition to platform specific build settings, it is possible to define build configurations. Build configurations add or override build settings to the global ones. To choose a configuration, use <code>dub --config=&lt;name&gt;</code>. By default, the first configuration that matches the target type and build platform is selected automatically. The configurations are defined by adding a "configurations" field.

	p If no configurations are specified, dub automatically tries to detect the two default configurations "application" and "library". The "application" configuration is only added if at least one of the following files is found: <code>source/app.d</code>, <code>source/main.d</code>, <code>source/&lt;package name&gt;/app.d</code>, <code>source/&lt;package name&gt;/main.d</code>, <code>src/app.d</code>, <code>src/main.d</code>, <code>src/&lt;package name&gt;/app.d</code>, <code>src/&lt;package name&gt;/main.d</code>. Those files are expected to contain only the application entry point (usually <code>main()</code>) and are only added to the "application" configuration.

	p When defining a configuration's platform, any of the suffixes described in <a href="#build-settings">build settings</a> may be combined to make the configuration as specific as necessary.

	p The following example defines "metro-app" and "desktop-app" configurations that are only available on Windows and a "glut-app" configuration that is available on all platforms.

	pre.code
		|{
		|	...
		|	"name": "somepackage"
		|	"configurations": [
		|		{
		|			"name": "metro-app",
		|			"targetType": "executable",
		|			"platforms": ["windows"],
		|			"versions": ["MetroApp"],
		|			"libs": ["d3d11"]
		|		},
		|		{
		|			"name": "desktop-app",
		|			"targetType": "executable",
		|			"platforms": ["windows"],
		|			"versions": ["DesktopApp"],
		|			"libs": ["d3d9"]
		|		},
		|		{
		|			"name": "glut-app",
		|			"targetType": "executable",
		|			"versions": ["GlutApp"]
		|		}
		|	]
		|}

	p You can choose a specific configuration for certain dependencies by using the "subConfigurations" field:

	pre.code
		|{
		|	...
		|	"dependencies": {
		|		"somepackage": ">=1.0.0"
		|	},
		|	"subConfigurations": {
		|		"somepackage": "glut-app"
		|	}
		|}

	p If no configuration is specified for a package, the first one that matches the current platform is chosen (see the "platforms" field below).


	h3#configuration-fields Configuration block specific fields

	p In addition to the usual <a href="#build-settings">build settings</a>, the following fields are recognized inside of a configuration block:

	table
		tr
			th Name
			th Type
			th Description

		tr
			td name [required]
			td
				code string
			td Name of the configuration
		tr
			td platforms
			td
				code string[]
			td A list of platform suffixes (as used for the build settings) to limit on which platforms the configuration applies

	h2#build-types Build types

	p By default, a set of predefined build types is already provided by DUB and can be specified using <code>dub build --build=&lt;name&gt;</code>:

	table
		tr
			th Name
			th Build options
		tr
			td plain
			td <code>[]</code>
		tr
			td debug
			td <code>["debugMode", "debugInfo"]</code>
		tr
			td release
			td <code>["releaseMode", "optimize", "inline"]</code>
		tr
			td unittest
			td <code>["unittests", "debugMode", "debugInfo"]</code>
		tr
			td docs
			td <code>["syntaxOnly"]</code>, plus <code>"dflags": ["-c", "-Dddocs"]</code>
		tr
			td ddox
			td <code>["syntaxOnly"]</code>, plus <code>"dflags": ["-c", "-Df__dummy.html", "-Xfdocs.json"]</code>
		tr
			td profile
			td <code>["profile", "optimize", "inline", "debugInfo"]</code>
		tr
			td cov
			td <code>["coverage", "debugInfo"]</code>
		tr
			td unittest-cov
			td <code>["unittests", "coverage", "debugMode", "debugInfo"]</code>

	p The existing build types can be customized and new build types can be added using the global <code>"buildTypes"</code> field. Each entry in <code>"buildTypes"</code> can use any of the low level <a href="#build-settings">build settings fields</a> (excluding "dependencies", "targetType", "targetName", "targetPath", "workingDirectory", "subConfigurations"). The build settings specified here will later be modified by the package/configuration specific settings.

	p An example that overrides the "debug" build type and defines a new "debug-profile" type:

	pre.code
		|{
		|	"name": "my-package",
		|	"buildTypes": {
		|		"debug": {
		|			"buildOptions": ["debugMode", "debugInfo", "optimize"]
		|		},
		|		"debug-profile": {
		|			"buildOptions": ["debugMode", "debugInfo", "profile"]
		|		}
		|	}
		|}
`;

    auto dst = new OutputStream;
    compileDietString!(src)(dst);
}

void compileDietString(string diet_code, ALIASES...)(OutputStream stream__)
{
    // some imports to make available by default inside templates
    import std.typetuple;

    //pragma(msg, localAliases!(0, ALIASES));
    mixin(localAliases!(0, ALIASES));

    // Generate the D source code for the diet template
    static if (is(typeof(diet_translate__)))
        alias TRANSLATE = TypeTuple!(diet_translate__);
    else
        alias TRANSLATE = TypeTuple!();

    auto output__ = StreamOutputRange(stream__);

    //pragma(msg, dietStringParser!(diet_code, "__diet_code__", TRANSLATE)(0));
    mixin(dietStringParser!(Group!(diet_code, "__diet_code__"), TRANSLATE)(0));
}

/**
	The same as $(D compileDietStrings), but taking multiple source codes as a $(D Group).
*/
/*private void compileDietStrings(SOURCE_AND_ALIASES...)(OutputStream stream__)
	if (SOURCE_AND_ALIASES.length >= 1 && isGroup!(SOURCE_AND_ALIASES[0]))
{
	// some imports to make available by default inside templates
	import vibe.http.common;
	import vibe.stream.wrapper;
	import vibe.utils.string;
	import std.typetuple;

	//pragma(msg, localAliases!(0, ALIASES));
	mixin(localAliases!(0, SOURCE_AND_ALIASES[1 .. $]));

	// Generate the D source code for the diet template
	static if (is(typeof(diet_translate__))) alias TRANSLATE = TypeTuple!(diet_translate__);
	else alias TRANSLATE = TypeTuple!();

	auto output__ = StreamOutputRange(stream__);

	//pragma(msg, dietStringParser!(diet_code, "__diet_code__", TRANSLATE)(0));
	mixin(dietStringParser!(SOURCE_AND_ALIASES[0], TRANSLATE)(0));
}*/

private
{
    enum string OutputVariableName = "output__";
}

private string dietParser(string template_file, TRANSLATE...)(size_t base_indent)
{
    TemplateBlock[] files;
    readFileRec!(template_file)(files);
    auto compiler = DietCompiler!TRANSLATE(&files[0], &files, new BlockStore);
    return compiler.buildWriter(base_indent);
}

private string dietStringParser(TEXT_NAME_PAIRS_AND_TRANSLATE...)(size_t base_indent) if (
        TEXT_NAME_PAIRS_AND_TRANSLATE.length >= 1 && isGroup!(TEXT_NAME_PAIRS_AND_TRANSLATE[0]))
{
    alias TEXT_NAME_PAIRS = TypeTuple!(TEXT_NAME_PAIRS_AND_TRANSLATE[0].expand);
    static if (TEXT_NAME_PAIRS_AND_TRANSLATE.length >= 2)
        alias TRANSLATE = TEXT_NAME_PAIRS_AND_TRANSLATE[1];
    else
        alias TRANSLATE = TypeTuple!();

    enum ROOT_LINES = removeEmptyLines(TEXT_NAME_PAIRS[0], TEXT_NAME_PAIRS[1]);

    TemplateBlock[] files;
    foreach (i, N; TEXT_NAME_PAIRS)
    {
        static if (i % 2 == 1)
        {
            TemplateBlock blk;
            blk.name = N;
            static if (i == 1)
                blk.lines = ROOT_LINES;
            else
                blk.lines = removeEmptyLines(TEXT_NAME_PAIRS[i - 1], N);
            blk.indentStyle = detectIndentStyle(blk.lines);
            files ~= blk;
        }
    }

    readFilesRec!(extractDependencies(ROOT_LINES), extractNames!TEXT_NAME_PAIRS)(files);

    auto compiler = DietCompiler!TRANSLATE(&files[0], &files, new BlockStore);
    return compiler.buildWriter(base_indent);
}

private template extractNames(PAIRS...)
{
    static if (PAIRS.length >= 2)
    {
        alias extractNames = TypeTuple!(PAIRS[1], extractNames!(PAIRS[2 .. $]));
    }
    else
    {
        alias extractNames = TypeTuple!();
    }
}

/******************************************************************************/
/* Reading of input files                                                     */
/******************************************************************************/

private struct TemplateBlock
{
    string name;
    int mode = 0; // -1: prepend, 0: replace, 1: append
    string indentStyle;
    Line[] lines;
}

private class BlockStore
{
    TemplateBlock[] blocks;
}

/// private
private void readFileRec(string FILE, ALREADY_READ...)(ref TemplateBlock[] dst)
{
    static if (!isPartOf!(FILE, ALREADY_READ)())
    {
        enum LINES = removeEmptyLines(import(FILE), FILE);

        TemplateBlock ret;
        ret.name = FILE;
        ret.lines = LINES;
        ret.indentStyle = detectIndentStyle(ret.lines);

        enum DEPS = extractDependencies(LINES);
        dst ~= ret;
        readFilesRec!(DEPS, ALREADY_READ, FILE)(dst);
    }
}

/// private
private void readFilesRec(alias FILES, ALREADY_READ...)(ref TemplateBlock[] dst)
{
    static if (FILES.length > 0)
    {
        readFileRec!(FILES[0], ALREADY_READ)(dst);
        readFilesRec!(FILES[1 .. $], ALREADY_READ, FILES[0])(dst);
    }
}

/// private
private bool isPartOf(string str, STRINGS...)()
{
    foreach (s; STRINGS)
        if (str == s)
            return true;
    return false;
}

private string[] extractDependencies(in Line[] lines)
{
    string[] ret;
    foreach (ref ln; lines)
    {
        auto lnstr = ln.text.ctstrip();
        if (lnstr.startsWith("extends "))
            ret ~= lnstr[8 .. $].ctstrip() ~ ".dt";
    }
    return ret;
}

/******************************************************************************/
/* The Diet compiler                                                          */
/******************************************************************************/

private class OutputContext
{
    enum State
    {
        Code,
        String
    }

    struct Node
    {
        string tag;
        bool inner;
        bool outer;
        alias tag this;
    }

    State m_state = State.Code;
    Node[] m_nodeStack;
    string m_result;
    Line m_line = Line(null, -1, null);
    size_t m_baseIndent;
    bool m_isHTML5;
    bool warnTranslationContext = false;

    this(size_t base_indent = 0)
    {
        m_baseIndent = base_indent;
    }

    void markInputLine(in ref Line line)
    {
        if (m_state == State.Code)
        {
            m_result ~= lineMarker(line);
        }
        else
        {
            m_line = Line(line.file, line.number, null);
        }
    }

    @property size_t stackSize() const
    {
        return m_nodeStack.length;
    }

    void pushNode(string str, bool inner = true, bool outer = true)
    {
        m_nodeStack ~= Node(str, inner, outer);
    }

    void pushDummyNode()
    {
        pushNode("-");
    }

    void popNodes(int next_indent_level, ref bool prepend_whitespaces)
    {
        // close all tags/blocks until we reach the level of the next line
        while (m_nodeStack.length > next_indent_level)
        {
            auto top = m_nodeStack[$ - 1];
            if (top[0] == '-')
            {
                if (top.length > 1)
                {
                    writeCodeLine(top[1 .. $]);
                }
            }
            else if (top.length)
            {
                if (top.inner && prepend_whitespaces && top != "</pre>")
                {
                    writeString("\n");
                    writeIndent(m_nodeStack.length - 1);
                }

                writeString(top);
                prepend_whitespaces = top.outer;
            }
            m_nodeStack.length--;
        }
    }

    // TODO: avoid runtime allocations by replacing htmlEscape/_toString calls with
    //       filtering functions
    void writeRawString(string str)
    {
        enterState(State.String);
        m_result ~= str;
    }

    void writeString(string str)
    {
        writeRawString(dstringEscape(str));
    }

    void writeStringHtmlEscaped(string str)
    {
        writeString(htmlEscape(str));
    }

    void writeIndent(size_t stack_depth = size_t.max)
    {
        import std.algorithm : min;

        string str;
        foreach (i; 0 .. m_baseIndent)
            str ~= '\t';
        foreach (j; 0 .. min(m_nodeStack.length, stack_depth))
            if (m_nodeStack[j][0] != '-')
                str ~= '\t';
        writeRawString(str);
    }

    void writeStringExpr(string str)
    {
        writeCodeLine(OutputVariableName ~ ".put(" ~ str ~ ");");
    }

    void writeStringExprHtmlEscaped(string str)
    {
        writeCodeLine("filterHTMLEscape(" ~ OutputVariableName ~ ", " ~ str ~ ")");
    }

    void writeStringExprHtmlAttribEscaped(string str)
    {
        writeCodeLine("filterHTMLAttribEscape(" ~ OutputVariableName ~ ", " ~ str ~ ")");
    }

    void writeExpr(string str)
    {
        writeCodeLine("_toStringS!(s => " ~ OutputVariableName ~ ".put(s))(" ~ str ~ ");");
    }

    void writeExprHtmlEscaped(string str)
    {
        writeCodeLine("_toStringS!(s => filterHTMLEscape(" ~ OutputVariableName ~ ", s))(" ~ str ~ ");");
    }

    void writeExprHtmlAttribEscaped(string str)
    {
        writeCodeLine(
            "_toStringS!(s => filterHTMLAttribEscape(" ~ OutputVariableName ~ ", s))(" ~ str ~ ");");
    }

    void writeDebugString(string str)
    {
        () {  }();
    }

    void writeCodeLine(string stmt)
    {
        if (!enterState(State.Code))
            m_result ~= lineMarker(m_line);
        m_result ~= stmt ~ "\n";
    }

    private bool enterState(State state)
    {
        if (state == m_state)
            return false;

        if (state != m_state.Code)
            enterState(State.Code);

        final switch (state)
        {
        case State.Code:
            if (m_state == State.String)
                m_result ~= "\");\n";
            else
                m_result ~= ");\n";
            m_result ~= lineMarker(m_line);
            break;
        case State.String:
            m_result ~= OutputVariableName ~ ".put(\"";
            break;
        }

        m_state = state;
        return true;
    }
}

private struct DietCompiler(TRANSLATE...) if (TRANSLATE.length <= 1)
{
    private
    {
        size_t m_lineIndex = 0;
        TemplateBlock* m_block;
        TemplateBlock[]* m_files;
        BlockStore m_blocks;
    }

    @property ref string indentStyle()
    {
        return m_block.indentStyle;
    }

    @property size_t lineCount()
    {
        return m_block.lines.length;
    }

    ref Line line(size_t ln)
    {
        return m_block.lines[ln];
    }

    ref Line currLine()
    {
        return m_block.lines[m_lineIndex];
    }

    ref string currLineText()
    {
        return m_block.lines[m_lineIndex].text;
    }

    Line[] lineRange(size_t from, size_t to)
    {
        return m_block.lines[from .. to];
    }

    @disable this();

    this(TemplateBlock* block, TemplateBlock[]* files, BlockStore blocks)
    {
        m_block = block;
        m_files = files;
        m_blocks = blocks;
    }

    string buildWriter(size_t base_indent)
    {
        auto output = new OutputContext(base_indent);
        buildWriter(output, 0);
        assert(output.m_nodeStack.length == 0, "Template writer did not consume all nodes!?");
        if (output.warnTranslationContext)
            output.writeCodeLine(`pragma(msg, "Warning: No translation context found, ignoring '&' suffixes. Note that you have to use @translationContext in conjunction with vibe.web.web.render() (vibe.http.server.render() does not work) to enable translation support.");`);
        return output.m_result;
    }

    void buildWriter(OutputContext output, int base_level)
    {
        assert(m_blocks !is null, "Trying to compile template with no blocks specified.");

        while (true)
        {
            if (lineCount == 0)
                return;
            auto firstline = line(m_lineIndex);
            auto firstlinetext = firstline.text;

            if (firstlinetext.startsWith("extends "))
            {
                string layout_file = firstlinetext[8 .. $].ctstrip() ~ ".dt";
                auto extfile = getFile(layout_file);
                m_lineIndex++;

                // extract all blocks
                while (m_lineIndex < lineCount)
                {
                    TemplateBlock subblock;

                    // read block header
                    string blockheader = line(m_lineIndex).text;
                    size_t spidx = 0;
                    auto mode = skipIdent(line(m_lineIndex).text, spidx, "");
                    assertp(spidx > 0, "Expected block/append/prepend.");
                    subblock.name = blockheader[spidx .. $].ctstrip();
                    if (mode == "block")
                        subblock.mode = 0;
                    else if (mode == "append")
                        subblock.mode = 1;
                    else if (mode == "prepend")
                        subblock.mode = -1;
                    else
                        assertp(false, "Expected block/append/prepend.");
                    m_lineIndex++;

                    // skip to next block
                    auto block_start = m_lineIndex;
                    while (m_lineIndex < lineCount)
                    {
                        auto lvl = indentLevel(line(m_lineIndex).text, indentStyle,
                            false);
                        if (lvl == 0)
                            break;
                        m_lineIndex++;
                    }

                    // append block to compiler
                    subblock.lines = lineRange(block_start, m_lineIndex);
                    subblock.indentStyle = indentStyle;
                    m_blocks.blocks ~= subblock;

                    //output.writeString("<!-- found block "~subblock.name~" in "~line(0).file ~ "-->\n");
                }

                // change to layout file and start over
                m_block = extfile;
                m_lineIndex = 0;
            }
            else
            {
                auto start_indent_level = indentLevel(firstlinetext, indentStyle);
                //assertp(start_indent_level == 0, "Indentation must start at level zero.");
                buildBodyWriter(output, base_level, start_indent_level);
                break;
            }
        }

        output.enterState(OutputContext.State.Code);
    }

    private void buildBodyWriter(OutputContext output, int base_level, int start_indent_level)
    {
        assert(m_blocks !is null, "Trying to compile template body with no blocks specified.");

        assertp(output.stackSize >= base_level);

        int computeNextIndentLevel()
        {
            return (m_lineIndex + 1 < lineCount ? indentLevel(line(m_lineIndex + 1).text,
                indentStyle, false) - start_indent_level : 0) + base_level;
        }

        bool prepend_whitespaces = true;

        for (; m_lineIndex < lineCount; m_lineIndex++)
        {
            auto curline = line(m_lineIndex);
            output.markInputLine(curline);
            auto level = indentLevel(curline.text, indentStyle) - start_indent_level + base_level;
            assertp(level <= output.stackSize + 1);
            auto ln = unindent(curline.text, indentStyle);
            assertp(ln.length > 0);
            int next_indent_level = computeNextIndentLevel();

            assertp(output.stackSize >= level,
                cttostring(output.stackSize) ~ ">=" ~ cttostring(level));
            assertp(
                next_indent_level <= level + 1,
                "The next line is indented by more than one level deeper. Please unindent accordingly.");

            if (ln[0] == '-')
            { // embedded D code
                assertp(ln[$ - 1] != '{', "Use indentation to nest D statements instead of braces.");
                output.writeCodeLine(ln[1 .. $] ~ "{");
                output.pushNode("-}");
            }
            else if (ln[0] == '|')
            { // plain text node
                buildTextNodeWriter(output, ln[1 .. ln.length], level, prepend_whitespaces);
            }
            else if (ln[0] == '<')
            { // plain text node starting with <
                assertp(next_indent_level <= level,
                    "Child elements for plain text starting with '<' are not supported.");
                buildTextNodeWriter(output, ln, level, prepend_whitespaces);
            }
            else if (ln[0] == ':')
            { // filter node (filtered raw text)
                // find all child lines
                size_t next_tag = m_lineIndex + 1;
                while (next_tag < lineCount && indentLevel(line(next_tag).text,
                        indentStyle, false) - start_indent_level > level - base_level)
                {
                    next_tag++;
                }

                buildFilterNodeWriter(output, ln, curline.number,
                    level + start_indent_level - base_level, lineRange(m_lineIndex + 1,
                    next_tag));

                // skip to the next tag
                //output.pushDummyNode();
                m_lineIndex = next_tag - 1;
                next_indent_level = computeNextIndentLevel();
            }
            else if (ln[0] == '/' && ln.length > 1 && ln[1] == '/')
            { // all sorts of comments
                if (ln.length >= 5 && ln[2 .. 5] == "if ")
                { // IE conditional comment
                    size_t j = 5;
                    skipWhitespace(ln, j);
                    buildSpecialTag(output, "!--[if " ~ ln[j .. $] ~ "]", level);
                    output.pushNode("<![endif]-->");
                }
                else
                { // HTML and non-output comment
                    auto output_comment = !(ln.length > 2 && ln[2] == '-');
                    if (output_comment)
                    {
                        size_t j = 2;
                        skipWhitespace(ln, j);
                        output.writeString("<!-- " ~ htmlEscape(ln[j .. $]));
                    }
                    size_t next_tag = m_lineIndex + 1;
                    while (next_tag < lineCount
                            && indentLevel(line(next_tag).text, indentStyle, false) - start_indent_level > level - base_level)
                    {
                        if (output_comment)
                        {
                            output.writeString("\n");
                            output.writeStringHtmlEscaped(line(next_tag).text);
                        }
                        next_tag++;
                    }
                    if (output_comment)
                    {
                        output.pushNode(" -->");
                    }

                    // skip to the next tag
                    m_lineIndex = next_tag - 1;
                    next_indent_level = computeNextIndentLevel();
                }
            }
            else
            {
                size_t j = 0;
                auto tag = isAlpha(ln[0]) ? skipIdent(ln, j, ":-_") : "div";

                if (ln.startsWith("!!! "))
                {
                    //output.writeCodeLine(`pragma(msg, "\"!!!\" is deprecated, use \"doctype\" instead.");`);
                    tag = "doctype";
                    j += 4;
                }

                switch (tag)
                {
                default:
                    if (buildHtmlNodeWriter(output, tag, ln[j .. $], level,
                            next_indent_level > level, prepend_whitespaces))
                    {
                        // tag had a '.' appended. treat child nodes as plain text
                        size_t next_tag = m_lineIndex + 1;
                        size_t unindent_count = level + start_indent_level - base_level + 1;
                        size_t last_line_number = curline.number;
                        while (next_tag < lineCount
                                && indentLevel(line(next_tag).text, indentStyle, false) - start_indent_level > level - base_level)
                        {
                            // TODO: output all empty lines between this and the previous one
                            foreach (i; last_line_number + 1 .. line(next_tag).number)
                                output.writeString("\n");
                            last_line_number = line(next_tag).number;
                            buildTextNodeWriter(output,
                                unindent(line(next_tag++).text, indentStyle, unindent_count),
                                level, prepend_whitespaces);
                        }
                        m_lineIndex = next_tag - 1;
                        next_indent_level = computeNextIndentLevel();
                    }
                    break;
                case "doctype": // HTML Doctype header
                    assertp(level == 0, "'doctype' may only be used as a top level tag.");
                    buildDoctypeNodeWriter(output, ln, j, level);
                    assertp(next_indent_level <= level, "'doctype' may not have child tags.");
                    break;
                case "block": // Block insertion place
                    output.pushDummyNode();
                    auto block = getBlock(ln[6 .. $].ctstrip());
                    if (block)
                    {
                        output.writeDebugString(
                            "<!-- using block " ~ ln[6 .. $] ~ " in " ~ curline.file ~ "-->");
                        if (block.mode == 1)
                        {
                            // TODO: output defaults
                            assertp(next_indent_level <= level,
                                "Append mode for blocks is currently not supported.");
                        }
                        auto blockcompiler = new DietCompiler(block, m_files, m_blocks);
                        /*blockcompiler.m_block = block;
							blockcompiler.m_blocks = m_blocks;*/
                        blockcompiler.buildWriter(output, cast(int) output.m_nodeStack.length);

                        if (block.mode != -1)
                        {
                            // skip over the default block contents if the block mode is not prepend

                            // find all child lines
                            size_t next_tag = m_lineIndex + 1;
                            while (next_tag < lineCount
                                    && indentLevel(line(next_tag).text, indentStyle,
                                    false) - start_indent_level > level - base_level)
                            {
                                next_tag++;
                            }

                            // skip to the next tag
                            m_lineIndex = next_tag - 1;
                            next_indent_level = computeNextIndentLevel();
                        }
                    }
                    else
                    {
                        // output defaults
                        output.writeDebugString(
                            "<!-- Default block " ~ ln[6 .. $] ~ " in " ~ curline.file ~ "-->");
                    }
                    break;
                case "include": // Diet file include
                    assertp(next_indent_level <= level,
                        "Child elements for 'include' are not supported.");
                    auto content = ln[8 .. $].ctstrip();
                    if (content.startsWith("#{"))
                    {
                        assertp(content.endsWith("}"), "Missing closing '}'.");
                        output.writeCodeLine(
                            "mixin(dietStringParser!(Group!(" ~ content[2 .. $ - 1] ~ ", \"" ~ replace(content,
                            `"`, `'`) ~ "\"), TRANSLATE)(" ~ to!string(level) ~ "));");
                    }
                    else
                    {
                        output.writeCodeLine(
                            "mixin(dietParser!(\"" ~ content ~ ".dt\", TRANSLATE)(" ~ to!string(
                            level) ~ "));");
                    }
                    break;
                case "script":
                case "style":
                    // determine if this is a plain css/JS tag (without a trailing .) and output a warning
                    // for using deprecated behavior
                    auto tagline = ln[j .. $];
                    HTMLAttribute[] attribs;
                    size_t tli;
                    auto wst = parseHtmlTag(tagline, tli, attribs);
                    tagline = tagline[0 .. tli];
                    if (wst.block_tag)
                        goto default;
                    enum legacy_types = [
                            `"text/css"`, `"text/javascript"`,
                            `"application/javascript"`, `'text/css'`,
                            `'text/javascript'`, `'application/javascript'`
                        ];
                    bool is_legacy_type = true;
                    foreach (i, ref a; attribs)
                        if (a.key == "type")
                        {
                            is_legacy_type = false;
                            foreach (t; legacy_types)
                                if (a.value == t)
                                {
                                    is_legacy_type = true;
                                    break;
                                }
                            break;
                        }
                    if (!is_legacy_type)
                        goto default;

                    if (next_indent_level <= level)
                    {
                        buildHtmlNodeWriter(output, tag, ln[j .. $], level,
                            false, prepend_whitespaces);
                    }
                    else
                    {
                        output.writeCodeLine(
                            `pragma(msg, "` ~ dstringEscape(currLine.file) ~ `:` ~ currLine.number.to!string ~ `: Warning: Use an explicit text block '` ~ tag ~ dstringEscape(
                            tagline) ~ `.' (with a trailing dot) for embedded css/javascript - old behavior will be removed soon.");`);

                        // pass all child lines to buildRawTag and continue with the next sibling
                        size_t next_tag = m_lineIndex + 1;
                        while (next_tag < lineCount
                                && indentLevel(line(next_tag).text, indentStyle, false) - start_indent_level > level - base_level)
                        {
                            next_tag++;
                        }
                        buildRawNodeWriter(output, tag, ln[j .. $], level,
                            base_level, lineRange(m_lineIndex + 1, next_tag));
                        m_lineIndex = next_tag - 1;
                        next_indent_level = computeNextIndentLevel();
                    }
                    break;
                case "each":
                case "for":
                case "if":
                case "unless":
                case "mixin":
                    assertp(false, "'" ~ tag ~ "' is not supported.");
                    break;
                }
            }
            output.popNodes(next_indent_level, prepend_whitespaces);
        }
    }

    private void buildTextNodeWriter(OutputContext output, in string textline,
        int level, ref bool prepend_whitespaces)
    {
        if (prepend_whitespaces)
            output.writeString("\n");
        if (textline.length >= 1 && textline[0] == '=')
        {
            output.writeExprHtmlEscaped(textline[1 .. $]);
        }
        else if (textline.length >= 2 && textline[0 .. 2] == "!=")
        {
            output.writeExpr(textline[2 .. $]);
        }
        else
        {
            buildInterpolatedString(output, textline);
        }
        output.pushDummyNode();
        prepend_whitespaces = true;
    }

    private void buildDoctypeNodeWriter(OutputContext output, string ln, size_t j,
        int level)
    {
        skipWhitespace(ln, j);
        output.m_isHTML5 = false;

        string doctype_str = "!DOCTYPE html";
        switch (ln[j .. $])
        {
        case "5":
        case "":
        case "html":
            output.m_isHTML5 = true;
            break;
        case "xml":
            doctype_str = `?xml version="1.0" encoding="utf-8" ?`;
            break;
        case "transitional":
            doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" ` ~ `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd`;
            break;
        case "strict":
            doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" ` ~ `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"`;
            break;
        case "frameset":
            doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" ` ~ `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"`;
            break;
        case "1.1":
            doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" ` ~ `"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"`;
            break;
        case "basic":
            doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" ` ~ `"http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd"`;
            break;
        case "mobile":
            doctype_str = `!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" ` ~ `"http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd"`;
            break;
        default:
            doctype_str = "!DOCTYPE " ~ ln[j .. $];
            break;
        }
        buildSpecialTag(output, doctype_str, level, false);
    }

    private bool buildHtmlNodeWriter(OutputContext output, in ref string tag,
        in string line, int level, bool has_child_nodes, ref bool prepend_whitespaces)
    {
        // parse the HTML tag, leaving any trailing text as line[i .. $]
        size_t i;
        HTMLAttribute[] attribs;
        auto ws_type = parseHtmlTag(line, i, attribs);

        // determine if we need a closing tag
        bool is_singular_tag = false;
        switch (tag)
        {
        case "area", "base", "basefont", "br", "col", "embed", "frame", "hr",
                "img", "input", "keygen", "link", "meta", "param", "source",
                "track", "wbr":
                is_singular_tag = true;
            break;
        default:
        }
        assertp(!(is_singular_tag && has_child_nodes),
            "Singular HTML element '" ~ tag ~ "' may not have children.");

        // opening tag
        buildHtmlTag(output, tag, level, attribs, is_singular_tag,
            ws_type.outer && prepend_whitespaces);

        // parse any text contents (either using "= code" or as plain text)
        if (i < line.length && line[i] == '=')
        {
            output.writeExprHtmlEscaped(ctstrip(line[i + 1 .. line.length]));
        }
        else if (i + 1 < line.length && line[i .. i + 2] == "!=")
        {
            output.writeExpr(ctstrip(line[i + 2 .. line.length]));
        }
        else
        {
            string rawtext = line[i .. line.length];
            static if (TRANSLATE.length > 0)
            {
                if (ws_type.isTranslated)
                    rawtext = TRANSLATE[0](rawtext);
            }
            else if (ws_type.isTranslated)
                output.warnTranslationContext = true;
            if (hasInterpolations(rawtext))
            {
                buildInterpolatedString(output, rawtext);
            }
            else
            {
                output.writeRawString(sanitizeEscaping(rawtext));
            }
        }

        // closing tag
        if (has_child_nodes)
            output.pushNode("</" ~ tag ~ ">", ws_type.inner, ws_type.outer);
        else if (!is_singular_tag)
            output.writeString("</" ~ tag ~ ">");
        prepend_whitespaces = has_child_nodes ? ws_type.inner : ws_type.outer;

        return ws_type.block_tag;
    }

    private void buildRawNodeWriter(OutputContext output, in ref string tag,
        in string tagline, int level, int base_level, in Line[] lines)
    {
        // parse the HTML tag leaving any trailing text as tagline[i .. $]
        size_t i;
        HTMLAttribute[] attribs;
        parseHtmlTag(tagline, i, attribs);

        // write the tag
        buildHtmlTag(output, tag, level, attribs, false);

        string indent_string = "\t";
        foreach (j; 0 .. output.m_baseIndent)
            indent_string ~= '\t';
        foreach (j; 0 .. level)
            if (output.m_nodeStack[j][0] != '-')
                indent_string ~= '\t';

        // write the block contents wrapped in a CDATA for old browsers
        if (tag == "script")
            output.writeString("\n" ~ indent_string ~ "//<![CDATA[\n");
        else
            output.writeString("\n" ~ indent_string ~ "<!--\n");

        // write out all lines
        void writeLine(string str)
        {
            if (!hasInterpolations(str))
            {
                output.writeString(indent_string ~ str ~ "\n");
            }
            else
            {
                output.writeString(indent_string);
                buildInterpolatedString(output, str);
            }
        }

        if (i < tagline.length)
            writeLine(tagline[i .. $]);
        foreach (j; 0 .. lines.length)
        {
            // remove indentation
            string lnstr = lines[j].text[(level - base_level + 1) * indentStyle.length .. $];
            writeLine(lnstr);
        }
        if (tag == "script")
            output.writeString(indent_string ~ "//]]>\n");
        else
            output.writeString(indent_string ~ "-->\n");
        output.writeString(indent_string[0 .. $ - 1] ~ "</" ~ tag ~ ">");
    }

    private void buildFilterNodeWriter(OutputContext output, in ref string tagline,
        int tagline_number, int indent, in Line[] lines)
    {
        // find all filters
        size_t j = 0;
        string[] filters;
        do
        {
            j++;
            filters ~= skipIdent(tagline, j);
            skipWhitespace(tagline, j);
        }
        while (j < tagline.length && tagline[j] == ':');

        // assemble child lines to one string
        string content = tagline[j .. $];
        int lc = content.length ? tagline_number : tagline_number + 1;
        foreach (i; 0 .. lines.length)
        {
            while (lc < lines[i].number)
            { // DMDBUG: while(lc++ < lines[i].number) silently loops and only executes the last iteration
                content ~= '\n';
                lc++;
            }
            content ~= lines[i].text[(indent + 1) * indentStyle.length .. $];
        }

        auto out_indent = output.m_baseIndent + indent;

        // compile-time filter whats possible
        filter_loop: foreach_reverse (f; filters)
        {
            bool found = true;
            switch (f)
            {
            default:
                found = false;
                break; //break filter_loop;
            case "css":
                content = filterCSS(content, out_indent);
                break;
            case "javascript":
                content = filterJavaScript(content, out_indent);
                break;
            }
            if (found)
                filters.length = filters.length - 1;
            else
                break;
        }

        // the rest of the filtering will happen at run time
        string filter_expr;
        foreach_reverse (flt; filters)
            filter_expr ~= "s_filters[\"" ~ dstringEscape(flt) ~ "\"](";
        filter_expr ~= "\"" ~ dstringEscape(content) ~ "\"";
        foreach (i; 0 .. filters.length)
            filter_expr ~= ", " ~ cttostring(out_indent) ~ ")";

        output.writeStringExpr(filter_expr);
    }

    private auto parseHtmlTag(in ref string line, out size_t i, out HTMLAttribute[] attribs)
    {
        struct WSType
        {
            bool inner = true;
            bool outer = true;
            bool block_tag = false;
            bool isTranslated;
        }

        i = 0;

        string id;
        string classes;

        WSType ws_type;

        // parse #id and .classes
        while (i < line.length)
        {
            if (line[i] == '#')
            {
                i++;
                assertp(id.length == 0, "Id may only be set once.");
                id = skipIdent(line, i, "-_");

                // put #id and .classes into the attribs list
                if (id.length)
                    attribs ~= HTMLAttribute("id", '"' ~ id ~ '"');
            }
            else if (line[i] == '&')
            {
                i++;
                assertp(i >= line.length || line[i] == ' ' || line[i] == '.');
                ws_type.isTranslated = true;
            }
            else if (line[i] == '.')
            {
                i++;
                // check if tag ends with dot
                if (i == line.length || line[i] == ' ')
                {
                    i = line.length;
                    ws_type.block_tag = true;
                    break;
                }
                auto cls = skipIdent(line, i, "-_");
                if (classes.length == 0)
                    classes = cls;
                else
                    classes ~= " " ~ cls;
            }
            else if (line[i] == '(')
            {
                // parse other attributes
                i++;
                parseAttributes(line, i, attribs);
                i++;
            }
            else
                break;
        }

        // parse whitespaces removal tokens
        for (; i < line.length; i++)
        {
            if (line[i] == '<')
                ws_type.inner = false;
            else if (line[i] == '>')
                ws_type.outer = false;
            else
                break;
        }

        // check for multiple occurances of id
        bool has_id = false;
        foreach (a; attribs)
            if (a.key == "id")
            {
                assertp(!has_id, "Id may only be set once.");
                has_id = true;
            }

        // add special attribute for extra classes that is handled by buildHtmlTag
        if (classes.length)
        {
            bool has_class = false;
            foreach (a; attribs)
                if (a.key == "class")
                {
                    has_class = true;
                    break;
                }

            if (has_class)
                attribs ~= HTMLAttribute("$class", classes);
            else
                attribs ~= HTMLAttribute("class", "\"" ~ classes ~ "\"");
        }

        // skip until the optional tag text contents begin
        skipWhitespace(line, i);

        return ws_type;
    }

    private void buildHtmlTag(OutputContext output, in ref string tag, int level,
        ref HTMLAttribute[] attribs, bool is_singular_tag, bool outer_whitespaces = true)
    {
        if (outer_whitespaces)
        {
            output.writeString("\n");
            assertp(output.stackSize >= level);
            output.writeIndent(level);
        }
        output.writeString("<" ~ tag);
        foreach (att; attribs)
        {
            if (att.key[0] == '$')
                continue; // ignore special attributes
            if (isStringLiteral(att.value))
            {
                output.writeString(" " ~ att.key ~ "=\"");
                if (!hasInterpolations(att.value))
                    output.writeString(htmlAttribEscape(dstringUnescape(att.value[1 .. $ - 1])));
                else
                    buildInterpolatedString(output, att.value[1 .. $ - 1], true);

                // output extra classes given as .class
                if (att.key == "class")
                {
                    foreach (a; attribs)
                        if (a.key == "$class")
                        {
                            output.writeString(" " ~ a.value);
                            break;
                        }
                }

                output.writeString("\"");
            }
            else
            {
                output.writeCodeLine(
                    "static if(is(typeof(" ~ att.value ~ ") == bool)){ if(" ~ att.value ~ "){");
                if (!output.m_isHTML5)
                    output.writeString(` ` ~ att.key ~ `="` ~ att.key ~ `"`);
                else
                    output.writeString(` ` ~ att.key);
                output.writeCodeLine(
                    "}} else static if(is(typeof(" ~ att.value ~ ") == string[])){\n");
                output.writeString(` ` ~ att.key ~ `="`);
                output.writeExprHtmlAttribEscaped(`join(` ~ att.value ~ `, " ")`);
                output.writeString(`"`);
                output.writeCodeLine("} else static if(is(typeof(" ~ att.value ~ ") == string)) {");
                output.writeCodeLine("if ((" ~ att.value ~ ") != \"\"){");
                output.writeString(` ` ~ att.key ~ `="`);
                output.writeExprHtmlAttribEscaped(att.value);
                output.writeString(`"`);
                output.writeCodeLine("}");
                output.writeCodeLine("} else {");
                output.writeString(` ` ~ att.key ~ `="`);
                output.writeExprHtmlAttribEscaped(att.value);
                output.writeString(`"`);
                output.writeCodeLine("}");
            }
        }

        output.writeString(is_singular_tag ? "/>" : ">");
    }

    private void parseAttributes(in ref string str, ref size_t i, ref HTMLAttribute[] attribs)
    {
        skipWhitespace(str, i);
        while (i < str.length && str[i] != ')')
        {
            string name = skipIdent(str, i, "-:");
            string value;
            skipWhitespace(str, i);
            if (i < str.length && str[i] == '=')
            {
                i++;
                skipWhitespace(str, i);
                assertp(i < str.length, "'=' must be followed by attribute string.");
                value = skipExpression(str, i);
                assert(i <= str.length);
                if (isStringLiteral(value) && value[0] == '\'')
                {
                    auto tmp = dstringUnescape(value[1 .. $ - 1]);
                    value = '"' ~ dstringEscape(tmp) ~ '"';
                }
            }
            else
                value = "true";

            assertp(i < str.length, "Unterminated attribute section.");
            assertp(str[i] == ')' || str[i] == ',',
                "Unexpected text following attribute: '" ~ str[0 .. i] ~ "' ('" ~ str[i .. $] ~ "')");
            if (str[i] == ',')
            {
                i++;
                skipWhitespace(str, i);
            }

            if (name == "class" && value == `""`)
                continue;
            attribs ~= HTMLAttribute(name, value);
        }

        assertp(i < str.length, "Missing closing clamp.");
    }

    private bool hasInterpolations(in char[] str)
    {
        size_t i = 0;
        while (i < str.length)
        {
            if (str[i] == '\\')
            {
                i += 2;
                continue;
            }
            if (i + 1 < str.length && (str[i] == '#' || str[i] == '!'))
            {
                if (str[i + 1] == str[i])
                {
                    i += 2;
                    continue;
                }
                else if (str[i + 1] == '{')
                {
                    return true;
                }
            }
            i++;
        }
        return false;
    }

    private void buildInterpolatedString(OutputContext output, string str, bool attribute = false)
    {
        size_t start = 0, i = 0;
        while (i < str.length)
        {
            // check for escaped characters
            if (str[i] == '\\')
            {
                if (i > start)
                {
                    if (attribute)
                        output.writeString(htmlAttribEscape(str[start .. i]));
                    else
                        output.writeString(str[start .. i]);
                }
                if (attribute)
                    output.writeString(
                        htmlAttribEscape(dstringUnescape(sanitizeEscaping(str[i .. i + 2]))));
                else
                    output.writeRawString(sanitizeEscaping(str[i .. i + 2]));
                i += 2;
                start = i;
                continue;
            }

            if ((str[i] == '#' || str[i] == '!') && i + 1 < str.length)
            {
                bool escape = str[i] == '#';
                if (i > start)
                {
                    if (attribute)
                        output.writeString(htmlAttribEscape(str[start .. i]));
                    else
                        output.writeString(str[start .. i]);
                    start = i;
                }
                assertp(str[i + 1] != str[i], "Please use \\ to escape # or ! instead of ## or !!.");
                if (str[i + 1] == '{')
                {
                    i += 2;
                    auto expr = dstringUnescape(skipUntilClosingBrace(str, i));
                    if (escape && !attribute)
                        output.writeExprHtmlEscaped(expr);
                    else if (escape)
                        output.writeExprHtmlAttribEscaped(expr);
                    else
                        output.writeExpr(expr);
                    i++;
                    start = i;
                }
                else
                    i++;
            }
            else
                i++;
        }

        if (i > start)
        {
            if (attribute)
                output.writeString(htmlAttribEscape(str[start .. i]));
            else
                output.writeString(str[start .. i]);
        }
    }

    private string skipIdent(in ref string s, ref size_t idx, string additional_chars = null)
    {
        size_t start = idx;
        while (idx < s.length)
        {
            if (isAlpha(s[idx]))
                idx++;
            else if (start != idx && s[idx] >= '0' && s[idx] <= '9')
                idx++;
            else
            {
                bool found = false;
                foreach (ch; additional_chars)
                    if (s[idx] == ch)
                    {
                        found = true;
                        idx++;
                        break;
                    }
                if (!found)
                {
                    assertp(start != idx, "Expected identifier but got '" ~ s[idx] ~ "'.");
                    return s[start .. idx];
                }
            }
        }
        assertp(start != idx, "Expected identifier but got nothing.");
        return s[start .. idx];
    }

    private string skipWhitespace(in ref string s, ref size_t idx)
    {
        size_t start = idx;
        while (idx < s.length)
        {
            if (s[idx] == ' ')
                idx++;
            else
                break;
        }
        return s[start .. idx];
    }

    private string skipUntilClosingBrace(in ref string s, ref size_t idx)
    {
        int level = 0;
        auto start = idx;
        while (idx < s.length)
        {
            if (s[idx] == '{')
                level++;
            else if (s[idx] == '}')
                level--;
            if (level < 0)
                return s[start .. idx];
            idx++;
        }
        assertp(false, "Missing closing brace");
        assert(false);
    }

    private string skipAttribString(in ref string s, ref size_t idx, char delimiter)
    {
        size_t start = idx;
        while (idx < s.length)
        {
            if (s[idx] == '\\')
            {
                // pass escape character through - will be handled later by buildInterpolatedString
                idx++;
                assertp(idx < s.length, "'\\' must be followed by something (escaped character)!");
            }
            else if (s[idx] == delimiter)
                break;
            idx++;
        }
        assertp(idx < s.length, "Unterminated attribute string: " ~ s[start - 1 .. $] ~ "||");
        return s[start .. idx];
    }

    private string skipExpression(in ref string s, ref size_t idx)
    {
        string clamp_stack;
        size_t start = idx;
        outer: while (idx < s.length)
        {
            switch (s[idx])
            {
            default:
                break;
            case ',':
                if (clamp_stack.length == 0)
                    break outer;
                break;
            case '"', '\'':
                idx++;
                skipAttribString(s, idx, s[idx - 1]);
                break;
            case '(':
                clamp_stack ~= ')';
                break;
            case '[':
                clamp_stack ~= ']';
                break;
            case '{':
                clamp_stack ~= '}';
                break;
            case ')', ']', '}':
                if (s[idx] == ')' && clamp_stack.length == 0)
                    break outer;
                assertp(clamp_stack.length > 0 && clamp_stack[$ - 1] == s[idx],
                    "Unexpected '" ~ s[idx] ~ "'");
                clamp_stack.length--;
                break;
            }
            idx++;
        }

        assertp(clamp_stack.length == 0,
            "Expected '" ~ clamp_stack[$ - 1] ~ "' before end of attribute expression.");
        return ctstrip(s[start .. idx]);
    }

    private string unindent(in ref string str, in ref string indent)
    {
        size_t lvl = indentLevel(str, indent);
        return str[lvl * indent.length .. $];
    }

    private string unindent(in ref string str, in ref string indent, size_t level)
    {
        assert(level <= indentLevel(str, indent));
        return str[level * indent.length .. $];
    }

    private int indentLevel(in ref string s, in ref string indent, bool strict = true)
    {
        if (indent.length == 0)
            return 0;
        assertp(!strict || (s[0] != ' ' && s[0] != '\t') || s[0] == indent[0],
            "Indentation style is inconsistent with previous lines.");
        int l = 0;
        while (l + indent.length <= s.length && s[l .. l + indent.length] == indent)
            l += cast(int) indent.length;
        assertp(!strict || s[l] != ' ', "Indent is not a multiple of '" ~ indent ~ "'");
        return l / cast(int) indent.length;
    }

    private int indentLevel(in ref Line[] ln, string indent)
    {
        return ln.length == 0 ? 0 : indentLevel(ln[0].text, indent);
    }

    private void assertp(bool cond, lazy string text = null,
        string file = __FILE__, int cline = __LINE__)
    {
        Line ln;
        if (m_lineIndex < lineCount)
            ln = line(m_lineIndex);
        assert(cond,
            "template " ~ ln.file ~ " line " ~ cttostring(ln.number) ~ ": " ~ text ~ "(" ~ file ~ ":" ~ cttostring(
            cline) ~ ")");
    }

    private TemplateBlock* getFile(string filename)
    {
        foreach (i; 0 .. m_files.length)
            if ((*m_files)[i].name == filename)
                return &(*m_files)[i];
        assertp(false, "Bug: include input file " ~ filename ~ " not found in internal list!?");
        assert(false);
    }

    private TemplateBlock* getBlock(string name)
    {
        foreach (i; 0 .. m_blocks.blocks.length)
            if (m_blocks.blocks[i].name == name)
                return &m_blocks.blocks[i];
        return null;
    }
}

private struct HTMLAttribute
{
    string key;
    string value;
}

/// private
private void buildSpecialTag(OutputContext output, string tag, int level,
    bool leading_newline = true)
{
    if (leading_newline)
        output.writeString("\n");
    output.writeIndent(level);
    output.writeString("<" ~ tag ~ ">");
}

private bool isStringLiteral(string str)
{
    size_t i = 0;

    // skip leading white space
    while (i < str.length && (str[i] == ' ' || str[i] == '\t'))
        i++;

    // no string literal inside
    if (i >= str.length)
        return false;

    char delimiter = str[i++];
    if (delimiter != '"' && delimiter != '\'')
        return false;

    while (i < str.length && str[i] != delimiter)
    {
        if (str[i] == '\\')
            i++;
        i++;
    }

    // unterminated string literal
    if (i >= str.length)
        return false;

    i++; // skip delimiter

    // skip trailing white space
    while (i < str.length && (str[i] == ' ' || str[i] == '\t'))
        i++;

    // check if the string has ended with the closing delimiter
    return i == str.length;
}

/// Internal function used for converting an interpolation expression to string
string _toString(T)(T v)
{
    // TODO: support sink based toString() and use an output range based interface
    //       instead of allocating a string
    static if (is(T == string))
        return v;
    else static if (__traits(compiles, v.toString()))
        return v.toString();
    else static if (__traits(compiles, v.opCast!string()))
        return cast(string) v;
    else
        return to!string(v);
}

private void _toStringS(alias SINK, T)(T v)
{
    // TODO: support sink based toString() and use an output range based interface
    //       instead of allocating a string
    static if (is(T == string))
        SINK(v);
    else static if (__traits(compiles, v.toString()))
        SINK(v.toString());
    else static if (__traits(compiles, v.opCast!string()))
        SINK(cast(string) v);
    else
        SINK(to!string(v));
}

/**************************************************************************************************/
/* Compile time filters                                                                           */
/**************************************************************************************************/

private string filterCSS(string text, size_t indent)
{
    auto lines = splitLines(text);

    string indent_string = "\n";
    while (indent-- > 0)
        indent_string ~= '\t';

    string ret = indent_string ~ "<style type=\"text/css\"><!--";
    indent_string = indent_string ~ '\t';
    foreach (ln; lines)
        ret ~= indent_string ~ ln;
    indent_string = indent_string[0 .. $ - 1];
    ret ~= indent_string ~ "--></style>";

    return ret;
}

private string filterJavaScript(string text, size_t indent)
{
    auto lines = splitLines(text);

    string indent_string = "\n";
    while (indent-- > 0)
        indent_string ~= '\t';

    string ret = indent_string[0 .. $ - 1] ~ "<script type=\"text/javascript\">";
    ret ~= indent_string ~ "//<![CDATA[";
    foreach (ln; lines)
        ret ~= indent_string ~ ln;
    ret ~= indent_string ~ "//]]>" ~ indent_string[0 .. $ - 1] ~ "</script>";

    return ret;
}

struct Line
{
    string file;
    int number;
    string text;
}

void assert_ln(in ref Line ln, bool cond, string text = null,
    string file = __FILE__, int line = __LINE__)
{
    assert(cond,
        "Error in template " ~ ln.file ~ " line " ~ numToString(ln.number) ~ ": " ~ text ~ "(" ~ file ~ ":" ~ numToString(
        line) ~ ")");
}

string unindent(in ref string str, in ref string indent)
{
    size_t lvl = indentLevel(str, indent);
    return str[lvl * indent.length .. $];
}

int indentLevel(in ref string s, in ref string indent)
{
    if (indent.length == 0)
        return 0;
    int l = 0;
    while (l + indent.length <= s.length && s[l .. l + indent.length] == indent)
        l += cast(int) indent.length;
    return l / cast(int) indent.length;
}

string lineMarker(in ref Line ln)
{
    if (ln.number < 0)
        return null;
    return "#line " ~ numToString(ln.number) ~ " \"" ~ ln.file ~ "\"\n";
}

string dstringEscape(char ch)
{
    switch (ch)
    {
    default:
        return "" ~ ch;
    case '\\':
        return "\\\\";
    case '\r':
        return "\\r";
    case '\n':
        return "\\n";
    case '\t':
        return "\\t";
    case '\"':
        return "\\\"";
    }
}

string sanitizeEscaping(string str)
{
    str = dstringUnescape(str);
    return dstringEscape(str);
}

string dstringEscape(in ref string str)
{
    string ret;
    foreach (ch; str)
        ret ~= dstringEscape(ch);
    return ret;
}

string dstringUnescape(in string str)
{
    string ret;
    size_t i, start = 0;
    for (i = 0; i < str.length; i++)
        if (str[i] == '\\')
        {
            if (i > start)
            {
                if (start > 0)
                    ret ~= str[start .. i];
                else
                    ret = str[0 .. i];
            }
            assert(i + 1 < str.length, "The string ends with the escape char: " ~ str);
            switch (str[i + 1])
            {
            default:
                ret ~= str[i + 1];
                break;
            case 'r':
                ret ~= '\r';
                break;
            case 'n':
                ret ~= '\n';
                break;
            case 't':
                ret ~= '\t';
                break;
            }
            i++;
            start = i + 1;
        }

    if (i > start)
    {
        if (start == 0)
            return str;
        else
            ret ~= str[start .. i];
    }
    return ret;
}

string ctstrip(string s)
{
    size_t strt = 0, end = s.length;
    while (strt < s.length && (s[strt] == ' ' || s[strt] == '\t'))
        strt++;
    while (end > 0 && (s[end - 1] == ' ' || s[end - 1] == '\t'))
        end--;
    return strt < end ? s[strt .. end] : null;
}

string detectIndentStyle(in ref Line[] lines)
{
    // search for the first indented line
    foreach (i; 0 .. lines.length)
    {
        // empty lines should have been removed
        assert(lines[0].text.length > 0);

        // tabs are used
        if (lines[i].text[0] == '\t')
            return "\t";

        // spaces are used -> count the number
        if (lines[i].text[0] == ' ')
        {
            size_t cnt = 0;
            while (lines[i].text[cnt] == ' ')
                cnt++;
            return lines[i].text[0 .. cnt];
        }
    }

    // default to tabs if there are no indented lines
    return "\t";
}

Line[] removeEmptyLines(string text, string file)
{
    text = stripUTF8Bom(text);

    Line[] ret;
    int num = 1;
    size_t idx = 0;

    while (idx < text.length)
    {
        // start end end markers for the current line
        size_t start_idx = idx;
        size_t end_idx = text.length;

        // search for EOL
        while (idx < text.length)
        {
            if (text[idx] == '\r' || text[idx] == '\n')
            {
                end_idx = idx;
                if (idx + 1 < text.length && text[idx .. idx + 2] == "\r\n")
                    idx++;
                idx++;
                break;
            }
            idx++;
        }

        // add the line if not empty
        auto ln = text[start_idx .. end_idx];
        if (ctstrip(ln).length > 0)
            ret ~= Line(file, num, ln);

        num++;
    }
    return ret;
}

/// private
private string numToString(T)(T x)
{
    static if (is(T == string))
        return x;
    else static if (is(T : long) ||  is(T : ulong))
    {
        Unqual!T tmp = x;
        string s;
        do
        {
            s = cast(char)('0' + (tmp % 10)) ~ s;
            tmp /= 10;
        }
        while (tmp > 0);
        return s;
    }
    else
    {
        static assert(false, "Invalid type for cttostring: " ~ T.stringof);
    }
}

/// When mixed in, makes all ALIASES available in the local scope
template localAliases(int i, ALIASES...)
{
    static if (i < ALIASES.length)
    {
        enum string localAliases = "alias ALIASES[" ~ cttostring(i) ~ "] " ~ __traits(
                identifier, ALIASES[i]) ~ ";\n" ~ localAliases!(i + 1, ALIASES);
    }
    else
    {
        enum string localAliases = "";
    }
}

/// When mixed in, makes all ALIASES available in the local scope. Note that there must be a
/// Variant[] args__ available that matches TYPES_AND_NAMES
template localAliasesCompat(int i, TYPES_AND_NAMES...)
{
    import core.vararg;

    static if (i + 1 < TYPES_AND_NAMES.length)
    {
        enum TYPE = "TYPES_AND_NAMES[" ~ cttostring(i) ~ "]";
        enum NAME = TYPES_AND_NAMES[i + 1];
        enum INDEX = cttostring(i / 2);
        enum string localAliasesCompat = "Rebindable2!(" ~ TYPE ~ ") " ~ NAME ~ ";\n" ~ "if( _arguments[" ~ INDEX ~ "] == typeid(Variant) )\n" ~ "\t" ~ NAME ~ " = *va_arg!Variant(_argptr).peek!(" ~ TYPE ~ ")();\n" ~ "else {\n" ~ "\tassert(_arguments[" ~ INDEX ~ "] == typeid(" ~ TYPE ~ "), \"Actual type for parameter " ~ NAME ~ " does not match template type.\");\n" ~ "\t" ~ NAME ~ " = va_arg!(" ~ TYPE ~ ")(_argptr);\n" ~ "}\n" ~ localAliasesCompat!(
                i + 2, TYPES_AND_NAMES);
    }
    else
    {
        enum string localAliasesCompat = "";
    }
}

template Rebindable2(T)
{
    static if (is(T == class) ||  is(T == interface) || isArray!T)
        alias Rebindable2 = Rebindable!T;
    else
        alias Rebindable2 = Unqual!T;
}

/// private
string cttostring(T)(T x)
{
    static if (is(T == string))
        return x;
    else static if (is(T : long) ||  is(T : ulong))
    {
        Unqual!T tmp = x;
        string s;
        do
        {
            s = cast(char)('0' + (tmp % 10)) ~ s;
            tmp /= 10;
        }
        while (tmp > 0);
        return s;
    }
    else
    {
        static assert(false, "Invalid type for cttostring: " ~ T.stringof);
    }
}

struct StreamOutputRange
{
    private
    {
        OutputStream m_stream;
        size_t m_fill = 0;
        ubyte[256] m_data = void;
    }

    @disable this(this);

    this(OutputStream stream)
    {
        m_stream = stream;
    }

    ~this()
    {
        flush();
    }

    void flush()
    {
        if (m_fill == 0)
            return;
        m_stream.write(m_data[0 .. m_fill]);
        m_fill = 0;
    }

    void put(ubyte bt)
    {
        m_data[m_fill++] = bt;
        if (m_fill >= m_data.length)
            flush();
    }

    void put(const(ubyte)[] bts)
    {
        while (bts.length)
        {
            auto len = min(m_data.length - m_fill, bts.length);
            m_data[m_fill .. m_fill + len] = bts[0 .. len];
            m_fill += len;
            bts = bts[len .. $];
            if (m_fill >= m_data.length)
                flush();
        }
    }

    void put(char elem)
    {
        put(cast(ubyte) elem);
    }

    void put(const(char)[] elems)
    {
        put(cast(const(ubyte)[]) elems);
    }

    void put(dchar elem)
    {
        import std.utf;

        char[4] chars;
        auto len = encode(chars, elem);
        put(chars[0 .. len]);
    }

    void put(const(dchar)[] elems)
    {
        foreach (ch; elems)
            put(ch);
    }
}

template Group(T...)
{
    alias expand = T;
}

template isGroup(T...)
{
    static if (T.length != 1)
        enum isGroup = false;
    else
        enum isGroup = !is(T[0]) &&  is(typeof(T[0]) == void) // does not evaluate to something

             &&  is(typeof(T[0].expand.length) : size_t) // expands to something with length
             &&  !is(typeof(&(T[0].expand))); // expands to not addressable
}

string stripUTF8Bom(string str) @safe pure nothrow
{
    if (str.length >= 3 && str[0 .. 3] == [0xEF, 0xBB, 0xBF])
        return str[3 .. $];
    return str;
}

/** Returns the HTML escaped version of a given string.
*/
string htmlEscape(R)(R str) if (isInputRange!R)
{
    if (__ctfe)
    { // appender is a performance/memory hog in ctfe
        StringAppender dst;
        filterHTMLEscape(dst, str);
        return dst.data;
    }
    else
    {
        auto dst = appender!string();
        filterHTMLEscape(dst, str);
        return dst.data;
    }
}

///
unittest
{
    assert(htmlEscape(`"Hello", <World>!`) == `"Hello", &lt;World&gt;!`);
}

/** Writes the HTML escaped version of a given string to an output range.
*/
void filterHTMLEscape(R, S)(ref R dst, S str, HTMLEscapeFlags flags = HTMLEscapeFlags.escapeNewline) if (
        isOutputRange!(R, dchar) && isInputRange!S)
{
    for (; !str.empty; str.popFront())
        filterHTMLEscape(dst, str.front, flags);
}

/** Returns the HTML escaped version of a given string (also escapes double quotes).
*/
string htmlAttribEscape(R)(R str) if (isInputRange!R)
{
    if (__ctfe)
    { // appender is a performance/memory hog in ctfe
        StringAppender dst;
        filterHTMLAttribEscape(dst, str);
        return dst.data;
    }
    else
    {
        auto dst = appender!string();
        filterHTMLAttribEscape(dst, str);
        return dst.data;
    }
}

///
unittest
{
    assert(htmlAttribEscape(`"Hello", <World>!`) == `&quot;Hello&quot;, &lt;World&gt;!`);
}

/** Writes the HTML escaped version of a given string to an output range (also escapes double quotes).
*/
void filterHTMLAttribEscape(R, S)(ref R dst, S str) if (isOutputRange!(R, dchar) && isInputRange!S)
{
    for (; !str.empty; str.popFront())
        filterHTMLEscape(dst, str.front,
            HTMLEscapeFlags.escapeNewline | HTMLEscapeFlags.escapeQuotes);
}

/** Returns the HTML escaped version of a given string (escapes every character).
*/
string htmlAllEscape(R)(R str) if (isInputRange!R)
{
    if (__ctfe)
    { // appender is a performance/memory hog in ctfe
        StringAppender dst;
        filterHTMLAllEscape(dst, str);
        return dst.data;
    }
    else
    {
        auto dst = appender!string();
        filterHTMLAllEscape(dst, str);
        return dst.data;
    }
}

///
unittest
{
    assert(htmlAllEscape("Hello!") == "&#72;&#101;&#108;&#108;&#111;&#33;");
}

/** Writes the HTML escaped version of a given string to an output range (escapes every character).
*/
void filterHTMLAllEscape(R, S)(ref R dst, S str) if (isOutputRange!(R, dchar) && isInputRange!S)
{
    for (; !str.empty; str.popFront())
    {
        dst.put("&#");
        dst.put(to!string(cast(uint) str.front));
        dst.put(';');
    }
}

/**
	Minimally escapes a text so that no HTML tags appear in it.
*/
string htmlEscapeMin(R)(R str) if (isInputRange!R)
{
    auto dst = appender!string();
    for (; !str.empty; str.popFront())
        filterHTMLEscape(dst, str.front, HTMLEscapeFlags.escapeMinimal);
    return dst.data();
}

/**
	Writes the HTML escaped version of a character to an output range.
*/
void filterHTMLEscape(R)(ref R dst, dchar ch, HTMLEscapeFlags flags = HTMLEscapeFlags.escapeNewline)
{
    switch (ch)
    {
    default:
        if (flags & HTMLEscapeFlags.escapeUnknown)
        {
            dst.put("&#");
            dst.put(to!string(cast(uint) ch));
            dst.put(';');
        }
        else
            dst.put(ch);
        break;
    case '"':
        if (flags & HTMLEscapeFlags.escapeQuotes)
            dst.put("&quot;");
        else
            dst.put('"');
        break;
    case '\'':
        if (flags & HTMLEscapeFlags.escapeQuotes)
            dst.put("&#39;");
        else
            dst.put('\'');
        break;
    case '\r', '\n':
        if (flags & HTMLEscapeFlags.escapeNewline)
        {
            dst.put("&#");
            dst.put(to!string(cast(uint) ch));
            dst.put(';');
        }
        else
            dst.put(ch);
        break;
    case 'a': .. case 'z':
        goto case;
    case 'A': .. case 'Z':
        goto case;
    case '0': .. case '9':
        goto case;
    case ' ', '\t', '-', '_', '.', ':', ',', ';', '#', '+', '*', '?', '=',
            '(', ')', '/', '!', '%', '{', '}', '[', ']', '`', '´', '$', '^',
            '~':
            dst.put(cast(char) ch);
        break;
    case '<':
        dst.put("&lt;");
        break;
    case '>':
        dst.put("&gt;");
        break;
    case '&':
        dst.put("&amp;");
        break;
    }
}

enum HTMLEscapeFlags
{
    escapeMinimal = 0,
    escapeQuotes = 1 << 0,
    escapeNewline = 1 << 1,
    escapeUnknown = 1 << 2
}

private struct StringAppender
{
    string data;
    void put(string s)
    {
        data ~= s;
    }

    void put(char ch)
    {
        data ~= ch;
    }

    void put(dchar ch)
    {
        import std.utf;

        char[4] dst;
        data ~= dst[0 .. encode(dst, ch)];
    }
}
