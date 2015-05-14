module test.filesize;

import std.algorithm;
import std.file;
import std.format;
import std.path;

import common;

/// File size of D file.
class FilesizeTest : Test
{
	this(string fileName, string component)
	{
		this.fileName = fileName;
		this.component = component;
	}

	string fileName, component;

	override @property string id() { return "size-" ~ fileName.baseName().stripExtension(); }
	override @property string name() { return "Size of %s".format(fileName.baseName()); }
	override @property string description() { return "The size of the built file %s.".format(fileName); }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }
	override @property string[] components() { return [component]; }

	override long sample()
	{
		return buildPath(d.buildDir, fileName).getSize();
	}
}

/// Total file size of Phobos/Druntime.
class SrcSizeTest : Test
{
	override @property string id() { return "srcsize"; }
	override @property string name() { return "Size of Phobos/Druntime source code"; }
	override @property string description() { return "The size of the Phobos/Druntime source code / includes."; }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }
	override @property string[] components() { return ["phobos-includes", "druntime"]; }

	override long sample()
	{
		return buildPath(d.buildDir, "import")
			.dirEntries(SpanMode.depth)
			.map!(de => de.getSize())
			.sum;
	}
}

static this()
{
	version (Windows)
		auto fileNames = [`bin\dmd.exe`, `lib\phobos.lib`];
	else
		auto fileNames = [`bin/dmd`, `lib/libphobos2.a`];
	auto components =    ["dmd", "phobos"];
	foreach (i, fn; fileNames)
		tests ~= new FilesizeTest(fn, components[i]);
	tests ~= new SrcSizeTest;
}
