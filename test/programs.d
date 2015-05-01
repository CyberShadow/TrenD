module test.programs;

import std.algorithm;
import std.array;
import std.datetime;
import std.exception;
import std.file;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.typetuple;

import ae.utils.meta;
import ae.utils.xmllite : encodeEntities;

import common;

const string[] dmdFlags = ["-O", "-inline", "-release"];

version (Posix)
{
	import core.sys.posix.sys.resource;
	import core.sys.posix.sys.wait;
	import core.stdc.errno;

	extern(C) pid_t wait4(pid_t pid, int *status, int options, rusage *rusage);
}

struct ProgramInfo
{
	string id, name, rawCode;
	int iterations = 10;

	@property string code()
	{
		return rawCode
			.replace("\n\t\t", "\n")
			.replace("\t", "    ")
			.strip()
		;
	}
}

const ProgramInfo[] programs = [
	ProgramInfo("empty", "Empty program", q{
		void main()
		{
		}
	}),

	ProgramInfo("hello", "\"Hello, world\"", q{
		import std.stdio;

		void main()
		{
			writeln("Hello, world!");
		}
	}),
];

struct ExecutionStats
{
	long realTime, userTime, kernelTime, maxRSS;
}

final class Program
{
	ProgramInfo info;

	this(ProgramInfo info) { this.info = info; }

	static struct State
	{
		bool haveSource, haveCompiled, haveLinked, haveExecuted;
		ExecutionStats compilation, linking, execution;
	}
	State state;

	@property string srcDir() { return d.config.local.workDir.buildPath("temp-trend"); }
	@property string srcFile() { return srcDir.buildPath("test.d"); }
	@property string objFile() { return srcDir.buildPath("test" ~ (isVersion!`Windows` ? ".obj" : ".o")); }
	@property string exeFile() { return srcDir.buildPath("test" ~ (isVersion!`Windows` ? ".exe" : "")); }

	void reset()
	{
		state = State.init;

		if (srcDir.exists)
			srcDir.rmdirRecurse();
	}

	void needSource()
	{
		if (!state.haveSource)
		{
			if (srcDir.exists)
				srcDir.rmdirRecurse();
			srcDir.mkdir();
			std.file.write(srcFile, info.code);

			state.haveSource = true;
		}
	}

	void needCompiled()
	{
		if (!state.haveCompiled)
		{
			needSource();
			measure(["dmd", "-c"] ~ dmdFlags ~ ["test.d"], objFile, state.compilation);
			state.haveCompiled = true;
		}
	}

	void needLinked()
	{
		if (!state.haveLinked)
		{
			needCompiled();
			measure(["dmd", objFile.baseName], exeFile, state.linking);
			state.haveLinked = true;
		}
	}

	void needExecuted()
	{
		if (!state.haveExecuted)
		{
			needLinked();
			measure([exeFile.absolutePath()], null, state.execution);
			state.haveExecuted = true;
		}
	}

	void measure(string[] command, string outputFile, out ExecutionStats bestStats)
	{
		auto oldPath = environment["PATH"];
		scope(exit) environment["PATH"] = oldPath;
		environment["PATH"] = buildPath(d.buildDir, "bin").absolutePath() ~ pathSeparator ~ oldPath;
		log("PATH=" ~ environment["PATH"]);

		foreach (ref n; bestStats.tupleof)
			n = typeof(n).max;

		foreach (iteration; 0..info.iterations)
		{
			if (outputFile && outputFile.exists)
				outputFile.remove();

			log("Running program: %s".format(command));
			auto pid = spawnProcess(command, stdin, stdout, stderr, null, std.process.Config.none, srcDir);

			ExecutionStats iterationStats;
			StopWatch sw;
			sw.start();

			version (Windows)
			{
				// Just measure something for some draft results
				auto status = wait(pid);
				enforce(status == 0, "%s failed with status %s".format(command, status));
			}
			else
			{
				rusage rusage;

				while (true)
				{
					int status;
					auto check = wait4(pid.osHandle, &status, 0, &rusage);
					if (check == -1)
					{
						errnoEnforce(errno == EINTR, "Unexpected wait3 interruption");
						continue;
					}

					enforce(!WIFSIGNALED(status), "Program failed with signal %s".format(status));
					if (!WIFEXITED(status))
						continue;

					enforce(WEXITSTATUS(status) == 0, "Program failed with status %s".format(status));
					break;
				}

				long nsecs(timeval tv) { return tv.tv_sec * 1_000_000_000L + tv.tv_usec * 1_000L; }

				iterationStats.userTime   = nsecs(rusage.ru_utime);
				iterationStats.kernelTime = nsecs(rusage.ru_stime);
				iterationStats.maxRSS     = rusage.ru_maxrss * 1024L;
			}

			sw.stop();
			iterationStats.realTime = sw.peek().hnsecs * 100L;

			if (outputFile)
				enforce(outputFile.exists, "Program did not create output file " ~ outputFile);

			foreach (i, n; bestStats.tupleof)
				bestStats.tupleof[i] = min(bestStats.tupleof[i], iterationStats.tupleof[i]);
		}
	}
}

