module frontend.lexer.lexer;

import std.stdio, std.conv, std.variant, std.ascii, std.format, std.exception;
import frontend.lexer.token;

class Lexer
{
private:
    string source = "";
    string filename = "";
    long offset = 0;
    long lineOffset = 0;
    Token[] tokens = [];
    TokenKind[string] keywords;
    TokenKind[char] singleSymbols;

    void setKeywords()
    {
        keywords["func"] = TokenKind.Func;
        keywords["let"] = TokenKind.Let;
        keywords["return"] = TokenKind.Return;
        keywords["int"] = TokenKind.Int;
        keywords["str"] = TokenKind.Str;
        keywords["void"] = TokenKind.Void;
    }

    void setSymbols()
    {
        singleSymbols['('] = TokenKind.LParen;
        singleSymbols[')'] = TokenKind.RParen;
        singleSymbols['{'] = TokenKind.LBrace;
        singleSymbols['}'] = TokenKind.RBrace;
        singleSymbols['['] = TokenKind.LBracket;
        singleSymbols[']'] = TokenKind.RBracket;
        singleSymbols['+'] = TokenKind.Plus;
        singleSymbols['-'] = TokenKind.Minus;
        singleSymbols['*'] = TokenKind.Star;
        singleSymbols['/'] = TokenKind.Slash;
        singleSymbols[':'] = TokenKind.Colon;
        singleSymbols[','] = TokenKind.Comma;
        singleSymbols[';'] = TokenKind.SemiColon;
        singleSymbols['='] = TokenKind.Equals;
    }

    bool lexChar(char ch)
    {
        if (ch !in singleSymbols)
            return false;
        tokens ~= Token(singleSymbols[ch], Variant(to!string(ch)));
        return true;
    }

public:
    this(string filename = "", string source = "")
    {
        this.filename = filename;
        this.source = source;
        setKeywords();
        setSymbols();
    }

    Token[] tokenize()
    {
        while (offset < source.length)
        {
            lineOffset++;
            char ch = source[offset];

            if (ch == '\n')
            {
                lineOffset = 0;
                offset++;
                continue;
            }

            if (isWhite(ch))
            {
                offset++;
                continue;
            }

            if (isAlpha(ch))
            {
                string id;
                while (offset < source.length && (isAlpha(source[offset]) || source[offset] == '_'))
                    id ~= to!string(source[offset++]);

                if (id in keywords)
                    tokens ~= Token(keywords[id], Variant(id));
                else
                    tokens ~= Token(TokenKind.Identifier, Variant(id));
                continue;
            }

            if (isDigit(ch))
            {
                string n;
                while (offset < source.length && isDigit(source[offset]))
                    n ~= to!string(source[offset++]);
                tokens ~= Token(TokenKind.Number, Variant(n));
                continue;
            }

            // comment
            if (ch == '/' && source[offset + 1] == '/')
            {
                while (offset < source.length && source[offset] != '\n')
                    offset++;
                continue;
            }

            // if (ch == '/' && source[++offset] == '*')
            // {
            //     while (offset < source.length && source[offset] != "*")
            //     {

            //     }
            // }

            if (lexChar(ch))
            {
                offset++;
                continue;
            }

            // String
            if (ch == '"')
            {
                offset++; // skip '"'
                string buff;
                while (offset < source.length && source[offset] != '"')
                    buff ~= to!string(source[offset++]);
                tokens ~= Token(TokenKind.String, Variant(buff));
                offset++; // skip '"'
                continue;
            }

            throw new Exception(format("Invalid char '%c'", ch));
        }

        tokens ~= Token(TokenKind.Eof, Variant(null));
        return tokens;
    }
}
