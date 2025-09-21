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

    // types
    Double, // double
    Real, // real
    Float, // float
    Int, // int
    Bool, // bool
    Str, // str
    Void, // void
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
    Minus, // -
    Star, // *
    Slash, // /
    Comma, // ,
    Colon, // :
    SemiColon, // ;
    Equals, // =
    Dot, // .
    Range, // ..

    GreaterThan, // >
    GreaterThanEquals, // >=
    LessThan, // <
    LessThanEquals, // <=

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
