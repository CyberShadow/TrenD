import core.time;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;

import ae.sys.d.manager;
import ae.sys.file;
import ae.utils.json;

import common;
import test;

bool[string] badCommits;
bool[string][string] testsDone;

debug
	enum updateInterval = 1.minutes;
else
	enum updateInterval = 5.minutes;

void main()
{
	log("Loading existing data...");
	loadInfo();

	while (true)
	{
		log("Saving results...");
		atomic!saveJson("data.json.gz");

		log("Updating...");
		d.update();

		log("Finding things to do...");
		auto todo = getToDo();

		auto start = Clock.currTime;

		foreach (commit; todo)
		{
			if (!prepareCommit(commit))
				continue;
			runTests(commit);

			if (Clock.currTime - start > updateInterval)
				break;
		}
	}
}

void loadInfo()
{
	foreach (string commit; query("SELECT [Commit] FROM [Commits] WHERE [Error]=1").iterate())
		badCommits[commit] = true;
	foreach (string commit, string testID; query("SELECT [Commit], [TestID] FROM [Results]").iterate())
		testsDone[commit][testID] = true;
}

alias LogEntry = DManager.LogEntry;

LogEntry[] getToDo()
{
	auto commits = d.getLog();
	commits.reverse(); // oldest first

	LogEntry[] result;
	for (int step = 1 << 30; step; step >>= 1)
		for (int n = step; n < commits.length; n += step * 2)
			result ~= commits[n];
	return result;
}

bool prepareCommit(LogEntry commit)
{
	debug log("Running tests for commit: " ~ commit.hash);
	if (commit.hash in badCommits)
	{
		debug log("Commit known to be bad - skipping");
		return false;
	}

	bool wantTests = tests.any!(test => test.id !in testsDone.get(commit.hash, null));
	if (!wantTests)
	{
		debug log("No new tests to sample - skipping");
		return false;
	}

	bool error = false;
	log("Building commit: " ~ commit.hash);
	try
		d.buildRev(commit.hash, config.buildConfig);
	catch (Exception e)
	{
		error = true;
		log("Error: " ~ e.toString());
	}

	query("INSERT OR REPLACE INTO [Commits] ([Commit], [Message], [Time], [Error]) VALUES (?, ?, ?, ?)")
		.exec(commit.hash, commit.message.join("\n"), commit.time.toUnixTime, error);

	if (error)
	{
		badCommits[commit.hash] = true;
		return false;
	}

	return true;
}

void runTests(LogEntry commit)
{
	foreach (test; tests)
	{
		bool haveResult;
		foreach (int count; query("SELECT COUNT(*) FROM [Results] WHERE [TestID]=? AND [Commit]=?").iterate(test.id, commit.hash))
			haveResult = count > 0;
		if (!haveResult)
		{
			log("Running test: " ~ test.id);
			long result = 0; string error = null;
			try
			{
				result = test.sample();
				log("Test succeeded with value: " ~ text(result));
			}
			catch (Exception e)
			{
				error = e.msg;
				log("Test failed with error: " ~ e.toString());
			}
			query("INSERT INTO [Results] ([TestID], [Commit], [Value], [Error]) VALUES (?, ?, ?, ?)").exec(test.id, commit.hash, result, error);
			testsDone[commit.hash][test.id] = true;
		}
	}
}

void saveJson(string target)
{
	static struct JsonData
	{
		struct Commit
		{
			string commit, message;
			long time;
			bool error;
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
	}
	JsonData data;

	foreach (string commit, string message, long time, int error; query("SELECT [Commit], [Message], [Time], [Error] FROM [Commits]").iterate())
		data.commits ~= JsonData.Commit(commit, message, time, error != 0);
	foreach (string testID, string commit, long value, string error; query("SELECT [TestID], [Commit], [Value], [Error] FROM [Results]").iterate())
		data.results ~= JsonData.Result(testID, commit, value, error);
	foreach (test; tests)
		data.tests ~= JsonData.Test(test.name, test.description, test.id, test.unit, test.exact);

	auto json = data.toJson();
	import ae.utils.gzip, ae.sys.data;

	auto f = File(target, "wb");
	foreach (datum; compress([Data(json)], ZlibOptions(9)))
		f.rawWrite(datum.contents);
}
