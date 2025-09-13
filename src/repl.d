module repl;

import std.stdio, std.string, std.array;
import frontend.lexer.token, frontend.lexer.lexer, frontend.parser.ast, frontend.parser.parser;
import backend.codegen;
import config, cli;

void showHelpRepl()
{
    writeln("Commands: ");
    writeln("   :sb  - Show the buffer");
    writeln("   :cl  - Remove the last line of the buffer");
    writeln("   :cla - Clear all from buffer");
    writeln("   :run - Run the code");
    writeln("   :sir - Show the IR code");
}

string genIR(string code)
{
    Lexer lexer = new Lexer("repl", code);
    Token[] tokens = lexer.tokenize();

    Program prog = new Parser(tokens).parse();
    Codegen cg = new Codegen(prog);
    cg.generate();
    return cg.ir();
}

void replMode()
{
    // main loop
    writeln("Welcome to ReplMode!");
    showHelpRepl();
    string[] buffer;
    string line;
    while (true)
    {
        write("> ");
        line = strip(readln());

        if (line == ":sb")
        {
            writeln(buffer);
            continue;
        }

        if (line == ":sir")
        {
            writeln(genIR(join(buffer, " ")));
            continue;
        }

        if (line == ":cla")
        {
            buffer = [];
            writeln("Done!");
            continue;
        }

        if (line == ":cl")
        {
            if (buffer.length > 0)
                buffer = buffer[0 .. $ - 1];
            writeln("Done!");
            continue;
        }

        buffer ~= line;
    }
}
