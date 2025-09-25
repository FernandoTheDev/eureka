module frontend.lexer.lexer;

import std.stdio, std.conv, std.variant, std.ascii, std.format, std.exception;
import frontend.lexer.token, error;

class Lexer
{
private:
    string source = "";
    string filename = "";
    string dir = ".";
    long offset = 0;
    long line = 1;
    long lineOffset = 0;
    Token[] tokens = [];
    TokenKind[string] keywords;
    TokenKind[string] symbols;
    DiagnosticError error;

    void setKeywords()
    {
        keywords["func"] = TokenKind.Func;
        keywords["let"] = TokenKind.Let;
        keywords["return"] = TokenKind.Return;
        keywords["extern"] = TokenKind.Extern;
        keywords["variadic"] = TokenKind.Variadic;
        keywords["if"] = TokenKind.If;
        keywords["else"] = TokenKind.Else;
        keywords["use"] = TokenKind.Use;
        keywords["for"] = TokenKind.For;
        keywords["while"] = TokenKind.While;
        keywords["do"] = TokenKind.Do;
        keywords["break"] = TokenKind.Break;
        keywords["continue"] = TokenKind.Continue;
        keywords["cast"] = TokenKind.Cast;
        keywords["mixed"] = TokenKind.Mixed;
        keywords["in"] = TokenKind.In;

        // types
        // numeric
        keywords["int"] = TokenKind.Int;
        keywords["float"] = TokenKind.Float;
        keywords["double"] = TokenKind.Double;
        keywords["real"] = TokenKind.Real;

        keywords["bool"] = TokenKind.Bool;
        keywords["str"] = TokenKind.Str;
        keywords["void"] = TokenKind.Void;
        keywords["true"] = TokenKind.True;
        keywords["false"] = TokenKind.False;
    }

    void setSymbols()
    {
        symbols["("] = TokenKind.LParen;
        symbols[")"] = TokenKind.RParen;
        symbols["{"] = TokenKind.LBrace;
        symbols["}"] = TokenKind.RBrace;
        symbols["["] = TokenKind.LBracket;
        symbols["]"] = TokenKind.RBracket;
        symbols["+"] = TokenKind.Plus;
        symbols["-"] = TokenKind.Minus;
        symbols["*"] = TokenKind.Star;
        symbols["/"] = TokenKind.Slash;
        symbols[":"] = TokenKind.Colon;
        symbols[","] = TokenKind.Comma;
        symbols[";"] = TokenKind.SemiColon;
        symbols["="] = TokenKind.Equals;
        symbols[">"] = TokenKind.GreaterThan;
        symbols[">="] = TokenKind.GreaterThanEquals;
        symbols["<"] = TokenKind.LessThan;
        symbols["<="] = TokenKind.LessThanEquals;
        symbols["=="] = TokenKind.EqualsEquals;
        symbols["."] = TokenKind.Dot;
        symbols["!"] = TokenKind.Bang;
        symbols["%"] = TokenKind.Modulo;

        // 2
        symbols["||"] = TokenKind.Or;
        symbols["&&"] = TokenKind.And;
        symbols[".."] = TokenKind.Range;
        symbols["++"] = TokenKind.PlusPlus;
        symbols["--"] = TokenKind.MinusMinus;
        symbols["+="] = TokenKind.PlusEquals;

        // 3
        symbols["..."] = TokenKind.Variadic;
        symbols["..="] = TokenKind.RangeEquals;
    }

    bool lexChar(char c)
    {
        string ch = to!string(c);

        if (offset + 2 < source.length)
        {
            string three = ch ~ source[offset + 1] ~ source[offset + 2];
            if (three in symbols)
            {
                createToken(symbols[three], Variant(three), three.length);
                return true;
            }
        }

        if (offset + 1 < source.length)
        {
            string two = ch ~ source[offset + 1];
            if (two in symbols)
            {
                createToken(symbols[two], Variant(two), two.length);
                return true;
            }
        }

        if (ch in symbols)
        {
            createToken(symbols[ch], Variant(ch), 1);
            return true;
        }

        return false;
    }

    Loc createLoc(ulong len, long line_ = -1)
    {
        return Loc(filename, dir, line_ == -1 ? line : line_, lineOffset - len + 1, lineOffset);
    }

    void createToken(TokenKind kind, Variant value, ulong len)
    {
        tokens ~= Token(kind, value, createLoc(len));
    }