abstract class ProgramTest : Test
{
	Program program;

	this(Program program) { this.program = program; }

	abstract @property string testID();
	abstract @property string testName();
	abstract @property string testDescription();

	override @property string id() { return "program-%s-%s-%d".format(program.info.id, testID, program.info.iterations); }
	override @property string name() { return "%s (%s)".format(testName, program.info.name); }
	override @property string description() { return "The <span class='test-description'>%s</span> for the following program:<pre>%s</pre>".format(testDescription, encodeEntities(program.info.code)); }

	override void reset() { program.reset(); }
}

final class ObjectSizeTest : ProgramTest
{
	mixin GenerateContructorProxies;

	override @property string testID() { return "objectsize"; }
	override @property string testName() { return "object file size"; }
	override @property string testDescription() { return "file size of the compiled intermediary object file"; }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }

	override long sample()
	{
		program.needCompiled();
		return program.objFile.getSize();
	}
}

final class BinarySizeTest : ProgramTest
{
	mixin GenerateContructorProxies;

	override @property string testID() { return "binarysize"; }
	override @property string testName() { return "binary file size"; }
	override @property string testDescription() { return "file size of the linked executable binary file"; }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }

	override long sample()
	{
		program.needLinked();
		return program.exeFile.getSize();
	}
}

class ProgramStatTest(string field, Unit statUnit, bool statExact, string statName, string statDescription) : ProgramTest
{
	mixin GenerateContructorProxies;

	abstract @property string stageID();
	abstract @property string stageName();
	abstract @property string stageDescription();
	abstract ExecutionStats getStats();

	override @property string testID() { return "%s-%s".format(stageID, field.toLower()); }
	override @property string testName() { return "%s - %s".format(stageName, statName); }
	override @property string testDescription() { return "%s during %s (best of %d runs)".format(statDescription, stageDescription, program.info.iterations); }
	override @property Unit unit() { return statUnit; }
	override @property bool exact() { return statExact; }

	override long sample()
	{
		auto stats = getStats();
		return mixin("stats." ~ field);
	}
}

alias ProgramRealTimeTest    = ProgramStatTest!("realTime"  , Unit.nanoseconds, false, "real time"  , "total real (elapsed) time spent");
alias ProgramUserTimeTest    = ProgramStatTest!("userTime"  , Unit.nanoseconds, false, "user time"  , "total user time (CPU time spent in userspace) spent");
alias ProgramKernelTimeTest  = ProgramStatTest!("kernelTime", Unit.nanoseconds, false, "kernel time", "total kernel time (CPU time spent in the kernel) spent");
alias ProgramMemoryUsageTest = ProgramStatTest!("maxRSS"    , Unit.bytes      , true , "max RSS"    , "peak RSS (resident set size memory usage) used");

class ProgramCompilePhaseTest(StatTest) : StatTest
{
	mixin GenerateContructorProxies;
	override @property string stageID() { return "compile"; }
	override @property string stageName() { return "Compilation"; }
	override @property string stageDescription() { return "compilation (<tt>dmd -c " ~ dmdFlags.join(" ") ~ "</tt> invocation)"; }
	override ExecutionStats getStats() { program.needCompiled(); return program.state.compilation; }
}

class ProgramLinkPhaseTest(StatTest) : StatTest
{
	mixin GenerateContructorProxies;
	override @property string stageID() { return "link"; }
	override @property string stageName() { return "Linking"; }
	override @property string stageDescription() { return "linking (<tt>dmd " ~ program.objFile.baseName ~ "</tt> invocation)"; }
	override ExecutionStats getStats() { program.needLinked(); return program.state.linking; }
}

class ProgramExecutionPhaseTest(StatTest) : StatTest
{
	mixin GenerateContructorProxies;
	override @property string stageID() { return "run"; }
	override @property string stageName() { return "Execution"; }
	override @property string stageDescription() { return "test program execution"; }
	override ExecutionStats getStats() { program.needExecuted(); return program.state.execution; }
}

static this()
{
	foreach (info; programs)
	{
		auto program = new Program(info);
		tests ~= new ObjectSizeTest(program);
		tests ~= new BinarySizeTest(program);
		foreach (StatTest; TypeTuple!(ProgramRealTimeTest, ProgramUserTimeTest, ProgramKernelTimeTest, ProgramMemoryUsageTest))
			foreach (PhaseTest; TypeTuple!(ProgramCompilePhaseTest, ProgramLinkPhaseTest, ProgramExecutionPhaseTest))
				tests ~= new PhaseTest!StatTest(program);
	}
}
