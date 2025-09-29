module runtime.runtime_value;

import std.variant;
import frontend.type, frontend.parser.ast;

union ValueData
{
    long _int;
    float _float;
    double _double;
    real _real;
    bool _bool;
    string _string;
    RuntimeValue[] _array;
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
    return RuntimeValue(new Type(Types.Literal, BaseType.Int), value);
}

RuntimeValue MK_ARRAY(RuntimeValue[] v, Type type)
{
    ValueData value;
    value._array = v;
    return RuntimeValue(type, value);
}

RuntimeValue MK_FLOAT(float n = 0.0)
{
    ValueData value;
    value._float = n;
    return RuntimeValue(new Type(Types.Literal, BaseType.Float), value);
}

RuntimeValue MK_DOUBLE(double n = 0.0)
{
    ValueData value;
    value._double = n;
    return RuntimeValue(new Type(Types.Literal, BaseType.Double), value);
}

RuntimeValue MK_REAL(real n = 0.0)
{
    ValueData value;
    value._real = n;
    return RuntimeValue(new Type(Types.Literal, BaseType.Real), value);
}

RuntimeValue MK_STRING(string str = "")
{
    ValueData value;
    value._string = str;
    return RuntimeValue(new Type(Types.Literal, BaseType.String), value);
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
    return RuntimeValue(new Type(Types.Literal, BaseType.Bool), value);
}

RuntimeValue MK_VOID()
{
    ValueData value;
    value._int = 0;
    return RuntimeValue(new Type(Types.Void, BaseType.Void), value);
}
