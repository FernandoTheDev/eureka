module frontend.parser.utils;

import std.stdio, std.array, std.conv;

void println(string message, ulong ident = 0)
{
    writeln(" ".replicate(ident), message);
}

void print(string message, ulong ident = 0)
{
    write(" ".replicate(ident), message);
}
