module frontend.type;

import std.conv : to;
import std.algorithm : map;
import std.array : join;

enum BaseType : string
{
    String = "string",

    // Numeric
    Int = "int",
    Double = "double",
    Float = "float",
    Real = "real",

    Bool = "bool",
    Void = "void",

    // unsafe
    Mixed = "mixed",
}

enum TypeQualifier : ubyte
{
    None = 0,
    Const = 1,
    Mutable = 2,
}

enum Types : string
{
    Literal = "literal", // string, int, void, ...
    Alias = "alias", // alias PHUB = int
    Undefined = "undefined", // causes the type to be resolved by the semantic analyzer
    Void = "void", // is a non-literal type
    Array = "array",
    Pointer = "pointer",
    Function = "function",
    Generic = "generic", // maybe
    Struct = "struct", // maybe
    Slice = "slice", // maybe
}

class Type
{
public:
    Types kind;
    BaseType baseType;
    TypeQualifier qualifiers;

    Type elementType; // arrays/pointers/slices
    ulong arraySize; // arrays fixos (0 = dinâmico)
    Type[] parameterTypes; // to funcs
    Type returnType; // to funcs
    string name; // structs/unions/aliases

    // metadata
    bool isUnsafe = false;
    bool isInferred = false;
    uint pointerLevel = 0;
    uint[] arrayDimensions;

    this(Types kind, BaseType baseType = BaseType.Void)
    {
        this.kind = kind;
        this.baseType = baseType;
        this.qualifiers = TypeQualifier.None;
    }

    static Type basic(BaseType base, TypeQualifier qual = TypeQualifier.None)
    {
        auto t = new Type(Types.Literal, base);
        t.qualifiers = qual;
        return t;
    }

    static Type pointer(Type target, TypeQualifier qual = TypeQualifier.None)
    {
        auto t = new Type(Types.Pointer, target.baseType);
        t.elementType = target;
        t.qualifiers = qual;
        t.pointerLevel = target.pointerLevel + 1;
        return t;
    }

    static Type array(Type element, ulong size = 0, TypeQualifier qual = TypeQualifier.None)
    {
        auto t = new Type(Types.Array, element.baseType);
        t.elementType = element;
        t.arraySize = size;
        t.qualifiers = qual;
        return t;
    }

    static Type slice(Type element, TypeQualifier qual = TypeQualifier.None)
    {
        auto t = new Type(Types.Slice, element.baseType);
        t.elementType = element;
        t.qualifiers = qual;
        return t;
    }

    static Type func(Type returnType, Type[] params, TypeQualifier qual = TypeQualifier.None)
    {
        auto t = new Type(Types.Function, BaseType.Void);
        t.returnType = returnType;
        t.parameterTypes = params;
        t.qualifiers = qual;
        return t;
    }

    bool isUndefined() const
    {
        return kind == Types.Undefined;
    }

    bool isPointer() const
    {
        return kind == Types.Pointer;
    }

    bool isArray() const
    {
        return kind == Types.Array;
    }

    bool isSlice() const
    {
        return kind == Types.Slice;
    }

    bool isFunction() const
    {
        return kind == Types.Function;
    }

    bool isBasic() const
    {
        return kind == Types.Literal;
    }

    bool isNumeric() const
    {
        return baseType == BaseType.Int || baseType == BaseType.Float ||
            baseType == BaseType.Double || baseType == BaseType.Real;
    }

    bool isConst() const
    {
        return (qualifiers & TypeQualifier.Const) != 0;
    }

    bool isMutable() const
    {
        return (qualifiers & TypeQualifier.Mutable) != 0;
    }

    bool isCompatibleWith(Type other) const
    {
        if (this.kind != other.kind)
            return false;
        if (this.baseType != other.baseType)
            return false;

        switch (kind)
        {
        case Types.Literal:
            return true;

        case Types.Pointer:
            return elementType.isCompatibleWith(other.elementType);

        case Types.Array:
            return elementType.isCompatibleWith(other.elementType) &&
                (arraySize == 0 || other.arraySize == 0 || arraySize == other.arraySize);

        case Types.Function:
            if (!returnType.isCompatibleWith(other.returnType))
                return false;
            if (parameterTypes.length != other.parameterTypes.length)
                return false;

            foreach (i, param; parameterTypes)
                if (!param.isCompatibleWith(other.parameterTypes[i]))
                    return false;

            return true;

        default:
            return false;
        }
    }

    override string toString() const
    {
        string result = "";

        if (isConst())
            result ~= "const ";
        if (isMutable())
            result ~= "mut ";

        foreach (i; 0 .. pointerLevel)
            result ~= "*";

        switch (kind)
        {
        case Types.Literal:
            result ~= baseType;
            break;

        case Types.Pointer:
            result ~= elementType.toString();
            break;

        case Types.Array:
            result ~= elementType.toString() ~ "[";
            if (arraySize > 0)
                result ~= to!string(arraySize);
            result ~= "]";
            break;

        case Types.Slice:
            result ~= elementType.toString() ~ "[:]";
            break;

        case Types.Function:
            result ~= "(";
            result ~= parameterTypes.map!(p => p.toString()).join(", ");
            result ~= ") -> " ~ returnType.toString();
            break;

        case Types.Alias:
            result ~= name;
            break;

        default:
            result ~= kind;
            break;
        }

        return result;
    }

    ulong getSize() const
    {
        switch (kind)
        {
        case Types.Literal:
            switch (baseType)
            {
            case BaseType.Bool:
                return 1;
            case BaseType.Int:
                return 4;
            case BaseType.Float:
                return 4;
            case BaseType.Double:
                return 8;
            case BaseType.Real:
                return 16;
            case BaseType.String:
                return 8; // ponteiro
            default:
                return 0;
            }

        case Types.Pointer:
            return 8; // 64-bit

        case Types.Array:
            return elementType.getSize() * arraySize;

        case Types.Slice:
            return 16; // ponteiro + tamanho

        default:
            return 0;
        }
    }
}