    void advance(int count = 1)
    {
        for (int i = 0; i < count; i++)
        {
            if (offset < source.length)
            {
                if (source[offset] == '\n')
                {
                    line++;
                    lineOffset = 0;
                }
                else
                {
                    lineOffset++;
                }
                offset++;
            }
        }
    }

    char peek(int lookahead = 0)
    {
        long pos = offset + lookahead;
        return (pos < source.length) ? source[pos] : '\0';
    }

public:
    this(string filename = "", string source = "", string dir = ".", DiagnosticError error)
    {
        this.filename = filename;
        this.source = source;
        this.dir = dir;
        this.error = error;
        setKeywords();
        setSymbols();
    }

    Token[] tokenize()
    {
        while (offset < source.length)
        {
            char ch = source[offset];

            if (ch == '\n')
            {
                advance();
                continue;
            }

            if (isWhite(ch))
            {
                advance();
                continue;
            }

            if (isAlpha(ch) || ch == '_')
            {
                long startOffset = lineOffset;
                string id;

                while (offset < source.length && (isAlpha(peek()) || peek() == '_' || isDigit(
                        peek())))
                {
                    id ~= to!string(peek());
                    advance();
                }

                if (id in keywords)
                    createToken(keywords[id], Variant(id), id.length + 1);
                else
                    createToken(TokenKind.Identifier, Variant(id), id.length + 1);
                continue;
            }

            if (isDigit(ch))
            {
                long startOffset = lineOffset;
                string n;
                bool isDouble = false;

                while (offset < source.length && (isDigit(peek()) || peek() == '_'))
                {
                    if (peek() != '_')
                        n ~= to!string(peek());
                    advance();
                }

                if (offset < source.length && peek() == '.' && source[offset + 1] != '.')
                {
                    n ~= ".";
                    advance();
                    isDouble = true;

                    while (offset < source.length && isDigit(peek()))
                    {
                        n ~= to!string(peek());
                        advance();
                    }
                }

                if (offset < source.length)
                {
                    char suffix = peek();
                    if (suffix == 'F' || suffix == 'f')
                    {
                        advance();
                        createToken(TokenKind.Float, Variant(n), n.length + 1);
                    }
                    else if (suffix == 'D' || suffix == 'd')
                    {
                        advance();
                        createToken(TokenKind.Double, Variant(n), n.length + 1);
                    }
                    else if (suffix == 'L')
                    {
                        advance();
                        createToken(TokenKind.Real, Variant(n), n.length + 1);
                    }
                    else if (isDouble)
                        createToken(TokenKind.Double, Variant(n), n.length + 1);
                    else
                        createToken(TokenKind.Number, Variant(n), n.length + 1);
                }
                else
                {
                    if (isDouble)
                        createToken(TokenKind.Double, Variant(n), n.length + 1);
                    else
                        createToken(TokenKind.Number, Variant(n), n.length + 1);
                }
                continue;
            }

            if (ch == '/' && offset + 1 < source.length && source[offset + 1] == '/')
            {
                while (offset < source.length && peek() != '\n')
                {
                    advance();
                }
                continue;
            }

            if (lexChar(ch))
            {
                if (offset + 2 < source.length)
                {
                    string three = to!string(ch) ~ source[offset + 1] ~ source[offset + 2];
                    if (three in symbols)
                    {
                        advance(3);
                        continue;
                    }
                }

                if (offset + 1 < source.length)
                {
                    string two = to!string(ch) ~ source[offset + 1];
                    if (two in symbols)
                    {
                        advance(2);
                        continue;
                    }
                }

                advance();
                continue;
            }

            // Strings
            if (ch == '"')
            {
                long line_ = line;
                advance();
                string buff;

                while (offset < source.length && peek() != '"')
                {
                    buff ~= to!string(peek());
                    advance();
                }

                if (offset < source.length && peek() == '"')
                {
                    advance();
                    createToken(TokenKind.String, Variant(buff), buff.length + 3);
                }
                else
                {
                    error.addError(Diagnostic("Unterminated string literal", createLoc(1, line_)));
                    createToken(TokenKind.String, Variant(buff), buff.length + 1);
                }
                continue;
            }

            error.addError(Diagnostic(format("Invalid char '%c'", ch), createLoc(1)));
            advance();
        }

        tokens ~= Token(TokenKind.Eof, Variant(null));
        return tokens;
    }
}
