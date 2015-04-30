module common;

import std.exception;
import std.file;
import std.process;
import std.string;

import ae.sys.d.manager;
import ae.sys.file;
import ae.sys.log;
import ae.utils.sini;

class Test
{
	/// Unique ID. Should change if the test changes.
	abstract @property string id();

	/// Short human-readable name. Should mention test parameters,
	/// but doesn't need to be globally unique.
	abstract @property string name();

	/// Longer description.
	abstract @property string description();

	/// What are we measuring (memory, time)
	abstract @property Unit unit();

	/// Whether this test is exact (unlikely to change in successive measurements)
	abstract @property bool exact();

	/// This will be called before any sample() call for all tests.
	void reset() {}

	/// Perform the test and return the result
	abstract long sample();
}

Test[] tests;

enum Unit
{
	bytes,
	nanoseconds,
}

// ***************************************************************************

Logger log;

static this()
{
	log = createLogger("TrenD");
}

// ***************************************************************************

class TrenDManager : DManager
{
	this()
	{
		config.local.workDir = .config.workDir;
		config.cache = .config.cache;
	}

	override void prepareEnv()
	{
		super.prepareEnv();
		applyEnv(.config.environment);
	}

	override string getCallbackCommand() { assert(false); }
	override void log(string s) { .log(s); }
}

DManager d;

static this()
{
	d = new TrenDManager;
}

// ***************************************************************************

struct Config
{
	DManager.Config.Build buildConfig;
	string workDir = "../Digger";
	string cache = "git";
	string[string] environment;
}

Config config;

shared static this()
{
	config = "trend.ini"
		.readText()
		.splitLines()
		.parseStructuredIni!Config();
}

// ***************************************************************************

import ae.sys.sqlite3;

SQLite db;

shared static this()
{
	auto dbFileName = "data/trend.s3db";

	void createDatabase(string target)
	{
		std.stdio.stderr.writeln("Creating new database from schema");
		ensurePathExists(target);
		enforce(spawnProcess(["sqlite3", target], File("schema.sql", "rb")).wait() == 0, "sqlite3 failed");
	}

	if (!dbFileName.exists)
		atomic!createDatabase(dbFileName);

	db = new SQLite(dbFileName);
}

SQLite.PreparedStatement query(string sql)
{
	static SQLite.PreparedStatement[string] cache;
	if (auto pstatement = sql in cache)
		return *pstatement;
	return cache[sql] = db.prepare(sql).enforce("Statement compilation failed: " ~ sql);
}
