module common;

import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.process;
import std.stdio;
import std.string;

import ae.sys.d.manager;
import ae.sys.file;
import ae.sys.log;
import ae.utils.meta : singleton;
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

	/// List of required DMD components (as done by ae.sys.d.manager) to run this test.
	abstract @property string[] components();

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

Logger log()
{
	static Logger instance;
	if (!instance)
		instance = createLogger("TrenD");
	return instance;
}

void log(string s) { return .log()(s); }

// ***************************************************************************

class TrenDManager : DManager
{
	this()
	{
		config.build = cast().config.build;
		config.local = cast().config.local;

		auto components = tests.map!(test => test.components).join.sort().uniq.array;
		log("Enabled components: %s".format(components));
		foreach (component; DManager.allComponents)
			config.build.components.enable[component] = components.canFind(component);
	}

	override string getCallbackCommand() { assert(false); }
	override void log(string s) { .log(s); }
}

// Late initialization to let tests array populate
alias d = singleton!TrenDManager;

// ***************************************************************************

struct Config
{
	DManager.Config.Build build;
	DManager.Config.Local local;
}

immutable Config config;

shared static this()
{
	config = cast(immutable)
		"trend.ini"
		.readText()
		.splitLines()
		.parseStructuredIni!Config();
}

// ***************************************************************************

import ae.sys.database;
import ae.sys.sqlite3 : SQLite;

Database database;

shared static this()
{
	database = Database("data/trend.s3db",
	[
		q"SQL
CREATE TABLE [Commits] (
	[Commit] CHAR(40) NOT NULL,
	[Message] TEXT NOT NULL,
	[Time] INTEGER NOT NULL,
	[Error] BOOLEAN NOT NULL
);

CREATE UNIQUE INDEX [CommitIndex] ON [Commits] (
	[Commit] ASC
);

CREATE TABLE [Results] (
	[TestID] VARCHAR(100) NOT NULL,
	[Commit] CHAR(40) NOT NULL,
	[Value] INTEGER NOT NULL,
	[Error] TEXT NULL
);

CREATE UNIQUE INDEX [ResultIndex] ON [Results] (
	[TestID] ASC,
	[Commit] ASC
);
SQL",
		// Make [Commits].[Error] a string
		q"SQL
ALTER TABLE [Commits] RENAME TO [Commits_OLD];
CREATE TABLE [Commits] (
	[Commit] CHAR(40) NOT NULL,
	[Message] TEXT NOT NULL,
	[Time] INTEGER NOT NULL,
	[Error] TEXT NULL
);
INSERT INTO [Commits] ([Commit], [Message], [Time], [Error])
	SELECT [Commit], [Message], [Time],
		CASE [Error]
			WHEN 0 THEN NULL
			WHEN 1 THEN "(unknown)"
		END
	FROM [Commits_OLD];
DROP TABLE [Commits_OLD];
SQL",
	]);
}

SQLite.PreparedStatement query(string sql)() { return database.stmt!sql(); }
SQLite.PreparedStatement query(string sql)   { return database.stmt(sql);  }
