module runtime.runtime;

import std.stdio, std.format;
import runtime.runtime_value, runtime.context, runtime.typechecker;
import frontend.parser.ast, frontend.type;

class EurekaRuntime
{
private:
    Context context;
public:
    this(Context context)
    {
        this.context = context;
    }

    RuntimeValue eval(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.IntLiteral:
            return MK_INT(node.value.get!long);
        case NodeKind.VarDeclaration:
            return this.eval(node.value.get!Node);
        case NodeKind.Program:
            RuntimeValue last;
            Program prog = cast(Program) node;
            foreach (Node n; prog.body)
                last = this.eval(n);
            return last;
        default:
            throw new Exception(format("Unknown node kind: '%s'.", node.kind));
        }
    }
}
