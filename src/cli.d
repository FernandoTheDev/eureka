module cli;

import std.stdio, std.format;
import config;

// TODO
void showHelpMessage()
{
    showVersion();
}

void showVersion()
{
    writefln("Fiber - v%s", VERSION);
}
