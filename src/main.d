module main;

import std.stdio;
import std.file : exists;
import frontend.lexer.token, frontend.lexer.lexer;

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
		writeln(lexer.tokenize());
	}
	catch (Exception e)
	{
		writeln("ERRO: ", e);
	}
}
