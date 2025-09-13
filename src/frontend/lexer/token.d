module frontend.lexer.token;

import std.variant, std.stdio, std.conv;

enum TokenKind
{
    // Keywords
    Func, // func
    Let, // let
    Return, // return
    Int, // int
    Str, // str
    Void, // void

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

    Eof // EndOfFile
}

struct Token
{
    TokenKind kind;
    Variant value; // raw

    void print()
    {
        writeln("TokenKind: ", to!string(kind));
        writeln("TokenValue: ", to!string(value));
    }
}
