module backend.codegen;

import std.stdio, std.variant, std.format, std.conv;
import frontend.type, frontend.parser.ast;
import lib.d.fiber_module, lib.d.fiber_block, lib.d.fiber_counter, lib.d.fiber_function, lib
    .d.fiber_value;

class Codegen
{
private:
    Program prog;
    FiberModule mod;
    FiberBlock block;
    FiberValue[string] context; // TODO: improve this

    FiberValue gen(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.IntLiteral:
            return block.varTmp(cast(FiberType) node.type.baseType, to!string(node.value.get!long));
        case NodeKind.StringLiteral:
            return block.varTmp(cast(FiberType) node.type.baseType, format("\"%s\"", node
                    .value.get!string));
        case NodeKind.VarDeclaration:
            VarDeclaration var = cast(VarDeclaration) node;
            FiberValue value = this.gen(node.value.get!Node);
            this.context[var.id] = value;
            return value;
        case NodeKind.Identifier:
            // TODO: check this
            Identifier id = cast(Identifier) node;
            return this.context[id.value.get!string];
        case NodeKind.FuncDeclaration:
            return genFuncDecl(cast(FunctionDeclaration) node);
        case NodeKind.CallExpr:
            return genCallExpr(cast(CallExpr) node);
        default:
            throw new Exception(format("Unkown node '%s'.", node.kind));
        }
    }

    FiberValue genCallExpr(CallExpr node)
    {
        if (node.id == "print")
        {
            foreach (arg; node.args)
            {
                block.print(this.gen(arg));
            }
        }

        return Value("\0", "", false, FiberType.Void);
    }

    FiberValue genFuncDecl(FunctionDeclaration node)
    {
        FiberFunction func = new FiberFunction(node.name, cast(FiberType) node.type.baseType, [
            ], node.name == "main" ? true : false);
        FiberBlock entry = new FiberBlock(new FiberTempCounter());
        func.setBlock(entry);
        this.block = entry;

        foreach (Node n; node.body)
            this.gen(n);

        if (node.name == "main")
            block.halt();

        mod.addFunc(func);

        return Value("\0", "", false, FiberType.Void);
    }

public:
    this(Program prog, string mod = "main.fir")
    {
        this.prog = prog;
        this.mod = new FiberModule(mod);
    }

    void generate()
    {
        foreach (Node node; prog.body)
            this.gen(node);
    }

    string ir()
    {
        return mod.gen();
    }
}
