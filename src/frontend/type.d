module frontend.type;

enum BaseType : string
{
    String = "string",
    Int = "int",
}

enum Types : string
{
    Pointer = "pointer",
    Literal = "literal",
}

struct Type
{
    Types type;
    BaseType baseType;
    ulong pointerLevel = 0;
}
