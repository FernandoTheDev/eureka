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

    static bool isComp(BaseType left, BaseType right)
    {
        string leftStr = cast(string) left;
        string rightStr = cast(string) right;

        string[][string] map = [
            "int": ["int", "float", "double", "real", "string", "bool"],
            "double": ["double", "real", "string"],
            "float": ["float", "double", "real", "string", "int"],
            "string": ["string", "bool", "int", "float", "double", "real"],
            "bool": ["bool", "int", "string"],
            "real": ["real", "string"],
            "mixed": ["mixed"], // unsafe
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
        return bt == BaseType.Int || bt == BaseType.Float || bt == BaseType.Double || bt == BaseType
            .Real;
    }

    Type inferType(Type left, Type right)
    {
        if (!isComp(left, right))
            throw new Exception(format("Tipos imcompativeis '%s' com '%s'.",
                    cast(string) left.baseType, cast(string) right.baseType)
            );
        if (isNumericType(left) && isNumericType(right))
        {
            if (left.baseType == BaseType.Real || right.baseType == BaseType.Real)
                return Type(Types.Literal, BaseType.Real);
            if (left.baseType == BaseType.Float || right.baseType == BaseType.Float)
                return Type(Types.Literal, BaseType.Float);
            if (left.baseType == BaseType.Double || right.baseType == BaseType.Double)
                return Type(Types.Literal, BaseType.Double);
            return Type(Types.Literal, BaseType.Int);
        }
        return Type(Types.Literal, BaseType.String, false);
    }
}
