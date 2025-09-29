module main;

import std.stdio, std.path, std.getopt, std.format, std.file : exists;
import frontend.lexer.token, frontend.lexer.lexer, frontend.parser.ast, frontend
	.parser.parser, frontend.type;
import runtime.context, runtime.runtime_value, runtime.runtime;
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
		replMode();
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

		Context context = new Context();
		EurekaRuntime eureka = new EurekaRuntime(context, dlopnso, error);
		eureka.eval(prog);

		if (checkErrors(error))
			return;

		if (stat)
			eureka.printCacheStats();

		if (ctxst_)
		{
			writeln("----- Context State -----");
			foreach (long i, RuntimeValue[string] value; context.contexts)
			{
				writeln("# New Context");
				foreach (string id, RuntimeValue cnt; value)
				{
					writef("%s: %s = ", id, cnt.type.toString());
					if (cnt.type.baseType == BaseType.Int)
						writeln(cnt.value._int);
					if (cnt.type.baseType == BaseType.String)
						writeln(cnt.value._string);
					if (cnt.type.baseType == BaseType.Float)
						writefln("%.6f", cnt.value._float);
					if (cnt.type.baseType == BaseType.Double)
						writefln("%.20f", cnt.value._double);
					if (cnt.type.baseType == BaseType.Real)
						writefln("%.20f", cnt.value._real);
					if (cnt.type.baseType == BaseType.Bool)
						writeln(cnt.value._bool ? "true" : "false");
				}
			}
		}
	}
	catch (Exception e)
	{
		if (checkErrors(error))
			return;
		else
			writeln("ERRO: ", e);
	}
}
