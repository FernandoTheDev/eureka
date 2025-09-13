module frontend.type;

enum BaseType : string
{
    String = "string",
    Int = "int",
    Void = "void",
}

enum Types : string
{
    Literal = "literal", // string, int, void, ...
    Alias = "alias", // alias PHUB = int
    Undefined = "undefined", // causes the type to be resolved by the semantic analyzer
    Void = "void", // is a non-literal type
}

struct Type
{
    Types type;
    BaseType baseType;
    bool undefined = false;
}
