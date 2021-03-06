module test.programs;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
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
	string id, name, code, description;
	int iterations = 10;

	static ProgramInfo fromSource(string id, string name, string rawCode)
	{
		ProgramInfo pi;
		pi.id = id;
		pi.name = name;
		pi.code = rawCode
			.replace("\n\t\t\t", "\n")
			.replace("\t", "    ")
			.strip()
		;
		pi.description = "the following program:<pre>%s</pre>".format(encodeEntities(pi.code));
		return pi;
	}

	static ProgramInfo fromFile(string id, string name)
	{
		ProgramInfo pi;
		pi.id = id;
		pi.name = name;
		auto fileName = "benchmarks/" ~ id ~ ".d";
		pi.code = readText(fileName);
		pi.description = "the program <a href='%s'>%s.d</a>.".format(fileName, id);
		return pi;
	}
}

const ProgramInfo[] programs;

shared static this()
{
	programs = [
		ProgramInfo.fromSource("empty", "Empty program", q{
			void main()
			{
			}
		}),

		ProgramInfo.fromSource("hello", "\"Hello, world\"", q{
			import std.stdio;

			void main()
			{
				writeln("Hello, world!");
			}
		}),

		ProgramInfo.fromSource("arrays2", "Dynamic/associative arrays", q{
			enum maxLength = 7;
			string letters = "abcdefgh";

			int[string] dict;

			void countSort(char[] s)
			{
				size_t[256] counts;
				foreach (c; s)
					counts[c]++;
				size_t i = 0;
				foreach (c, count; counts)
					foreach (n; 0 .. count)
						s[i++] = cast(char)c;
			}

			void gen(string base)
			{
				if (base.length == maxLength)
				{
					auto s = base.dup;
					s.countSort;
					dict[s.idup]++;
				}
				else
					foreach (c; letters)
						gen(base ~ c);
			}

			void main()
			{
				gen(null);
				int total;
				foreach (k, v; dict)
					total += v;

				int expected = 1;
				foreach (n; 0..maxLength)
					expected *= letters.length;
				assert(total == expected);
			}
		}),

		ProgramInfo.fromFile("dietbench", "Vibe.d diet templates"),
	];
}

struct ExecutionStats
{
	long realTime   = long.max;
	long userTime   = long.max;
	long kernelTime = long.max;
	long maxRSS     = long.max;
}

final class Program
{
	ProgramInfo info;

	this(ProgramInfo info) { this.info = info; }

	static struct State
	{
		Target source, compile, link, run;
	}
	State state;

	@property string srcDir() { return d.config.local.workDir.buildPath("temp-trend"); }
	@property string srcFile() { return srcDir.buildPath("test.d"); }
	@property string objFile() { return srcDir.buildPath("test" ~ (isVersion!`Windows` ? ".obj" : ".o")); }
	@property string exeFile() { return srcDir.buildPath("test" ~ (isVersion!`Windows` ? ".exe" : "")); }

	class Target
	{
		ExecutionStats bestStats;
		int runs;

		abstract @property Target[] dependencies();
		abstract @property string[] command();
		abstract @property string outputFile();

		void need(int runs = 1)
		{
			foreach (dependency; dependencies)
				dependency.need();
			if (runs > this.runs)
				run(runs - this.runs, &measureRusage);
			else
			if (outputFile && !outputFile.exists)
			{
				// a failure in a previous run call might have caused
				// outputFile to get deleted but not recreated
				log("Recreating " ~ outputFile);
				run(1, &measureRusage);
			}
		}

		void run(int iterations, void delegate() runner)
		{
			auto oldPath = environment["PATH"];
			scope(exit) environment["PATH"] = oldPath;
			environment["PATH"] = buildPath(d.buildDir, "bin").absolutePath() ~ pathSeparator ~ oldPath;
			log("PATH=" ~ environment["PATH"]);

			foreach (iteration; 0..iterations)
			{
				if (outputFile && outputFile.exists)
					outputFile.remove();

				runner();

				if (outputFile)
					enforce(outputFile.exists, "Program did not create output file " ~ outputFile);
			}
		}

		final void measureRusage()
		{
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
			iterationStats.realTime = sw.peek().total!"hnsecs" * 100L;

			foreach (i, n; bestStats.tupleof)
				bestStats.tupleof[i] = min(bestStats.tupleof[i], iterationStats.tupleof[i]);
			runs++;
		}
	}

