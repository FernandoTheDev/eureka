module frontend.parser.parser;

import std.format, std.stdio, std.conv, std.variant;
import frontend.lexer.token, frontend.parser.ast, frontend.parser.precedence, frontend.type, error;

class Parser
{
private:
    Token[] tokens;
    ulong pos = 0; // offset
    DiagnosticError error;

    Node parsePrefix()
    {
        Token token = this.advance();
        switch (token.kind)
        {
        case TokenKind.Identifier:
            if (this.peek()
                .kind == TokenKind.LParen)
                return parseCallExpr(token.value.get!string, token.loc);
            return new Identifier(token.value.get!string, token.loc);
        case TokenKind.True:
            return new BoolLiteral(true, token.loc);
        case TokenKind.False:
            return new BoolLiteral(false, token.loc);
        case TokenKind.Number:
            return new IntLiteral(to!long(token.value.get!string), token.loc);
        case TokenKind.Double:
            return new DoubleLiteral(to!double(token.value.get!string), token.loc);
        case TokenKind.Real:
            return new RealLiteral(to!real(token.value.get!string), token.loc);
        case TokenKind.Float:
            return new FloatLiteral(to!float(token.value.get!string), token.loc);
        case TokenKind.String:
            return new StringLiteral(token.value.get!string, token.loc);
        case TokenKind.Func:
            return this.parseFuncDecl();
        case TokenKind.Let:
            return this.parseVarDecl();
        case TokenKind.Return:
            return this.parseReturn();
        case TokenKind.Extern:
            return this.parseExtern();
        case TokenKind.If:
            return this.parseIfStatement();
        case TokenKind.Use:
            return this.parseUseStatement();
        default:
            throw new Exception("Noo prefix parse function for " ~ to!string(token));
        }
    }

    UseStatement parseUseStatement()
    {
        bool[string] symbols = null;
        Token file = this.consume(TokenKind.String, "Expected a string to file name.");
        if (this.match([TokenKind.Colon]))
        {
            this.consume(TokenKind.LBrace, "Expected '{' after ':'.");
            while (!this.check(TokenKind.RBrace) && !this.isAtEnd())
            {
                symbols[this.consume(TokenKind.Identifier, "Expected 'id' in import selective.")
                    .value.get!string] = true;
                this.match([TokenKind.Comma]);
            }
            this.consume(TokenKind.RBrace, "Expected '}' after 'use'.");
        }
        return new UseStatement(file.value.get!string, file.loc, symbols);
    }

    IfStatement parseIfStatement()
    {
        Loc start = this.previous().loc;
        Node condition = this.parseExpression(Precedence.LOWEST);
        Node[] body = this.parseBody(true);
        Node else_ = null;

        if (this.peek().kind == TokenKind.Else)
        {
            Loc elseLoc = this.advance().loc;

            if (this.peek().kind == TokenKind.If)
            {
                this.advance();
                Node ifStmt = this.parseIfStatement();
                else_ = ifStmt;
            }
            else
            {
                Node[] elseBody = this.parseBody(true);
                Node elseStmt = new ElseStatement(elseBody, Type(Types.Undefined, BaseType.Void, true), elseLoc);
                else_ = elseStmt;
            }
        }

        return new IfStatement(condition, body, Type(Types.Undefined, BaseType.Void, true), else_, start);
    }

    Extern parseExtern()
    {
        Loc start = this.previous().loc;
        Node value = this.parseExpression(Precedence.LOWEST);
        if (value.kind != NodeKind.FuncDeclaration)
            throw new Exception("Expected 'Function' in extern.");
        return new Extern(cast(FunctionDeclaration) value, start);
    }

    Return parseReturn()
    {
        Node n;
        if (this.match([TokenKind.SemiColon]))
            return new Return(n, false, this.previous().loc);
        n = this.parseExpression(Precedence.LOWEST);
        return new Return(n, true, n.loc);
    }

    CallExpr parseCallExpr(string id, Loc start)
    {
        this.match([TokenKind.LParen]);
        Node[] args;
        while (this.peek().kind != TokenKind.RParen && !this.isAtEnd())
        {
            args ~= this.parseExpression(Precedence.LOWEST);
            this.match([TokenKind.Comma]);
        }
        this.consume(TokenKind.RParen, "Expected ')' after call.");
        return new CallExpr(id, args, start);
    }

    VarDeclaration parseVarDecl()
    {
        Token id = this.consume(TokenKind.Identifier, "Expected a name for variable.");
        Type ty = this.parseType();
        this.consume(TokenKind.Equals, "Expected '=' after variable type.");
        Node value = this.parseExpression(Precedence.LOWEST);
        return new VarDeclaration(id.value.get!string, ty, value, id.loc);
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
            return new FunctionDeclaration(id.value.get!string, args, body, funcType, id.loc);

        body = this.parseBody();
        return new FunctionDeclaration(id.value.get!string, args, body, funcType, id.loc);
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
            args ~= FunctionArgument(id.value.get!string, ty, Variant(null), false, id.loc);
            this.match([TokenKind.Comma]);
        }
        return args;
    }

    Node[] parseBody(bool uniqueStmt = false)
    {
        Node[] body_;

        if (this.peek().kind != TokenKind.LBrace && !uniqueStmt)
            throw new Exception("Expected '{' for body.");

        if (this.peek().kind == TokenKind.LBrace)
        {
            this.consume(TokenKind.LBrace, "Expected '{' for body.");
            while (this.peek().kind != TokenKind.RBrace && !this.isAtEnd())
                body_ ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.RBrace, "Expected '}' after body.");
        }
        else
            body_ ~= this.parseExpression(Precedence.LOWEST);

        return body_;
    }

    Type parseType()
    {
        // TODO: arrays suport
        Token ty = this.advance();
        switch (ty.kind)
        {
        case TokenKind.Int:
            return Type(Types.Literal, BaseType.Int);
        case TokenKind.Float:
            return Type(Types.Literal, BaseType.Float);
        case TokenKind.Double:
            return Type(Types.Literal, BaseType.Double);
        case TokenKind.Real:
            return Type(Types.Literal, BaseType.Real);
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
        return new BinaryExpr(left, right, op.value.get!string, this.getLoc(left.loc, right.loc));
    }

    void infix(ref Node leftOld)
    {
        switch (this.peek().kind)
        {
        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.Star:
        case TokenKind.EqualsEquals:
        case TokenKind.GreaterThan:
        case TokenKind.GreaterThanEquals:
        case TokenKind.LessThanEquals:
        case TokenKind.LessThan:
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
        this.peek().print();
        error.addError(Diagnostic(format(`Parser Error: %s`, message), this.peek().loc));
        throw new Exception(format(`Parser Error: %s`, message));
    }

    Precedence getPrecedence(TokenKind kind)
    {
        switch (kind)
        {
        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.EqualsEquals:
        case TokenKind.GreaterThan:
        case TokenKind.LessThan:
        case TokenKind.LessThanEquals:
        case TokenKind.GreaterThanEquals:
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

    Loc getLoc(ref Loc start, ref Loc end)
    {
        return Loc(start.filename, start.dir, start.line, start.start, end.end);
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
            // ignore
            throw e; // propaga
        }
        return program;
    }
}
