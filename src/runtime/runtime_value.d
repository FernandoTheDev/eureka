module runtime.runtime_value;

import std.variant;
import frontend.type, frontend.parser.ast;

union ValueData
{
    long _int;
    bool _bool;
    string _string;
    FunctionDeclaration _function;
}

struct RuntimeValue
{
    Type type;
    ValueData value;
    bool haveReturn = false;
    bool asStd = false;
    bool asExtern = false;
}

RuntimeValue MK_INT(long n = 0)
{
    ValueData value;
    value._int = n;
    return RuntimeValue(Type(Types.Literal, BaseType.Int), value);
}

RuntimeValue MK_STRING(string str = "")
{
    ValueData value;
    value._string = str;
    return RuntimeValue(Type(Types.Literal, BaseType.String), value);
}

RuntimeValue MK_FUNCTION(FunctionDeclaration fn)
{
    ValueData value;
    value._function = fn;
    return RuntimeValue(fn.type, value);
}

RuntimeValue MK_BOOL(bool b = false)
{
    ValueData value;
    value._bool = b;
    return RuntimeValue(Type(Types.Literal, BaseType.Bool), value);
}

RuntimeValue MK_VOID()
{
    ValueData value;
    value._int = 0;
    return RuntimeValue(Type(Types.Void, BaseType.Void), value);
}
