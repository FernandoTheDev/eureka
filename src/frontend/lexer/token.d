module frontend.lexer.token;

import std.variant, std.stdio, std.conv;

enum TokenKind
{
    // Keywords
    Func, // func
    Let, // let
    Return, // return
    Extern, // extern
    Variadic, // variadic, ...
    For, // for
    While, // while
    Do, // do {} while (1 == 1)
    If, // if
    Else, // else
    Break, // break
    Continue, // continue
    Use, // use
    Cast, // cast
    In, // in

    // types
    Double, // double
    Real, // real
    Float, // float
    Int, // int
    Bool, // bool
    Str, // str
    Void, // void
    Mixed, // mixed <- unsafe
    True, // true
    False, // false

    Identifier, // ID
    Number, // 0-9
    String, // "FernandoDev"

    // Symbols
    LParen, // (
    RParen, // )
    LBrace, // {
    RBrace, // }
    LBracket, // [
    RBracket, // ]
    Plus, // +
    PlusPlus, // ++
    Minus, // -
    MinusMinus, // --
    Star, // *
    Slash, // /
    Comma, // ,
    Colon, // :
    SemiColon, // ;
    Equals, // =
    Dot, // .
    Range, // ..
    RangeEquals, // ..=
    Bang, // !
    Modulo, // %

    GreaterThan, // >
    GreaterThanEquals, // >=
    LessThan, // <
    LessThanEquals, // <=
    Or, // ||
    And, // &&
    PlusEquals, // +=

    EqualsEquals, // ==

    Eof // EndOfFile
}

struct Token
{
    TokenKind kind;
    Variant value; // raw
    Loc loc;

    void print()
    {
        writeln("TokenKind: ", to!string(kind));
        writeln("TokenValue: ", to!string(value));
        writeln("Loc: ", loc);
    }
}

struct Loc
{
    string filename;
    string dir;
    ulong line;
    ulong start; // in lineOffset
    ulong end; // in lineOffset
}
