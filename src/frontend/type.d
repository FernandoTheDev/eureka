module frontend.type;

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

enum Types : string
{
    Literal = "literal", // string, int, void, ...
    Alias = "alias", // alias PHUB = int
    Undefined = "undefined", // causes the type to be resolved by the semantic analyzer
    Void = "void", // is a non-literal type
    Array = "array",
}

struct Type
{
    Types type;
    BaseType baseType;
    bool undefined = false;
    ulong dimensions = 0; // for array
}
