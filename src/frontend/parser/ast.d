module frontend.parser.ast;

import std.stdio;
import std.variant;
import std.format;
import std.range : replace, repeat;
import frontend.type;

enum NodeKind
{
    Program,
    Identifier,

    // literal
    StringLiteral,
    IntLiteral,

    FuncDeclaration,
    VarDeclaration,

    BinaryExpr,
    CallExpr,
}

abstract class Stmt
{
    NodeKind kind;
    Variant value;
    Type type;

    void print(ulong ident = 0);
}

class Program : Stmt
{
    Stmt[] body;
    this(Stmt[] body)
    {
        this.kind = NodeKind.Program;
        this.type = Type(Types.Literal, BaseType.Int);
        this.value = null;
        this.body = body;
    }

    override void print(ulong ident = 0)
    {
        writeln("» Program");
        writeln("Body: {");
        foreach (Stmt node; body)
        {
            node.print(ident + 4);
        }
        writeln("}");
    }
}
