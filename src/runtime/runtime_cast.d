module runtime.runtime_cast;

import std.conv, std.format, std.stdio;
import frontend.type, runtime.runtime_value, runtime.typechecker, frontend.parser.ast;

string getValueToString(RuntimeValue value)
{
    string value_;
    if (value.type.baseType == BaseType.Bool)
        value_ = value.value._bool ? "true" : "false";
    else if (value.type.baseType == BaseType.Int)
        value_ = to!string(value.value._int);
    else if (value.type.baseType == BaseType.Float)
        value_ = to!string(value.value._float);
    else if (value.type.baseType == BaseType.Double)
        value_ = to!string(value.value._double);
    else if (value.type.baseType == BaseType.Real)
        value_ = to!string(value.value._real);
    else if (value.type.baseType == BaseType.String)
        value_ = to!string(value.value._string);
    else
        value_ = format("Unknown type '%s'.", value.type.baseType);
    return value_;
}

mixin template CastOperations()
{
    bool isValidCast(T, U)(T from, U to) if (is(T == BaseType) && is(U == BaseType))
    {
        return typeChecker.isComp(Type(Types.Literal, from), Type(Types.Literal, to));
    }

    RuntimeValue performCast(BaseType targetType, RuntimeValue sourceValue)
    {
        switch (targetType)
        {
        case BaseType.String:
            return castToString(sourceValue);
        case BaseType.Int:
            return castToInt(sourceValue);
        case BaseType.Double:
            return castToDouble(sourceValue);
        case BaseType.Real:
            return castToReal(sourceValue);
        case BaseType.Float:
            return castToFloat(sourceValue);
        case BaseType.Bool:
            return castToBool(sourceValue);
        default:
            throw new Exception(format("Cast para tipo '%s' não implementado", targetType));
        }
    }

    private RuntimeValue castToString(RuntimeValue value)
    {
        return MK_STRING(getValueToString(value));
    }

    private RuntimeValue castToInt(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.String:
            try
                return MK_INT(to!long(value.value._string));
            catch (Exception e)
                throw new Exception(format("Não foi possível converter '%s' para int: %s",
                        value.value._string, e.msg));
        case BaseType.Double:
            return MK_INT(cast(long) value.value._double);
        case BaseType.Float:
            return MK_INT(cast(long) value.value._float);
        case BaseType.Bool:
            return MK_INT(value.value._bool ? 1 : 0);
        default:
            throw new Exception(format("Cast de '%s' para int não suportado",
                    value.type.baseType));
        }
    }

    private RuntimeValue castToDouble(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.String:
            try
                return MK_DOUBLE(to!double(value.value._string));
            catch (Exception e)
                throw new Exception(format("Não foi possível converter '%s' para double: %s",
                        value.value._string, e.msg));
        case BaseType.Int:
            return MK_DOUBLE(cast(double) value.value._int);
        case BaseType.Float:
            return MK_DOUBLE(cast(double) value.value._float);
        default:
            throw new Exception(format("Cast de '%s' para double não suportado",
                    value.type.baseType));
        }
    }

    private RuntimeValue castToReal(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.String:
            try
                return MK_REAL(to!real(value.value._string));
            catch (Exception e)
                throw new Exception(format("Não foi possível converter '%s' para real: %s",
                        value.value._string, e.msg));
        case BaseType.Int:
            return MK_REAL(cast(real) value.value._int);
        case BaseType.Float:
            return MK_REAL(cast(real) value.value._float);
        case BaseType.Double:
            return MK_REAL(cast(real) value.value._double);
        default:
            throw new Exception(format("Cast de '%s' para real não suportado",
                    value.type.baseType));
        }
    }

    private RuntimeValue castToFloat(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.String:
            try
                return MK_FLOAT(to!float(value.value._string));
            catch (Exception e)
                throw new Exception(format("Não foi possível converter '%s' para float: %s",
                        value.value._string, e.msg));
        case BaseType.Int:
            return MK_FLOAT(cast(float) value.value._int);
        case BaseType.Double:
            return MK_FLOAT(cast(float) value.value._double);
        default:
            throw new Exception(format("Cast de '%s' para float não suportado",
                    value.type.baseType));
        }
    }

    private RuntimeValue castToBool(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.String:
            return MK_BOOL(value.value._string.length > 0);
        case BaseType.Int:
            return MK_BOOL(value.value._int != 0);
        case BaseType.Double:
            return MK_BOOL(value.value._double != 0.0);
        case BaseType.Float:
            return MK_BOOL(value.value._float != 0.0f);
        default:
            throw new Exception(format("Cast de '%s' para bool não suportado",
                    value.type.baseType));
        }
    }
}

class CastHandler
{
    mixin CastOperations;

    private TypeChecker typeChecker;

    this(TypeChecker tc)
    {
        this.typeChecker = tc;
    }

    RuntimeValue executeCast(Type targetType, RuntimeValue sourceValue)
    {
        if (!typeChecker.isComp(sourceValue.type, targetType))
        {
            throw new Exception(format("Conversão inválida de tipos: '%s' para '%s'",
                    sourceValue.type.baseType, targetType.baseType));
        }
        return performCast(targetType.baseType, sourceValue);
    }
}
