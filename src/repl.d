module repl;

import std.stdio, std.string, std.array, std.algorithm.searching;
import frontend.lexer.token, frontend.lexer.lexer, frontend.parser.ast, frontend.parser.parser;
import frontend.type;
import runtime.context, runtime.runtime_value, runtime.runtime;
import config, cli;

void showHelpRepl()
{
    writeln("Commands:");
    writeln("  :sb            - Show the buffer");
    writeln("  :cl            - Remove the last line of the buffer");
    writeln("  :cla           - Clear all from buffer");
    writeln("  :run           - Run the code");
    writeln("  :help          - Show this help message");
    writeln("  :libs          - Show loaded libraries");
    writeln("  :addlib <name> - Add a library (.so/.dll)");
    writeln("  :rmlib <name>  - Remove a library");
    writeln("  :exit          - Exit REPL mode");
    writeln("  :quit          - Exit REPL mode");
}

void replMode()
{
    writeln("Eureka - Welcome to ReplMode!");
    showHelpRepl();

    string[] dlopnso;
    string[] buffer;
    string line;
    EurekaRuntime eureka = new EurekaRuntime(new Context(), dlopnso);

    while (true)
    {
        write("> ");
        line = strip(readln());

        if (line.length == 0)
            continue;

        // Command handling
        if (line == ":sb")
        {
            if (buffer.length == 0)
            {
                writeln("Buffer is empty.");
            }
            else
            {
                writeln("Buffer contents:");
                foreach (size_t i, string bufLine; buffer)
                {
                    writefln("%d: %s", i + 1, bufLine);
                }
            }
            continue;
        }

        if (line == ":cla")
        {
            buffer = [];
            writeln("Buffer cleared!");
            continue;
        }

        if (line == ":cl")
        {
            if (buffer.length > 0)
            {
                string removedLine = buffer[$ - 1];
                buffer = buffer[0 .. $ - 1];
                writefln("Removed: %s", removedLine);
            }
            else
            {
                writeln("Buffer is already empty.");
            }
            continue;
        }

        if (line == ":help")
        {
            showHelpRepl();
            continue;
        }

        if (line == ":libs")
        {
            if (dlopnso.length == 0)
            {
                writeln("No libraries loaded.");
            }
            else
            {
                writeln("Loaded libraries:");
                foreach (size_t i, string lib; dlopnso)
                {
                    writefln("%d: %s", i + 1, lib);
                }
            }
            continue;
        }

        if (line.startsWith(":addlib "))
        {
            string libName = line[8 .. $].strip();
            if (libName.length == 0)
            {
                writeln("Usage: :addlib <library_name>");
                continue;
            }

            if (dlopnso.canFind(libName))
                writefln("Library '%s' is already loaded.", libName);
            else
            {
                dlopnso ~= libName;
                // Recreate runtime with new libraries
                eureka = new EurekaRuntime(new Context(), dlopnso);
                writefln("Added library: %s", libName);
            }
            continue;
        }

        if (line.startsWith(":rmlib "))
        {
            string libName = line[7 .. $].strip();
            if (libName.length == 0)
            {
                writeln("Usage: :rmlib <library_name>");
                continue;
            }

            auto index = dlopnso.countUntil(libName);
            if (index == -1)
            {
                writefln("Library '%s' not found.", libName);
            }
            else
            {
                import std.algorithm.mutation : remove;

                dlopnso = dlopnso.remove(index);
                eureka = new EurekaRuntime(new Context(), dlopnso);
                writefln("Removed library: %s", libName);
            }
            continue;
        }

        if (line == ":exit" || line == ":quit")
        {
            writeln("Goodbye!");
            break;
        }

        if (line == ":run")
        {
            if (buffer.length == 0)
            {
                writeln("Buffer is empty. Nothing to run.");
                continue;
            }

            try
            {
                string source = buffer.join("\n");
                Lexer lexer = new Lexer("repl", source);
                Token[] tokens = lexer.tokenize();
                Program prog = new Parser(tokens).parse();
                eureka.eval(prog);

                writeln("Execution completed.");
            }
            catch (Exception e)
            {
                writefln("ERROR: %s", e.msg);
            }
            continue;
        }

        // If it's not a command, add to buffer
        if (line.startsWith(":"))
        {
            writefln("Unknown command: %s", line);
            writeln("Type :help for available commands.");
        }
        else
        {
            buffer ~= line;
            writefln("Added line %d to buffer.", buffer.length);
        }
    }
}
