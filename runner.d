module runner;

/*
  Database structure:
  - Commits table holds information about every D-dot-git meta-repository commit:
    commit hash, commit message (containing a link to the PR), and time.
    Error is set to the error message when building the commit, if that failed.
  - Results table holds the test results.
    TestID is the `test.id` property.
    "Error", if set, indicates an error running the test,
    and holds the error message preventing that test from running.
 */

import core.thread;

import std.algorithm;
import std.conv;
import std.range;
import std.stdio;
import std.typecons;

import ae.sys.d.manager;
import ae.utils.time.format;

import common;
import test;

alias LogEntry = DManager.LogEntry;

struct State
{
	bool[string] badCommits; /// In-memory cache of un-buildable commits
	long[string][string] testResults; // testResults[commit.hash][test.id] = value

	/// Result of getSubmoduleHistory of the meta-repository.
	/// history[commitHash][submoduleName] == submoduleCommitHash
	string[string][string] history;

	LogEntry[] commits;
}

/// Load data from database on disk at startup
State loadState()
{
	log("Loading existing data...");

	State state;
	foreach (string commit; query("SELECT [Commit] FROM [Commits] WHERE [Error] IS NOT NULL").iterate())
		state.badCommits[commit] = true;

	foreach (string commit, string testID, long value; query("SELECT [Commit], [TestID], [Value] FROM [Results]").iterate())
		state.testResults[commit][testID] = value;

	state.loadHistory();

	return state;
}

/// Fetch our Git repositories
void update(ref State state)
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
			// Network error?
			log("Update error: " ~ e.msg);
			Thread.sleep(1.minutes);
		}
	}

	state.loadHistory();
}

private void loadHistory(ref State state)
{
	state.history = d.getMetaRepo().getSubmoduleHistory(["origin/master"]);
	state.commits = d.getLog();
	state.commits.reverse(); // oldest first
}

struct ToDoEntry
{
	LogEntry commit;
	int score;
}

struct ScoreFactors
{
	/// Prefer commits in base 2:
	int base2       =   100; /// points per trailing zero

	/// Prefer commits which are already built and cached:
	int cached      =   500; /// points if cached

	/// Prefer recent commits:
	int recentMax   =  1000; /// max points (for newest commit)
	int recentExp   =    50; /// curve exponent

	/// Prefer untested commits:
	int untested    =   100; /// total budget, awarded in full if never tested

	/// Prefer commits between big differences in test results:
	int diffMax     = 20000; /// max points (for 100% difference)
	int diffInexact =   500; /// penalty divisor for inexact tests
}
ScoreFactors scoreFactors;

struct Stats
{
	size_t numCommits, numCachedCommits;
	string lastCommitTime;
	size_t numResults;
}

struct ToDo
{
	ToDoEntry[] entries;
	Stats stats;
}

/// What should we build/test next?
ToDo getToDo(/*in*/ ref State state)
{
	ToDo result;

	log("Finding things to do...");

	log("Getting log...");
	auto commits = state.commits;

	log("Getting cache state...");
	auto cacheState = d.getCacheState(state.history);

	log("Calculating...");

	auto scores = new int[commits.length];
	debug(TODO) auto scoreReasons = new int[string][commits.length];

	void award(size_t commit, int points, string reason)
	{
		scores[commit] += points;
		debug (TODO)
			scoreReasons[commit][reason] += points;
	}

	foreach (i; 0..commits.length)
	{
		if (i)
		{
			int score = 0;
			foreach (b; 0..30)
				if ((i & (1<<b)) == 0)
					score += scoreFactors.base2;
				else
					break;
			award(i, score, "base2");
		}

		if (cacheState[commits[i].hash])
			award(i, scoreFactors.cached, "cached");

		award(i, cast(int)(scoreFactors.recentMax * (double(i) / (commits.length-1)) ^^ scoreFactors.recentExp), "recent");
	}

	size_t[string] commitLookup = commits.map!(logEntry => logEntry.hash).enumerate.map!(t => tuple(t[1], t[0])).assocArray;
	auto testResultArray = new long[commits.length];

	auto diffPoints = new int[commits.length];

	foreach (test; tests)
	{
		testResultArray[] = long.min;
		foreach (commit, results; state.testResults)
			if (auto pvalue = test.id in results)
				if (auto pindex = commit in commitLookup)
					testResultArray[*pindex] = *pvalue;

		size_t lastIndex = 0;
		long lastValue = long.min;
		size_t bestIntermediaryIndex = 0;
		int bestIntermediaryScore = 0;

		foreach (i, value; testResultArray)
		{
			if (value == long.min)
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
					assert(lastValue != long.min);
					auto v0 = min(value, lastValue);
					auto v1 = max(value, lastValue);
					auto points = v1 ? cast(int)(scoreFactors.diffMax * (v1-v0) / v1) : 0;
					if (!test.exact)
						points /= scoreFactors.diffInexact;
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
		award(i, points / cast(int)tests.length, "diff");

	debug (TODO)
	{
		auto f = File("todolist.txt", "wb");
		foreach (i, commit; commits)
			f.writefln("%s %s %5d %s", commit.hash, commit.time.formatTime!`Y-m-d H:i:s`, scores[i], scoreReasons[i]);
	}

	auto index = new size_t[commits.length];
	scores.makeIndex!"a>b"(index);

	result.entries = index.map!(i => ToDoEntry(commits[i], scores[i])).array();

	{
		result.stats.numCommits = commits.length;
		foreach (commit; commits)
			if (cacheState.get(commit.hash, false))
				result.stats.numCachedCommits++;
		result.stats.lastCommitTime = commits[$-1].time.toString();

		foreach (commit, results; state.testResults)
			result.stats.numResults += results.length;
	}

	return result;
}

/// Build (or pull from cache) a commit for testing
/// Return true if successful
bool prepareCommit(ref State state, LogEntry commit)
{
	if (commit.hash in state.badCommits)
	{
		debug log("Commit known to be bad - skipping");
		return false;
	}

	bool wantTests = tests.any!(test => test.id !in state.testResults.get(commit.hash, null));
	if (!wantTests)
	{
		debug log("No new tests to sample - skipping");
		return false;
	}

	string error = null;
	log("Building commit: " ~ commit.hash);
	try
		d.buildRev(commit.hash);
	catch (Exception e)
	{
		error = e.msg;
		log("Error: " ~ e.toString());
	}

	query("INSERT OR REPLACE INTO [Commits] ([Commit], [Error]) VALUES (?, ?)")
		.exec(commit.hash, error);

	if (error)
	{
		state.badCommits[commit.hash] = true;
		return false;
	}

	return true;
}

void runTests(ref State state, LogEntry commit)
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
		state.testResults[commit.hash][test.id] = result;
	}
	log("Saving test results...");
	query("COMMIT TRANSACTION").exec();
}
