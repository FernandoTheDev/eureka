import core.stdc.stdio : c_printf = printf, putchar, getchar, scanf, fgets, stdin;
import core.stdc.stdlib : atoi, atof;
import std.string : toStringz;
import std.conv : to;
import frontend.type, runtime.runtime_value, config : LIMIT;

extern (C):

RuntimeValue print(RuntimeValue[LIMIT] values, size_t argCount)
{
    for (size_t i; i < argCount; i++)
    {
        RuntimeValue value = values[i];

        if (value.type.kind == Types.Array)
        {
            c_printf("Array<%s>[", cast(const char*) value.type.baseType);
            for (size_t j; j < value.value._array.length; j++)
            {
                RuntimeValue v = value.value._array[j];
                RuntimeValue[LIMIT] v_;
                v_[0] = v;
                print(v_, 1);
                if (j + 1 < value.value._array.length)
                    c_printf(", ");
            }
            c_printf("]");
        }

        if (value.type.baseType == BaseType.Bool)
            c_printf("%s", value.value._bool ? "true".toStringz() : "false".toStringz());
        else if (value.type.baseType == BaseType.Int)
            c_printf("%lld", value.value._int);
        else if (value.type.baseType == BaseType.Float)
            c_printf("%f", value.value._float);
        else if (value.type.baseType == BaseType.Double)
            c_printf("%.14f", value.value._double);
        else if (value.type.baseType == BaseType.Real)
            c_printf("%.18Lg", value.value._real);
        else if (value.type.baseType == BaseType.String)
            c_printf("%s", value.value._string.toStringz());
        else
            c_printf("Unknown type '%s'.", cast(const char*) value.type.baseType);
    }
    return MK_VOID();
}

RuntimeValue println(RuntimeValue[LIMIT] values, size_t argCount)
{
    print(values, argCount);
    c_printf("\n");
    return MK_VOID();
}

RuntimeValue eprintf(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount == 0)
    {
        throw new Exception("eprintf requires at least one argument (format string)");
    }

    const(char)* message = values[0].value._string.toStringz();
    size_t argI = 1;
    size_t messageLen = values[0].value._string.length;

    for (size_t i = 0; i < messageLen; i++)
    {
        char ch = message[i];

        if (ch == '%')
        {
            if (i + 1 >= messageLen)
            {
                throw new Exception("Invalid format: '%' at end of string");
            }

            i++;
            ch = message[i];

            switch (ch)
            {
            case 's':
                if (argI >= argCount)
                {
                    throw new Exception("Not enough arguments for format specifiers");
                }
                c_printf("%s", values[argI].value._string.toStringz());
                argI++;
                break;

            case 'd':
                if (argI >= argCount)
                {
                    throw new Exception("Not enough arguments for format specifiers");
                }
                c_printf("%lld", values[argI].value._int);
                argI++;
                break;

            case 'f':
                if (argI >= argCount)
                {
                    throw new Exception("Not enough arguments for format specifiers");
                }
                if (values[argI].type.baseType == BaseType.Float)
                    c_printf("%f", values[argI].value._float);
                else if (values[argI].type.baseType == BaseType.Double)
                    c_printf("%f", values[argI].value._double);
                else if (values[argI].type.baseType == BaseType.Real)
                    c_printf("%Lg", values[argI].value._real);
                argI++;
                break;

            case 'b':
                if (argI >= argCount)
                {
                    throw new Exception("Not enough arguments for format specifiers");
                }
                c_printf("%s", values[argI].value._bool ? "true".toStringz() : "false".toStringz());
                argI++;
                break;

            case '%':
                putchar('%');
                break;

            default:
                throw new Exception("Invalid format specifier: '%" ~ ch ~ "'");
            }
        }
        else
        {
            if (ch == '\\')
            {
                i++;
                ch = message[i];

                switch (ch)
                {
                case '\\':
                    putchar('\\');
                    argI++;
                    continue;

                case 'n':
                    c_printf("\n");
                    argI++;
                    continue;

                default:
                    throw new Exception("Invalid escape specifier: '\\" ~ ch ~ "'");
                }
            }
            putchar(ch);
        }
    }

    return MK_VOID();
}

RuntimeValue put(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1)
    {
        throw new Exception("put requires exactly one argument");
    }

    char ch;
    if (values[0].type.baseType == BaseType.Int)
        ch = cast(char) values[0].value._int;
    else if (values[0].type.baseType == BaseType.String && values[0].value._string.length > 0)
        ch = values[0].value._string[0];
    else
        throw new Exception("put requires an integer or non-empty string");

    putchar(ch);
    return MK_VOID();
}

RuntimeValue input(RuntimeValue[LIMIT] values, size_t argCount)
{
    import core.stdc.string : strlen, strchr;
    import core.stdc.stdio : printf;

    printf("%s", values[0].value._string.toStringz());
    char[1024] buffer;
    if (!fgets(buffer.ptr, buffer.length, stdin))
        throw new Exception("Failed to read line");

    // Remove newline if present
    char* newlinePos = strchr(buffer.ptr, '\n');
    if (newlinePos)
        *newlinePos = '\0';

    string result = cast(string) buffer[0 .. strlen(buffer.ptr)].dup;
    return MK_STRING(result);
}

RuntimeValue toString(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1)
        throw new Exception("toString requires exactly one argument");

    string result;
    RuntimeValue value = values[0];

    if (value.type.baseType == BaseType.Int)
        result = value.value._int.to!string;
    else if (value.type.baseType == BaseType.Bool)
        result = value.value._bool ? "true" : "false";
    else if (value.type.baseType == BaseType.String)
        result = value.value._string;
    else
        throw new Exception("Cannot convert unknown type to string");

    return MK_STRING(result);
}

RuntimeValue toInt(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1)
    {
        throw new Exception("toInt requires exactly one argument");
    }

    long result;
    RuntimeValue value = values[0];

    if (value.type.baseType == BaseType.String)
    {
        try
        {
            result = value.value._string.to!long;
        }
        catch (Exception)
        {
            throw new Exception("Invalid integer format in string");
        }
    }
    else if (value.type.baseType == BaseType.Bool)
        result = value.value._bool ? 1 : 0;
    else if (value.type.baseType == BaseType.Int)
        result = value.value._int;
    else
        throw new Exception("Cannot convert unknown type to integer");

    return MK_INT(result);
}

RuntimeValue toBool(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1)
    {
        throw new Exception("toBool requires exactly one argument");
    }

    bool result;
    RuntimeValue value = values[0];

    if (value.type.baseType == BaseType.Int)
        result = value.value._int != 0;
    else if (value.type.baseType == BaseType.String)
        result = value.value._string == "true" || value.value._string == "1";
    else if (value.type.baseType == BaseType.Bool)
        result = value.value._bool;
    else
        throw new Exception("Cannot convert unknown type to boolean");

    return MK_BOOL(result);
}

RuntimeValue flush(RuntimeValue[LIMIT] values, size_t argCount)
{
    import core.stdc.stdio : fflush, stdout;

    fflush(stdout);
    return MK_VOID();
}

RuntimeValue estrlen(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1 || values[0].type.baseType != BaseType.String)
    {
        throw new Exception("getStringLength requires exactly one string argument");
    }

    return MK_INT(cast(long) values[0].value._string.length);
}

RuntimeValue etypeof(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1)
    {
        throw new Exception("etypeof requires exactly one argument");
    }
    string type = cast(string) values[0].type.baseType;
    return MK_STRING(type);
}
