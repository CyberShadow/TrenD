module test.filesize;

import std.file;
import std.format;
import std.path;

import common;

/// File size of D file.
class FilesizeTest : Test
{
	this(string fileName)
	{
		this.fileName = fileName;
	}

	string fileName;

	override @property string name() { return "Size of %s".format(fileName.baseName()); }
	override @property string description() { return "The size of the built file %s.".format(fileName); }
	override @property string id() { return fileName.baseName().stripExtension(); }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }

	override long sample()
	{
		return buildPath(d.buildDir, fileName).getSize();
	}
}

static this()
{
	version (Windows)
		auto fileNames = [`bin\dmd.exe`, `lib\phobos.lib`];
	else
		auto fileNames = [`bin/dmd`, `lib/libphobos2.a`];
	foreach (fn; fileNames)
		tests ~= new FilesizeTest(fn);
}
