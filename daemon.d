module daemon;

import core.thread;
import core.time;

import std.algorithm;
import std.datetime;
import std.range;
import std.stdio;
import std.string;

import ae.sys.d.manager;
import ae.sys.file;
import ae.sys.log;
import ae.utils.json;
import ae.utils.path : nullFileName;

import common;
import runner;

static import ae.sys.net.ae;

debug
{
	enum updateInterval = 1.minutes;
	enum idleDuration = 0.minutes;
}
else
{
	enum updateInterval = 5.minutes;
	enum idleDuration = 1.minutes;
}

const jsonPath = "web/data/data.json.gz"; /// Path to write data for the web interface

void main()
{
	if (quiet)
	{
		auto f = File(nullFileName, "wb");
		std.stdio.stdout = f;
		std.stdio.stderr = f;
	}

	loadInfo();

	while (true)
	{
		update();
		auto todo = getToDo();
		atomic!saveJson(jsonPath, todo.stats);

		auto start = Clock.currTime;

		log("Running tests...");
		foreach (entry; todo.entries)
		{
			debug log("Running tests for commit: %s (%s, score %d)".format(entry.commit.hash, entry.commit.time, entry.score));
			if (!prepareCommit(entry.commit))
				continue;
			runTests(entry.commit);

			if (Clock.currTime - start > updateInterval)
				break;
		}

		log("Idling...");
		Thread.sleep(idleDuration);
	}
}

/// Fetch our Git repositories
void update()
{
	log("Updating...");

	while (true)
	{
		try
		{
			d.update();
			break;
		}
		catch (Exception e)
		{
			log("Update error: " ~ e.msg);
			Thread.sleep(updateInterval);
		}
	}

	history = d.getMetaRepo().getSubmoduleHistory(["origin/master"]);
}

void saveJson(string target, Stats stats)
{
	log("Saving results...");

	static struct JsonData
	{
		struct Commit
		{
			string commit, message;
			long time;
		}
		Commit[] commits;

		struct Result
		{
			string testID, commit;
			long value;
			string error;
		}
		Result[] results;

		struct Test
		{
			string name, description, id;
			Unit unit;
			bool exact;
		}
		Test[] tests;

		Stats stats;
	}
	JsonData data;

	foreach (string commit, string message, long time; query("SELECT [Commit], [Message], [Time] FROM [Commits]").iterate())
		data.commits ~= JsonData.Commit(commit, message, time);
	foreach (string testID, string commit, long value, string error; query("SELECT [TestID], [Commit], [Value], [Error] FROM [Results]").iterate())
		data.results ~= JsonData.Result(testID, commit, value, error);
	foreach (test; tests)
		data.tests ~= JsonData.Test(test.name, test.description, test.id, test.unit, test.exact);
	data.stats = stats;

	auto json = data.toJson();
	import ae.utils.gzip, ae.sys.data;

	ensurePathExists(target);
	auto f = File(target, "wb");
	foreach (datum; compress([Data(json)], ZlibOptions(9)))
		f.rawWrite(datum.contents);
}
