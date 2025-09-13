module main;

import std.stdio, std.getopt, std.file : exists;
import frontend.lexer.token, frontend.lexer.lexer, frontend.parser.ast, frontend.parser.parser;
import backend.codegen;
import repl, config, cli;

string getFileSource(string file)
{
	File file_ = File(file, "r");
	size_t len = file_.size;
	char[] buff = new char[len];
	file_.rawRead(buff);
	file_.close();
	return cast(string) buff;
}

void main(string[] args)
{
	if (args.length < 2)
	{
		writeln("A '.fiber' file is expected as an argument.");
		return;
	}

	bool help = false;
	bool repl = false;
	bool version_ = false;

	getopt(args, "v|version", &version_, "h|help", &help, "repl", &repl);

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

	try
	{
		string source = getFileSource(file);
		Lexer lexer = new Lexer(file, source);
		Token[] tokens = lexer.tokenize();
		// writeln(tokens);

		Program prog = new Parser(tokens).parse();
		Codegen cg = new Codegen(prog);
		cg.generate();
		writeln(cg.ir());
	}
	catch (Exception e)
	{
		writeln("ERRO: ", e);
	}
}
