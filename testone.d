import std.algorithm;
import std.array;
import std.conv;
import std.stdio;

import common;
import test;

void main(string[] args)
{
	string[] commits;
	if (args.length > 1)
		commits = args[1..$];
	else
	{
		d.getMetaRepo().needRepo();
		commits = [d.getMetaRepo().getRef("origin/master")];
	}

	foreach (commit; commits)
	{
		d.buildRev(commit, config.buildConfig);

		long[] results;
		string[] errors;

		foreach (test; tests)
		{
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
