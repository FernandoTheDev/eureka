module frontend.parser.ast;

import std.stdio, std.variant, std.format, std.conv, frontend.parser.utils, std.string;
import frontend.type;

enum NodeKind
{
    Program,
    Identifier,
    Return,
    Extern,

    // literal
    StringLiteral,
    IntLiteral,
    BoolLiteral,

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

    void print(ulong ident = 0, bool isLast = false);
}

/*
├── Program
│   ├── Body
│   │   ├── FunctionDeclaration
│   │   └── ...
│   └── Type: int
*/

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

    override void print(ulong ident = 0, bool isLast = false)
    {
        println("├── Program", ident);
        println("│   ├── Type: " ~ cast(string) type.baseType, ident);
        println("│   └── Body (" ~ to!string(body.length) ~ " nodes):", ident);
        foreach (size_t i, Node node; body)
        {
            if (i == cast(uint)
                body.length - 1)
                node.print(ident + 8, true); // último item
            else
                node.print(ident + 8, false);
        }
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

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "FunctionDeclaration: " ~ name, ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "├── Arguments (" ~ to!string(args.length) ~ "):", ident);

        foreach (size_t i, FunctionArgument arg; args)
        {
            string argPrefix = (i == cast(uint) args.length - 1) ? "└── " : "├── ";
            println(continuation ~ "│   " ~ argPrefix ~ "Arg: " ~ arg.name, ident);
            println(continuation ~ "│   " ~ (i == cast(uint) args.length - 1 ? "    " : "│   ") ~
                    "├── Type: " ~ cast(string) arg.type.baseType, ident);
            println(continuation ~ "│   " ~ (i == cast(uint) args.length - 1 ? "    " : "│   ") ~
                    "└── HasDefault: " ~ to!string(arg.defaultValue), ident);
        }

        println(continuation ~ "└── Body (" ~ to!string(body.length) ~ " statements):", ident);
        foreach (size_t i, Node node; body)
        {
            if (i == cast(uint)
                body.length - 1)
                node.print(ident + continuation.length + 4, true);
            else
                node.print(ident + continuation.length + 4, false);
        }
    }
}

class Identifier : Node
{
    this(string id)
    {
        this.kind = NodeKind.Identifier;
        this.type = Type(Types.Undefined, BaseType.Void);
        this.value = id;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "Identifier: " ~ value.get!string, ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
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

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "VarDeclaration: " ~ id, ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "└── Value:", ident);
        value.get!Node.print(ident + continuation.length + 4, true);
    }
}

class BoolLiteral : Node
{
    this(bool n)
    {
        this.kind = NodeKind.BoolLiteral;
        this.type = Type(Types.Literal, BaseType.Bool);
        this.value = n;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "BoolLiteral: " ~ value.get!bool ? "true" : "false", ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class IntLiteral : Node
{
    this(long n)
    {
        this.kind = NodeKind.IntLiteral;
        this.type = Type(Types.Literal, BaseType.Int);
        this.value = n;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "IntLiteral: " ~ to!string(value.get!long), ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class StringLiteral : Node
{
    this(string n)
    {
        this.kind = NodeKind.StringLiteral;
        this.type = Type(Types.Literal, BaseType.String);
        this.value = n;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "StringLiteral: \"" ~ value.get!string ~ "\"", ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class CallExpr : Node
{
    string id;
    Node[] args;
    this(string id, Node[] args)
    {
        this.kind = NodeKind.CallExpr;
        this.type = Type(Types.Undefined, BaseType.Void);
        this.value = null;
        this.id = id;
        this.args = args;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "CallExpr: " ~ id ~ "()", ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "└── Arguments (" ~ to!string(args.length) ~ "):", ident);

        foreach (size_t i, Node arg; args)
        {
            if (i == cast(uint) args.length - 1)
                arg.print(ident + continuation.length + 4, true);
            else
                arg.print(ident + continuation.length + 4, false);
        }
    }
}

class Return : Node
{
    bool ret;
    this(Node expr, bool ret = true)
    {
        this.kind = NodeKind.Return;
        this.type = expr ? expr.type : Type.init;
        this.value = expr;
        this.ret = ret;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "Return" ~ (ret ? "" : " (void)"), ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "└── Expression:", ident);

        if (value.convertsTo!Node && !value.hasValue())
            value.get!Node.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (null)", ident);
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

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "BinaryExpr: (" ~ op ~ ")", ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "├── Left:", ident);

        if (left !is null)
            left.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (null)", ident);

        println(continuation ~ "└── Right:", ident);

        if (right !is null)
            right.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (null)", ident);
    }
}

class Extern : Node
{
    this(FunctionDeclaration expr)
    {
        this.kind = NodeKind.Extern;
        this.type = expr ? expr.type : Type.init;
        this.value = expr;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "Extern (" ~ value.get!FunctionDeclaration.name ~ ")", ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "└── Expression:", ident);
        value.get!Node.print(ident + continuation.length + 4, true);
    }
}
