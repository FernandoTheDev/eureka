module stdlib.array;

import core.stdc.stdio : c_printf = printf, putchar, getchar, scanf, fgets, stdin;
import core.stdc.stdlib : atoi, atof;
import std.string : toStringz;
import std.conv : to;
import frontend.type, runtime.runtime_value, config : LIMIT;

extern (C):

RuntimeValue array_push(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 2)
    {
        // Error
    }

    if (values[0].type.type != Types.Array)
    {
        // Error
    }

    if (values[0].type.baseType != BaseType.Mixed)
    {
        if (values[0].type.baseType != values[1].type.baseType)
        {
            // Error
        }
    }

    values[0].value._array = values[0].value._array ~ values[1];
    return values[0];
}
