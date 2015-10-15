import core.thread;
import core.time;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.range;
import std.typecons;

import ae.sys.d.manager;
import ae.sys.file;
import ae.sys.log;
import ae.utils.json;
import ae.utils.path : nullFileName;
import ae.utils.time;

static import ae.sys.net.ae;

import common;
import test;

bool[string] badCommits;
long[string][string] testResults; // testResults[commit.hash][test.id] = value

debug
	enum updateInterval = 1.minutes;
else
	enum updateInterval = 5.minutes;
enum idleDuration = 1.minutes;
const jsonPath = "web/data/data.json.gz";

string[string][string] history;

void main()
{
	if (quiet)
	{
		auto f = File(nullFileName, "wb");
		std.stdio.stdout = f;
		std.stdio.stderr = f;
	}

	auto components = tests.map!(test => test.components).join.sort().uniq.array;
	foreach (component; DManager.allComponents)
		config.buildConfig.components.enable[component] = components.canFind(component);

	loadInfo();

	update();

	atomic!saveJson(jsonPath);

	while (true)
	{
		auto todo = getToDo();

		auto start = Clock.currTime;

		log("Running tests...");
		foreach (commit; todo)
		{
			if (!prepareCommit(commit))
				continue;
			runTests(commit);

			if (Clock.currTime - start > updateInterval)
				break;
		}

		atomic!saveJson(jsonPath);

		log("Idling...");
		Thread.sleep(idleDuration);

		update();
	}
}

void loadInfo()
{
	log("Loading existing data...");

	badCommits = null;
	foreach (string commit; query("SELECT [Commit] FROM [Commits] WHERE [Error]=1").iterate())
		badCommits[commit] = true;

	testResults = null;
	foreach (string commit, string testID, long value; query("SELECT [Commit], [TestID], [Value] FROM [Results]").iterate())
		testResults[commit][testID] = value;
}

void update()
{
	log("Updating...");
	d.update();

	history = d.getMetaRepo().getSubmoduleHistory(["origin/master"]);
}

alias LogEntry = DManager.LogEntry;

struct ScoreFactors
{
	/// Prefer commits in base 2:
	int base2       =  100; /// points per trailing zero

	/// Prefer commits which are already built and cached:
	int cached      =  500; /// points if cached

	/// Prefer recent commits:
	int recentMax   = 1000; /// max points (for newest commit)
	int recentExp   =   50; /// curve exponent

	/// Prefer untested commits:
	int untested    =  100; /// points per test

	/// Prefer commits between big differences in test results:
	int diffMax     = 1000; /// max points (for 100% difference)
	int diffExact   =    5; /// multiplier for "exact" tests
}
ScoreFactors scoreFactors;

LogEntry[] getToDo()
{
	log("Finding things to do...");

	log("Getting log...");
	auto commits = d.getLog();
	commits.reverse(); // oldest first

	log("Getting cache state...");
	auto cacheState = d.getCacheState(history);

	log("Calculating...");

	auto scores = new int[commits.length];

	foreach (i; 0..commits.length)
	{
		int score;

		if (i)
		{
			foreach (b; 0..30)
				if ((i & (1<<b)) == 0)
					score += scoreFactors.base2;
				else
					break;
		}

		if (cacheState[commits[i].hash])
			score += scoreFactors.cached;

		score += cast(int)(scoreFactors.recentMax * (double(i) / (commits.length-1)) ^^ scoreFactors.recentExp);

		scores[i] = score;
	}

	size_t[string] commitLookup = commits.map!(logEntry => logEntry.hash).enumerate.map!(t => tuple(t[1], t[0])).assocArray;
	auto testResultArray = new long[commits.length];

	auto diffPoints = new int[commits.length];

	foreach (test; tests)
	{
		testResultArray[] = 0;
		foreach (commit, results; testResults)
			if (auto pvalue = test.id in results)
				if (auto pindex = commit in commitLookup)
					testResultArray[*pindex] = *pvalue;

		size_t lastIndex = 0;
		long lastValue = 0;
		size_t bestIntermediaryIndex = 0;
		int bestIntermediaryScore = 0;

		foreach (i, value; testResultArray)
		{
			if (value == 0)
			{
				diffPoints[i] += scoreFactors.untested;

				if (bestIntermediaryScore < scores[i])
				{
					bestIntermediaryIndex = i;
					bestIntermediaryScore = scores[i];
				}
			}
			else
			{
				if (lastIndex && bestIntermediaryIndex)
				{
					assert(lastValue);
					auto v0 = min(value, lastValue);
					auto v1 = max(value, lastValue);
					auto points = cast(int)(scoreFactors.diffMax * (v1-v0) / v1);
					if (test.exact)
						points *= scoreFactors.diffExact;
					diffPoints[bestIntermediaryIndex] += points;
				}

				lastIndex = i;
				lastValue = value;
				bestIntermediaryIndex = 0;
				bestIntermediaryScore = 0;
			}
		}
	}
	foreach (i, points; diffPoints)
		scores[i] += points;

	debug(TODO)
	{
		auto f = File("todolist.txt", "wb");
		foreach (i, commit; commits)
			f.writefln("%s %s %5d", commit.hash, commit.time.formatTime!`Y-m-d H:i:s`, scores[i]);
	}

	auto index = new size_t[commits.length];
	scores.makeIndex!"a>b"(index);
	return index.map!(i => commits[i]).array();
}

bool prepareCommit(LogEntry commit)
{
	debug log("Running tests for commit: " ~ commit.hash);
	if (commit.hash in badCommits)
	{
		debug log("Commit known to be bad - skipping");
		return false;
	}

	bool wantTests = tests.any!(test => test.id !in testResults.get(commit.hash, null));
	if (!wantTests)
	{
		debug log("No new tests to sample - skipping");
		return false;
	}

	bool error = false;
	log("Building commit: " ~ commit.hash);
	try
		d.buildRev(commit.hash);
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
	log("Preparing list of tests to run...");
	Test[] testsToRun;
	foreach (test; tests)
		foreach (int count; query("SELECT COUNT(*) FROM [Results] WHERE [TestID]=? AND [Commit]=?").iterate(test.id, commit.hash))
			if (count == 0)
				testsToRun ~= test;

	log("Resetting tests...");
	foreach (test; testsToRun)
		test.reset();

	query("BEGIN TRANSACTION").exec();
	foreach (test; testsToRun)
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
		testResults[commit.hash][test.id] = result;
	}
	log("Saving test results...");
	query("COMMIT TRANSACTION").exec();
}

void saveJson(string target)
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
	}
	JsonData data;

	foreach (string commit, string message, long time; query("SELECT [Commit], [Message], [Time] FROM [Commits]").iterate())
		data.commits ~= JsonData.Commit(commit, message, time);
	foreach (string testID, string commit, long value, string error; query("SELECT [TestID], [Commit], [Value], [Error] FROM [Results]").iterate())
		data.results ~= JsonData.Result(testID, commit, value, error);
	foreach (test; tests)
		data.tests ~= JsonData.Test(test.name, test.description, test.id, test.unit, test.exact);

	auto json = data.toJson();
	import ae.utils.gzip, ae.sys.data;

	ensurePathExists(target);
	auto f = File(target, "wb");
	foreach (datum; compress([Data(json)], ZlibOptions(9)))
		f.rawWrite(datum.contents);
}
