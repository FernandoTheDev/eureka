module main;

import std.stdio, std.path, std.getopt, std.file : exists;
import frontend.lexer.token, frontend.lexer.lexer, frontend.parser.ast, frontend.parser.parser;
import runtime.context, runtime.runtime_value, runtime.runtime;
import repl, config, cli;

void main(string[] args)
{
	if (args.length < 2)
	{
		showHelpMessage();
		return;
	}

	string output = "";
	bool help = false;
	bool repl = false;
	bool ast = false;
	bool tokens_ = false;
	bool version_ = false;

	getopt(args,
		"v|version", &version_,
		"h|help", &help,
		"repl", &repl,
		"tokens", &tokens_,
		"ast", &ast,
		"o|output", &output,
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
	if (output == "")
		output = file;

	if (!exists(file))
	{
		writefln("The file '%s' does not exist.");
		return;
	}

	try
	{
		string source = getFileSource(file);
		Lexer lexer = new Lexer(file, source);
		Token[] tokens = lexer.tokenize();

		if (tokens_)
			writeln(tokens);

		Program prog = new Parser(tokens).parse();

		if (ast)
			prog.print();

		Context context = new Context();
		EurekaRuntime eureka = new EurekaRuntime(context);
		writeln(eureka.eval(prog));
	}
	catch (Exception e)
	{
		writeln("ERRO: ", e);
	}
}
