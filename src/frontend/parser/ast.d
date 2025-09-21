module frontend.parser.ast;

import std.stdio, std.variant, std.format, std.conv, frontend.parser.utils, std.string;
import frontend.type, frontend.lexer.token : Loc;

enum NodeKind
{
    Program,
    Identifier,
    Return,
    Extern,

    // literal
    StringLiteral,
    IntLiteral,
    DoubleLiteral,
    BoolLiteral,
    FloatLiteral,
    RealLiteral,

    FuncDeclaration,
    VarDeclaration,

    BinaryExpr,
    CallExpr,

    IfStatement,
    ElseStatement,
    UseStatement,
}

abstract class Node
{
    NodeKind kind;
    Variant value;
    Type type;
    Loc loc;

    void print(ulong ident = 0, bool isLast = false);
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
        this.loc = loc;
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
                node.print(ident + 8, true); // last
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
    Loc loc;
}

class FunctionDeclaration : Node
{
    string name;
    Node[] body;
    FunctionArgument[] args;
    this(string name, ref FunctionArgument[] args, Node[] body, Type type, Loc loc)
    {
        this.kind = NodeKind.FuncDeclaration;
        this.type = type;
        this.value = null;
        this.body = body;
        this.name = name;
        this.args = args;
        this.loc = loc;
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
    this(string id, Loc loc)
    {
        this.kind = NodeKind.Identifier;
        this.type = Type(Types.Undefined, BaseType.Void);
        this.value = id;
        this.loc = loc;
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
    this(string id, Type type, Node value, Loc loc)
    {
        this.kind = NodeKind.VarDeclaration;
        this.id = id;
        this.type = type;
        this.value = value;
        this.loc = loc;
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
    this(bool n, Loc loc)
    {
        this.kind = NodeKind.BoolLiteral;
        this.type = Type(Types.Literal, BaseType.Bool);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "BoolLiteral: " ~ value.get!bool ? "true" : "false", ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class RealLiteral : Node
{
    this(real n, Loc loc)
    {
        this.kind = NodeKind.RealLiteral;
        this.type = Type(Types.Literal, BaseType.Real);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "RealLiteral: " ~ to!string(value.get!double), ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class DoubleLiteral : Node
{
    this(double n, Loc loc)
    {
        this.kind = NodeKind.DoubleLiteral;
        this.type = Type(Types.Literal, BaseType.Double);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "DoubleLiteral: " ~ to!string(value.get!double), ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class FloatLiteral : Node
{
    this(float n, Loc loc)
    {
        this.kind = NodeKind.FloatLiteral;
        this.type = Type(Types.Literal, BaseType.Float);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "FloatLiteral: " ~ to!string(value.get!float), ident);
        println(continuation ~ "└── Type: " ~ cast(string) type.baseType, ident);
    }
}

class IntLiteral : Node
{
    this(long n, Loc loc)
    {
        this.kind = NodeKind.IntLiteral;
        this.type = Type(Types.Literal, BaseType.Int);
        this.value = n;
        this.loc = loc;
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
    this(string n, Loc loc)
    {
        this.kind = NodeKind.StringLiteral;
        this.type = Type(Types.Literal, BaseType.String);
        this.value = n;
        this.loc = loc;
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
    this(string id, Node[] args, Loc loc)
    {
        this.kind = NodeKind.CallExpr;
        this.type = Type(Types.Undefined, BaseType.Void);
        this.value = null;
        this.id = id;
        this.loc = loc;
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
    this(Node expr, bool ret = true, Loc loc)
    {
        this.kind = NodeKind.Return;
        this.type = expr ? expr.type : Type.init;
        this.value = expr;
        this.loc = loc;
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
    this(Node left, Node right, string op, Loc loc)
    {
        this.kind = NodeKind.BinaryExpr;
        this.type = left.type;
        this.left = left;
        this.loc = loc;
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
    this(FunctionDeclaration expr, Loc loc)
    {
        this.kind = NodeKind.Extern;
        this.type = expr ? expr.type : Type.init;
        this.loc = loc;
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

class IfStatement : Node
{
    Node condition;
    Node[] body;
    Node else_;
    this(Node condition, Node[] body, Type type, Node else_ = null, Loc loc)
    {
        this.kind = NodeKind.IfStatement;
        this.type = type;
        this.value = null;
        this.condition = condition;
        this.body = body;
        this.loc = loc;
        this.else_ = else_;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "IfStatement", ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "├── Condition:", ident);

        if (condition !is null)
            condition.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (null)", ident);

        println(continuation ~ "└── Body (" ~ to!string(body.length) ~ " statements):", ident);
        foreach (size_t i, Node node; body)
        {
            if (i == cast(uint)
                body.length - 1)
                node.print(ident + continuation.length + 4, else_ !is null);
            else
                node.print(ident + continuation.length + 4, false);
        }

        if (else_ !is null)
        {
            println(continuation ~ "└── Else:", ident);
            else_.print(ident + continuation.length + 4, true);
        }
    }
}

class ElseStatement : Node
{
    Node[] body;
    this(Node[] body = [], Type type, Loc loc)
    {
        this.kind = NodeKind.ElseStatement;
        this.type = type;
        this.value = null;
        this.loc = loc;
        this.body = body;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "ElseStatement", ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);

        println(continuation ~ "└── Body (" ~ to!string(body.length) ~ " statements):", ident);
        foreach (size_t i, Node node; body)
            node.print(ident + continuation.length + 4, false);
    }
}

class UseStatement : Node
{
    bool[string] symbols;
    this(string file, Loc loc, bool[string] symbols)
    {
        this.kind = NodeKind.UseStatement;
        this.type = Type(Types.Void, BaseType.Void);
        this.value = file;
        this.loc = loc;
        this.symbols = symbols;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "UseStatement", ident);
        println(continuation ~ "├── Type: " ~ cast(string) type.baseType, ident);
        println(continuation ~ "├── Value: " ~ value.get!string, ident);
    }
}
