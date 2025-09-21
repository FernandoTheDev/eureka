module frontend.parser.parser;

import std.format, std.stdio, std.conv, std.variant;
import frontend.lexer.token, frontend.parser.ast, frontend.parser.precedence, frontend.type;

class Parser
{
private:
    Token[] tokens;
    ulong pos = 0; // offset

    Node parsePrefix()
    {
        Token token = this.advance();
        switch (token.kind)
        {
        case TokenKind.Identifier:
            if (this.peek()
                .kind == TokenKind.LParen)
                return parseCallExpr(token.value.get!string);
            return new Identifier(token.value.get!string);
        case TokenKind.True:
            return new BoolLiteral(true);
        case TokenKind.False:
            return new BoolLiteral(false);
        case TokenKind.Number:
            return new IntLiteral(to!long(token.value.get!string));
        case TokenKind.String:
            return new StringLiteral(token.value.get!string);
        case TokenKind.Func:
            return this.parseFuncDecl();
        case TokenKind.Let:
            return this.parseVarDecl();
        case TokenKind.Return:
            return this.parseReturn();
        case TokenKind.Extern:
            return this.parseExtern();
        default:
            throw new Exception("Noo prefix parse function for " ~ to!string(token));
        }
    }

    Extern parseExtern()
    {
        Node value = this.parseExpression(Precedence.LOWEST);
        if (value.kind != NodeKind.FuncDeclaration)
            throw new Exception("Expected 'Function' in extern.");
        return new Extern(cast(FunctionDeclaration) value);
    }

    Return parseReturn()
    {
        Node n;
        if (this.match([TokenKind.SemiColon]))
            return new Return(n, false);
        return new Return(this.parseExpression(Precedence.LOWEST));
    }

    CallExpr parseCallExpr(string id)
    {
        this.match([TokenKind.LParen]);
        Node[] args;
        while (this.peek().kind != TokenKind.RParen && !this.isAtEnd())
        {
            args ~= this.parseExpression(Precedence.LOWEST);
            this.match([TokenKind.Comma]);
        }
        this.consume(TokenKind.RParen, "Expected ')' after call.");
        return new CallExpr(id, args);
    }

    VarDeclaration parseVarDecl()
    {
        Token id = this.consume(TokenKind.Identifier, "Expected a name for variable.");
        Type ty = this.parseType();
        this.consume(TokenKind.Equals, "Expected '=' after variable type.");
        Node value = this.parseExpression(Precedence.LOWEST);
        return new VarDeclaration(id.value.get!string, ty, value);
    }

    FunctionDeclaration parseFuncDecl()
    {
        Type funcType = this.parseType();
        Token id = this.consume(TokenKind.Identifier, "Expected a name for function.");

        FunctionArgument[] args;
        if (this.match([TokenKind.LParen]))
        {
            args = parseFuncArgs();
            this.consume(TokenKind.RParen, "Exected ')' after args in function declaration.");
        }

        Node[] body;
        if (this.match([TokenKind.SemiColon]))
            return new FunctionDeclaration(id.value.get!string, args, body, funcType);

        this.consume(TokenKind.LBrace, "Expected '{' for function body.");
        while (this.peek().kind != TokenKind.RBrace && !this.isAtEnd())
            body ~= this.parseExpression(Precedence.LOWEST);
        this.consume(TokenKind.RBrace, "Expected '}' after function body.");

        return new FunctionDeclaration(id.value.get!string, args, body, funcType);
    }

    FunctionArgument[] parseFuncArgs()
    {
        FunctionArgument[] args;
        while (this.peek().kind != TokenKind.RParen && !this.isAtEnd())
        {
            if (this.match([TokenKind.Variadic]))
            {
                args ~= FunctionArgument("...", Type(Types.Undefined, BaseType.Void, true), Variant(
                        null), false);
                break;
            }
            Token id = this.consume(TokenKind.Identifier, "Expected an id for argument name.");
            Type ty = this.parseType();
            args ~= FunctionArgument(id.value.get!string, ty, Variant(null), false);
            this.match([TokenKind.Comma]);
        }
        return args;
    }

    Type parseType()
    {
        // TODO: arrays suport
        Token ty = this.advance();
        switch (ty.kind)
        {
        case TokenKind.Int:
            return Type(Types.Literal, BaseType.Int);
        case TokenKind.Bool:
            return Type(Types.Literal, BaseType.Bool);
        case TokenKind.Str:
            return Type(Types.Literal, BaseType.String);
        case TokenKind.Void:
            return Type(Types.Void, BaseType.Void);
        default:
            return Type(Types.Undefined, BaseType.Void);
        }
    }

    BinaryExpr parseBinaryExpr(Node left)
    {
        Token op = this.advance();
        Node right = this.parseExpression(this.getPrecedence(op.kind));
        return new BinaryExpr(left, right, op.value.get!string);
    }

    void infix(ref Node leftOld)
    {
        switch (this.peek().kind)
        {
        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.Star:
            leftOld = parseBinaryExpr(leftOld);
            return;
        default:
            return;
        }
    }

    Node parseExpression(Precedence precedence)
    {
        Node left = this.parsePrefix();
        while (!this.isAtEnd() && precedence < this.peekPrecedence())
        {
            ulong oldPos = this.pos;
            this.infix(left);

            if (this.pos == oldPos)
                break;
        }
        return left;
    }

    Node parseNode()
    {
        Node Node = this.parseExpression(Precedence.LOWEST);
        return Node;
    }

    bool isAtEnd()
    {
        return this.peek().kind == TokenKind.Eof;
    }

    Variant next()
    {
        if (this.isAtEnd())
            return Variant(false);
        return Variant(this.tokens[this.pos + 1]);
    }

    Token peek()
    {
        return this.tokens[this.pos];
    }

    Token previous(ulong i = 1)
    {
        return this.tokens[this.pos - i];
    }

    Token advance()
    {
        if (!this.isAtEnd())
            this.pos++;
        return this.previous();
    }

    bool match(TokenKind[] kinds)
    {
        foreach (kind; kinds)
        {
            if (this.check(kind))
            {
                this.advance();
                return true;
            }
        }
        return false;
    }

    bool check(TokenKind kind)
    {
        if (this.isAtEnd())
            return false;
        return this.peek().kind == kind;
    }

    Token consume(TokenKind expected, string message)
    {
        if (this.check(expected))
            return this.advance();
        throw new Exception(format(`Erro de parsing: %s`, message));
    }

    Precedence getPrecedence(TokenKind kind)
    {
        switch (kind)
        {
        case TokenKind.Plus:
        case TokenKind.Minus:
            return Precedence.SUM;
        case TokenKind.Star:
        case TokenKind.Slash:
            return Precedence.MUL;
        default:
            return Precedence.LOWEST;
        }
    }

    Precedence peekPrecedence()
    {
        return this.getPrecedence(this.peek().kind);
    }

public:
    this(Token[] tokens = [])
    {
        this.tokens = tokens;
    }

    Program parse()
    {
        Program program = new Program([]);
        try
        {
            while (!this.isAtEnd())
                program.body ~= this.parseNode();
            if (this.tokens.length == 0)
                return program;
        }
        catch (Exception e)
        {
            writeln("Erro:", e.msg);
            throw e;
        }
        return program;
    }
}
