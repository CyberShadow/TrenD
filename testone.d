import std.algorithm;
import std.array;
import std.conv;
import std.getopt;
import std.stdio;

import common;
import test;

void main(string[] args)
{
	bool noCache;
	getopt(args,
		"no-cache", &noCache,
	);

	string[] commits;
	if (args.length > 1)
		commits = args[1..$];
	else
	{
		d.getMetaRepo().needRepo();
		commits = [d.getMetaRepo().getRef("origin/master")];
	}
	if (noCache)
		d.config.local.cache = null;

	foreach (commit; commits)
	{
		log("Preparing commit: " ~ commit);
		d.buildRev(commit);

		long[] results;
		string[] errors;

		log("Resetting tests");
		foreach (test; tests)
			test.reset();

		foreach (test; tests)
		{
			log("Running test " ~ test.id);
			long result = 0; string error = null;
			try
				result = test.sample();
			catch (Exception e)
				error = e.msg;
			results ~= result;
			errors ~= error;
		}

		writeln("===============================================================");
		auto maxLength = tests.map!(t => t.id.length).reduce!max;
		foreach (i, test; tests)
			writefln("%s%s : %s", test.id, " ".replicate(maxLength-test.id.length), errors[i] ? errors[i] : text(results[i]));
	}
}
