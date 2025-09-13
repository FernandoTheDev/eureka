module frontend.parser.ast;

import std.stdio, std.variant, std.format, std.conv, frontend.parser.utils;
import frontend.type;

enum NodeKind
{
    Program,
    Identifier,
    Return,

    // literal
    StringLiteral,
    IntLiteral,

    FuncDeclaration,
    VarDeclaration,

    BinaryExpr,
    CallExpr,

}

abstract class Node
{
    NodeKind kind;
    Variant value;
    Type type;

    void print(ulong ident = 0);
}

class Program : Node
{
    Node[] body;
    this(Node[] body)
    {
        this.kind = NodeKind.Program;
        this.type = Type(Types.Literal, BaseType.Int);
        this.value = null;
        this.body = body;
    }

    override void print(ulong ident = 0)
    {
        println("» Program", ident);
        println("Body: {", ident);
        foreach (Node node; body)
            node.print(ident + 4);
        println("};", ident);
    }
}

struct FunctionArgument
{
    string name;
    Type type;
    Variant value;
    bool defaultValue;
}

class FunctionDeclaration : Node
{
    string name;
    Node[] body;
    FunctionArgument[] args;
    this(string name, ref FunctionArgument[] args, Node[] body, Type type)
    {
        this.kind = NodeKind.FuncDeclaration;
        this.type = type;
        this.value = null;
        this.body = body;
        this.name = name;
        this.args = args;
    }

    override void print(ulong ident = 0)
    {
        println(format("» Function - %s", name), ident);
        println(format("Type - %s", type), ident);
        println(format("Arguments (%d): [ ", args.length), ident);
        foreach (FunctionArgument arg; args)
        {
            println(format("» Name: %s", arg.name), ident + 4);
            println(format("Type: %s", arg.type), ident + 4);
            println(format("Default: %d", to!int(
                    arg.defaultValue)), ident + 4);
        }
        println("]", ident);
        println("Body: {", ident);
        foreach (Node node; body)
            node.print(ident + 4);
        println("};", ident);
    }
}

class Identifier : Node
{
    this(string id)
    {
        this.kind = NodeKind.Identifier;
        this.type = Type(Types.Undefined, BaseType
                .Void);
        this.value = id;
    }

    override void print(ulong ident = 0)
    {
        println(format("» Identifier - %s", value.get!string), ident);
        println(format("Type - %s", type), ident);
    }
}

class VarDeclaration : Node
{
    string id;
    this(string id, Type type, Node value)
    {
        this.kind = NodeKind.VarDeclaration;
        this.id = id;
        this.type = type;
        this.value = value;
    }

    override void print(ulong ident = 0)
    {
        println(format("» VarDeclaration - %s", id), ident);
        println(
            format("Type - %s", type), ident);
        println("Value: ", ident);
        value.get!Node.print(ident + 4);
    }
}

class IntLiteral : Node
{
    this(long n)
    {
        this.kind = NodeKind.IntLiteral;
        this.type = Type(Types.Literal, BaseType
                .Int);
        this.value = n;
    }

    override void print(ulong ident = 0)
    {
        println(format("» IntLiteral - %d", value.get!long), ident);
        println(format("Type - %s", type), ident);
    }
}

class StringLiteral : Node
{
    this(string n)
    {
        this.kind = NodeKind.StringLiteral;
        this.type = Type(Types.Literal, BaseType
                .String);
        this.value = n;
    }

    override void print(ulong ident = 0)
    {
        println(format("» StringLiteral - %s", value.get!string), ident);
        println(format("Type - %s", type), ident);
    }
}

class CallExpr : Node
{
    string id;
    Node[] args;
    this(string id, Node[] args)
    {
        this.kind = NodeKind.CallExpr;
        this.type = Type(Types.Undefined, BaseType
                .Void);
        this.value = null;
        this.id = id;
        this.args = args;
    }

    override void print(ulong ident = 0)
    {
        println(format("» CallExpr - %s", id), ident);
        println(format("Type - %s", type), ident);
        println(format("Arguments (%d): [ ", args.length), ident);
        foreach (Node arg; args)
            arg.print(ident + 4);
    }
}

class Return : Node
{
    bool ret;
    this(Node expr, bool ret = true)
    {
        this.kind = NodeKind.Return;
        this.type = expr.type;
        this.value = expr;
        this.ret = ret;
    }

    override void print(ulong ident = 0)
    {
        println("» Return", ident);
        println(format("Type - %s", type), ident);
        println("Value: ", ident);
        value.get!Node.print(ident + 4);
    }
}

class BinaryExpr : Node
{
    Node left, right;
    string op;
    this(Node left, Node right, string op)
    {
        this.kind = NodeKind.BinaryExpr;
        this.type = left.type;
        this.left = left;
        this.right = right;
        this.op = op;
    }

    override void print(ulong ident = 0)
    {
        println(format("» BinaryExpr - operator(%s)", op), ident);
        println(format("Type - %s", type), ident);
        println("Left: ", ident);
        left.print(ident + 4);
        println("Right: ", ident);
        left.print(ident + 4);
    }
}
