module runtime.runtime_value;

import std.variant;
import frontend.type;

union ValueData
{
    long _int;
    string _string;
}

struct RuntimeValue
{
    Type type;
    ValueData value;
    bool haveReturn = false;
}

RuntimeValue MK_INT(long n = 0)
{
    ValueData value;
    value._int = n;
    return RuntimeValue(Type(Types.Literal, BaseType.Int), value);
}
