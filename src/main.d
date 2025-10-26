module main;

import std.stdio, std.path, std.getopt, std.format, std.datetime.stopwatch, std.file : exists;
import frontend.lexer.token, frontend.lexer.lexer, frontend.parser.ast, frontend
	.parser.parser, frontend.type;
import middle.semantic_analyzer;
import backend.codegen, backend.eureka_engine;
import repl, config, cli, error;

string extractDir(string path)
{
	string dir = dirName(path);
	return dir == "." || dir == "" ? "." : dir;
}

bool checkErrors(DiagnosticError error)
{
	if (error.hasErrors() || error.hasWarnings())
	{
		error.printDiagnostics();
		error.clear();
		return error.hasErrors();
	}
	return false;
}

void main(string[] args)
{
	if (args.length < 2)
	{
		showHelpMessage();
		return;
	}

	string[] dlopnso;
	bool help = false;
	bool repl = false;
	bool ast = false;
	bool tokens_ = false;
	bool version_ = false;
	bool ctxst_ = false;
	bool stat = false;

	getopt(args,
		"v|version", &version_,
		"h|help", &help,
		"context", &ctxst_,
		"stat", &stat,
		"repl", &repl,
		"tokens", &tokens_,
		"ast", &ast,
		"L", &dlopnso,
	);

	if (version_)
	{
		showVersion();
		return;
	}

	if (help)
	{
		showHelpMessage();
		return;
	}

	if (repl)
	{
		// replMode();
		writeln("TODO...");
		return;
	}

	string file = args[1];

	if (!exists(file))
	{
		writefln("The file '%s' does not exist.");
		return;
	}

	DiagnosticError error = new DiagnosticError();

	try
	{
		string source = getFileSource(file);
		auto totalSw = StopWatch(AutoStart.yes);
		Lexer lexer = new Lexer(file, source, extractDir(file), error);
		Token[] tokens = lexer.tokenize();

		if (tokens_)
			writeln(tokens);

		if (checkErrors(error))
			return;

		Program prog = new Parser(tokens, error).parse();

		if (ast)
			prog.print();

		if (checkErrors(error))
			return;

		SemanticAnalyzer anal = new SemanticAnalyzer(error);
		anal.analyze(prog);

		EurekaEngine engine = new EurekaEngine;
		CodeGen cg = new CodeGen(engine, error);
		auto vmSw = StopWatch(AutoStart.yes);
		Instruction[] code = cg.generate(prog);

		if (checkErrors(error))
			return;

		if (ctxst_)
			writeln(code);

		engine.code = code;
		engine.run();

		if (stat)
		{
			writefln("Total time from vm: %d µs", vmSw.peek().total!"usecs");
			writefln("Total time: %d µs", totalSw.peek().total!"usecs");
		}
	}
	catch (Exception e)
	{
		if (checkErrors(error))
			return;
		else
			writeln("ERROR: ", e);
	}
}