	class Source : Target
	{
		override @property Target[] dependencies() { return null; }
		override @property string[] command() { assert(false); }
		override @property string outputFile() { return srcFile; }
		override void run(int runs, void delegate() runner)
		{
			assert(runs==1 && runner is &measureRusage);
			if (srcDir.exists)
			{
				log("Cleaning up " ~ srcDir);
				srcDir.rmdirRecurse();
			}
			srcDir.mkdir();
			std.file.write(srcFile, info.code);
			this.runs = 1;
		}
	}

	class Compile : Target
	{
		override @property Target[] dependencies() { return [state.source]; }
		override @property string[] command() { return ["dmd", "-c"] ~ dmdFlags ~ ["test.d"]; }
		override @property string outputFile() { return objFile; }
	}

	class Link : Target
	{
		override @property Target[] dependencies() { return [state.compile]; }
		override @property string[] command() { return ["dmd", objFile.baseName]; }
		override @property string outputFile() { return exeFile; }
	}

	class Run : Target
	{
		override @property Target[] dependencies() { return [state.link]; }
		override @property string[] command() { return [exeFile.absolutePath()]; }
		override @property string outputFile() { return null; }
	}

	void reset()
	{
		if (srcDir.exists)
			srcDir.rmdirRecurse();

		state = State.init;
		state.source = new Source;
		state.compile = new Compile;
		state.link = new Link;
		state.run = new Run;
	}
}

abstract class ProgramTest : Test
{
	Program program;

	this(Program program) { this.program = program; }

	abstract @property string testID();
	abstract @property string testName();
	abstract @property string testDescription();

	override @property string id() { return "program-%s-%s".format(program.info.id, testID); }
	override @property string name() { return "Program - %s - %s".format(program.info.name, testName); }
	override @property string description() { return "The <span class='test-description'>%s</span> for %s".format(testDescription, program.info.description); }
	override @property string[] components() { return ["dmd", "phobos-includes", "druntime", "phobos"]; }

	override void reset() { program.reset(); }
}

final class ObjectSizeTest : ProgramTest
{
	mixin GenerateConstructorProxies;

	override @property string testID() { return "objectsize"; }
	override @property string testName() { return "object file size"; }
	override @property string testDescription() { return "file size of the compiled intermediary object file"; }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }

	override long sample()
	{
		program.state.compile.need();
		return program.objFile.getSize();
	}
}

final class BinarySizeTest : ProgramTest
{
	mixin GenerateConstructorProxies;

	override @property string testID() { return "binarysize"; }
	override @property string testName() { return "binary file size"; }
	override @property string testDescription() { return "file size of the linked executable binary file"; }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }

	override long sample()
	{
		program.state.link.need();
		return program.exeFile.getSize();
	}
}

class ProgramPhaseTest : ProgramTest
{
	mixin GenerateConstructorProxies;

	abstract @property string statID();
	abstract @property string statName();
	abstract @property string statDescription();

	abstract @property string stageID();
	abstract @property string stageName();
	abstract @property string stageDescription();
	abstract Program.Target getTarget();

	override @property string testID() { return "%s-%s".format(stageID, statID); }
	override @property string testName() { return "%s - %s".format(stageName, statName); }
	override @property string testDescription() { return "%s during %s".format(statDescription, stageDescription); }
}

class ProgramStatTest(string field, Unit _unit, bool _exact, string _name, string _description) : ProgramPhaseTest
{
	mixin GenerateConstructorProxies;

	override @property string statID() { return "%s-%d".format(field.toLower(), program.info.iterations); }
	override @property string statName() { return _name; }
	override @property string statDescription() { return "%s (best of %d runs)".format(_description, program.info.iterations).replace(") (", ", "); }
	override @property Unit unit() { return _unit; }
	override @property bool exact() { return _exact; }

	override long sample()
	{
		auto target = getTarget();
		target.need(exact ? 1 : program.info.iterations);
		auto stats = target.bestStats;
		auto value = mixin("stats." ~ field);
		enforce(value != typeof(value).max, "Value can't be measured");
		return value;
	}
}

alias ProgramRealTimeTest    = ProgramStatTest!("realTime"  , Unit.nanoseconds, false, "real time"  , "total real (elapsed) time spent");
alias ProgramUserTimeTest    = ProgramStatTest!("userTime"  , Unit.nanoseconds, false, "user time"  , "total user time (CPU time spent in userspace) spent");
alias ProgramKernelTimeTest  = ProgramStatTest!("kernelTime", Unit.nanoseconds, false, "kernel time", "total kernel time (CPU time spent in the kernel) spent");
//alias ProgramMemoryUsageTest = ProgramStatTest!("maxRSS"    , Unit.bytes      , true , "max RSS"    , "peak RSS (resident set size memory usage) used");

