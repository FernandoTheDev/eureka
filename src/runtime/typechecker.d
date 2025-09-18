module runtime.typechecker;

import std.stdio, std.format, std.algorithm;
import frontend.type, frontend.parser.ast;

class TypeChecker
{
private:
public:
    bool isComp(Type left, Type right)
    {
        return isComp(left.baseType, right.baseType);
    }

    bool isComp(BaseType left, BaseType right)
    {
        string leftStr = cast(string) left;
        string rightStr = cast(string) right;

        string[][string] map = [
            "int": ["int"],
            "string": ["string"]
        ];

        if (leftStr !in map || !canFind(map[leftStr], rightStr) || rightStr !in map)
            return false;

        return true;
    }

    bool isNumericType(Node left, Node right)
    {
        return isNumericType(left) && isNumericType(right);
    }

    bool isNumericType(Node node)
    {
        return node.type.baseType == BaseType.Int;
    }

    bool isNumericType(Type ty)
    {
        return isNumericType(ty.baseType);
    }

    bool isNumericType(BaseType bt)
    {
        return bt == BaseType.Int;
    }

    Type inferType(Type left, Type right)
    {
        if (!isComp(left, right))
            throw new Exception(format("Tipos imcompativeis '%s' com '%s'.",
                    cast(string) left.baseType, cast(string) right.baseType)
            );
        if (isNumericType(left) && isNumericType(right))
            return Type(Types.Literal, BaseType.Int, false);
        return Type(Types.Literal, BaseType.String, false);
    }
}