class ValgrindTest : ProgramPhaseTest
{
	mixin GenerateConstructorProxies;

	abstract @property string[] commandPrefix();
	abstract @property string logFileSwitch();
	abstract long parseLogFile();

	override @property string statDescription() { return statName ~ " (as reported by <tt>" ~ commandPrefix.join(" ") ~ "</tt>)"; }

	@property string valgrindLogFile() { return program.srcDir.buildPath("valgrind.out"); }

	override long sample()
	{
		enforce(!isVersion!"Windows", "Valgrind can't run on Windows");
		auto target = getTarget();
		target.need(1); // dependencies, and ensure it works uninstrumented
		target.run(1, &runValgrind);

		return parseLogFile();
	}

	final void runValgrind()
	{
		auto target = getTarget();
		if (valgrindLogFile.exists)
			valgrindLogFile.remove();
		auto command = commandPrefix ~ [logFileSwitch ~ valgrindLogFile.absolutePath] ~ target.command;
		log("Running program: %s".format(command));
		auto status = spawnProcess(command, stdin, stdout, stderr, null, std.process.Config.none, program.srcDir).wait();
		enforce(status == 0, "Valgrind failed");
	}
}

class ProgramMemoryUsageTest : ValgrindTest
{
	mixin GenerateConstructorProxies;

	override @property string[] commandPrefix() { return ["valgrind", "--tool=massif", "--pages-as-heap=yes"]; }
	override @property string logFileSwitch() { return "--massif-out-file="; }

	override @property string statID() { return "massif"; }
	override @property string statName() { return "peak heap size"; }
	override @property Unit unit() { return Unit.bytes; }
	override @property bool exact() { return true; }

	override long parseLogFile()
	{
		long peakSize = 0;
		foreach (line; File(valgrindLogFile).byLine)
			if (line.skipOver("mem_heap_B="))
			{
				auto size = line.strip().to!long;
				if (peakSize < size)
					peakSize = size;
			}
		return peakSize;
	}
}

class ProgramInstructionCountTest : ValgrindTest
{
	mixin GenerateConstructorProxies;

	override @property string[] commandPrefix() { return ["valgrind", "--tool=callgrind"]; }
	override @property string logFileSwitch() { return "--callgrind-out-file="; }

	override @property string statID() { return "callgrind-insns"; }
	override @property string statName() { return "instructions executed"; }
	override @property Unit unit() { return Unit.instructions; }
	override @property bool exact() { return true; }

	override long parseLogFile()
	{
		foreach (line; File(valgrindLogFile).byLine)
			if (line.skipOver("summary: "))
				return line.strip().to!long;
		throw new Exception("Can't find result in log file");
	}
}

class ProgramCompilePhaseTest(StatTest) : StatTest
{
	mixin GenerateConstructorProxies;
	override @property string stageID() { return "compile"; }
	override @property string stageName() { return "compilation"; }
	override @property string stageDescription() { return "compilation (<tt>dmd -c " ~ dmdFlags.join(" ") ~ "</tt> invocation)"; }
	override Program.Target getTarget() { return program.state.compile; }
}

class ProgramLinkPhaseTest(StatTest) : StatTest
{
	mixin GenerateConstructorProxies;
	override @property string stageID() { return "link"; }
	override @property string stageName() { return "linking"; }
	override @property string stageDescription() { return "linking (<tt>dmd " ~ program.objFile.baseName ~ "</tt> invocation)"; }
	override Program.Target getTarget() { return program.state.link; }
}

class ProgramExecutionPhaseTest(StatTest) : StatTest
{
	mixin GenerateConstructorProxies;
	override @property string stageID() { return "run"; }
	override @property string stageName() { return "execution"; }
	override @property string stageDescription() { return "test program execution"; }
	override Program.Target getTarget() { return program.state.run; }
}

static this()
{
	foreach (info; programs)
	{
		auto program = new Program(info);
		foreach (PhaseTest; TypeTuple!(ProgramCompilePhaseTest, ProgramLinkPhaseTest, ProgramExecutionPhaseTest))
			foreach (StatTest; TypeTuple!(ProgramRealTimeTest, ProgramUserTimeTest, ProgramKernelTimeTest, ProgramInstructionCountTest, ProgramMemoryUsageTest))
				tests ~= new PhaseTest!StatTest(program);
		tests ~= new ObjectSizeTest(program);
		tests ~= new BinarySizeTest(program);
	}
}
