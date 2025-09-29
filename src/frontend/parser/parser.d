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
        case TokenKind.LParen:
            Node value = this.parseExpression(Precedence.CALL);
            this.consume(TokenKind.RParen, "Expected ')' after the value.");
            return value;

        case TokenKind.Identifier:
            if (this.peek()
                .kind == TokenKind.LParen)
                return parseCallExpr(token.value.get!string, token.loc);

            if (this.peek()
                .kind == TokenKind.Equals)
            {
                this.advance(); // skip '='
                Node value = this.parseExpression(Precedence.LOWEST);
                return new VarAssignmentDecl(token.value.get!string, value.type, value, token.loc);
            }

            if (this.check(TokenKind.PlusPlus) || this.check(TokenKind.MinusMinus))
            {
                Token postOp = this.advance();
                Node operand = new Identifier(token.value.get!string, token.loc);
                return new UnaryExpr(postOp.value.get!string, operand, token.loc, true);
            }
            return new Identifier(token.value.get!string, token.loc);

        case TokenKind.PlusPlus:
        case TokenKind.MinusMinus:
        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.Bang:
            Node operand = this.parseExpression(Precedence.HIGHEST);
            return new UnaryExpr(token.value.get!string, operand, token.loc, false);

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
        case TokenKind.LBracket:
            Node[] values;
            while (!this.check(TokenKind.RBracket) && !this.isAtEnd())
            {
                values ~= this.parseExpression(Precedence.LOWEST);
                this.match([TokenKind.Comma]);
            }
            Loc end = this.consume(TokenKind.RBracket, "Expected ']' after array literal.").loc;
            return new ArrayLiteral(values, new Type(Types.Array, values.length > 0 ? values[0].type.baseType
                    : BaseType.Void), this.getLoc(token.loc, end));

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
        case TokenKind.Cast:
            return this.parseCastExpr();
        case TokenKind.For:
            return this.parseForStatement();
        default:
            if (error !is null)
                error.addError(Diagnostic(format("Noo prefix parse function for '%s'.", to!string(
                        token.value)), token.loc));
            throw new Exception(format("Noo prefix parse function for '%s'.", to!string(token.value)));
        }
    }

    Node parseForStatement()
    {
        Loc start = this.previous().loc;

        if (this.check(TokenKind.Let))
        {
            this.advance();
            return parseForStmt(start);
        }
        else if (this.check(TokenKind.Identifier))
        {
            ulong savedPos = this.pos;
            Token id = this.advance();

            if (this.check(TokenKind.In))
            {
                this.advance();

                if (this.isRangeExpression()) // ForRange: for i in 0..100 { }
                    return parseForRangeStmt(id.value.get!string, start);
                else // ForEach: for name in names { }
                    return parseForEachStmt(id.value.get!string, start);
            }
            else
            {
                this.pos = savedPos;
                error.addError(Diagnostic("Expected 'in' after identifier in for statement", this.peek()
                        .loc));
                throw new Exception("Expected 'in' after identifier in for statement");
            }
        }
        else if (this.check(TokenKind.Number) || this.check(TokenKind.Double) ||
            this.check(TokenKind.Real) || this.check(TokenKind.Float) ||
            this.check(TokenKind.LParen)) // Anonymous range: for 0..100 { }
            return parseForRangeStmt("", start);
        else
        {
            error.addError(Diagnostic("Invalid for statement syntax", this.peek().loc));
            throw new Exception("Invalid for statement syntax");
        }
    }

    ForStmt parseForStmt(Loc start)
    {
        Node init = this.parseVarDecl(); // let i int = 0
        this.consume(TokenKind.SemiColon, "Expected ';' after for loop initialization");
        Node condition = this.parseExpression(Precedence.LOWEST); // i < 1000
        this.consume(TokenKind.SemiColon, "Expected ';' after for loop condition");
        Node increment = this.parseExpression(Precedence.LOWEST); // i++
        Node[] body = this.parseBody(); // { ... }
        return new ForStmt(init, condition, increment, body, start);
    }

    ForRangeStmt parseForRangeStmt(string iterator, Loc start)
    {
        bool hasIterator = iterator.length > 0;
        Node startExpr = this.parseExpression(Precedence.LOWEST);
        bool inclusive = false;
        if (this.check(TokenKind.Range))
        {
            this.advance();
            if (this.check(TokenKind.Equals))
            {
                this.advance();
                inclusive = true;
            }
        }
        else if (this.check(TokenKind.RangeEquals))
        {
            this.advance();
            inclusive = true;
        }
        else
        {
            error.addError(Diagnostic("Expected '..' or '..=' in range expression", this.peek().loc));
            throw new Exception("Expected '..' or '..=' in range expression");
        }

        Node endExpr = this.parseExpression(Precedence.LOWEST);
        Node stepExpr = null;
        if (this.check(TokenKind.Colon))
        {
            this.advance();
            stepExpr = this.parseExpression(Precedence.LOWEST);
        }

        Node[] body = this.parseBody();
        return new ForRangeStmt(iterator, startExpr, endExpr, body, inclusive, stepExpr, hasIterator, start);
    }

    ForEachStmt parseForEachStmt(string iterator, Loc start)
    {
        Node iterable = this.parseExpression(Precedence.LOWEST);
        Node[] body = this.parseBody();
        return new ForEachStmt(iterator, iterable, body, start);
    }

    bool isRangeExpression()
    {
        ulong savedPos = this.pos;

        try
        {
            this.parseExpression(Precedence.LOWEST);
            bool isRange = this.check(TokenKind.Range) || this.check(TokenKind.RangeEquals);
            this.pos = savedPos;
            return isRange;
        }
        catch (Exception)
        {
            this.pos = savedPos;
            return false;
        }
    }

    Node parseUnaryExpr()
    {
        Token op = this.advance();
        Node operand = null;
        bool postFix = false;

        if (op.kind == TokenKind.Identifier)
        {
            operand = new Identifier(op.value.get!string, op.loc);
            if (this.check(TokenKind.PlusPlus) || this.check(TokenKind.MinusMinus))
            {
                Token postOp = this.advance();
                return new UnaryExpr(postOp.value.get!string, operand, op.loc, true);
            }
        }
        else if (op.kind == TokenKind.PlusPlus || op.kind == TokenKind.MinusMinus)
        {
            operand = this.parseExpression(Precedence.HIGHEST);
            return new UnaryExpr(op.value.get!string, operand, op.loc, false);
        }
        else if (op.kind == TokenKind.Plus || op.kind == TokenKind.Minus || op.kind == TokenKind
            .Bang)
        {
            operand = this.parseExpression(Precedence.HIGHEST);
            return new UnaryExpr(op.value.get!string, operand, op.loc, false);
        }

        error.addError(Diagnostic("Invalid unary expression", op.loc));
        throw new Exception("Invalid unary expression");
    }

    CastExpr parseCastExpr()
    {
        Loc start = this.previous().loc;
        this.consume(TokenKind.Bang, "Expected '!' after 'cast'.");
        Type target = this.parseType();
        Node value = this.parseExpression(Precedence.LOWEST);
        return new CastExpr(target, value, start);
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
                Node elseStmt = new ElseStatement(elseBody, new Type(Types.Undefined, BaseType.Void), elseLoc);
                else_ = elseStmt;
            }
        }

        return new IfStatement(condition, body, new Type(Types.Undefined, BaseType.Void), else_, start);
    }

    Extern parseExtern()
    {
        Loc start = this.previous().loc;
        Node value = this.parseExpression(Precedence.LOWEST);
        if (value.kind != NodeKind.FuncDeclaration)
        {
            error.addError(Diagnostic("Expected 'Function' in extern.", value.loc));
            throw new Exception("Expected 'Function' in extern.");
        }
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
        if (value.kind == NodeKind.ArrayLiteral)
            value.type = ty;
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
                args ~= FunctionArgument("...", new Type(Types.Undefined, BaseType.Void), Variant(
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

    // old system
    // Type parseType()
    // {
    //     Token ty = this.advance();
    //     bool isArray = this.match([TokenKind.LBracket]);
    //     long dim;
    //     if (isArray)
    //     {
    //         if (this.check(TokenKind.Number))
    //             dim = to!long(this.advance().value.get!string);
    //         this.consume(TokenKind.RBracket, "Expected ']' after array type.");
    //     }

    //     switch (ty.kind)
    //     {
    //     case TokenKind.Int:
    //         if (isArray)
    //             return new Type(Types.Array, BaseType.Int, false, to!ulong(dim));
    //         return new Type(Types.Literal, BaseType.Int);
    //     case TokenKind.Float:
    //         if (isArray)
    //             return new Type(Types.Array, BaseType.Float, false, to!ulong(dim));
    //         return new Type(Types.Literal, BaseType.Float);
    //     case TokenKind.Double:
    //         if (isArray)
    //             return new Type(Types.Array, BaseType.Double, false, to!ulong(dim));
    //         return new Type(Types.Literal, BaseType.Double);
    //     case TokenKind.Real:
    //         if (isArray)
    //             return new Type(Types.Array, BaseType.Real, false, to!ulong(dim));
    //         return new Type(Types.Literal, BaseType.Real);
    //     case TokenKind.Bool:
    //         if (isArray)
    //             return new Type(Types.Array, BaseType.Bool, false, to!ulong(dim));
    //         return new Type(Types.Literal, BaseType.Bool);
    //     case TokenKind.Str:
    //         if (isArray)
    //             return new Type(Types.Array, BaseType.String, false, to!ulong(dim));
    //         return new Type(Types.Literal, BaseType.String);
    //     case TokenKind.Void:
    //         return new Type(Types.Void, BaseType.Void);
    //     case TokenKind.Mixed:
    //         this.error.addWarning(Diagnostic(
    //                 "The 'mixed' type is unsafe, be careful when using it", ty.loc));
    //         return new Type(Types.Array, BaseType.Mixed);
    //     default:
    //         return new Type(Types.Undefined, BaseType.Void);
    //     }
    // }

    Type parseType()
    {
        TypeQualifier qualifiers = parseQualifiers();

        uint pointerCount = 0;
        while (match(TokenKind.Star))
            pointerCount++;

        Type baseType = parseBaseType();
        baseType.qualifiers = qualifiers;
        Type result = parseTypeSuffixes(baseType);

        foreach (i; 0 .. pointerCount)
            result = Type.pointer(result);

        return result;
    }

    TypeQualifier parseQualifiers()
    {
        TypeQualifier quals = TypeQualifier.None;

        while (true)
        {
            switch (peek().kind)
            {
            case TokenKind.Const:
                advance();
                quals |= TypeQualifier.Const;
                break;
            case TokenKind.Mut:
                advance();
                quals |= TypeQualifier.Mutable;
                break;
            default:
                return quals;
            }
        }
    }

    Type parseBaseType()
    {
        if (check(TokenKind.LParen))
        {
            return parseFunctionType();
        }

        Token token = advance();

        switch (token.kind)
        {
        case TokenKind.Int:
            return Type.basic(BaseType.Int);
        case TokenKind.Float:
            return Type.basic(BaseType.Float);
        case TokenKind.Double:
            return Type.basic(BaseType.Double);
        case TokenKind.Real:
            return Type.basic(BaseType.Real);
        case TokenKind.Bool:
            return Type.basic(BaseType.Bool);
        case TokenKind.Str:
            return Type.basic(BaseType.String);
        case TokenKind.Void:
            return Type.basic(BaseType.Void);
        case TokenKind.Mixed:
            auto t = Type.basic(BaseType.Mixed);
            t.isUnsafe = true;
            return t;
        case TokenKind.Identifier:
            // Pode ser alias ou struct
            auto t = new Type(Types.Alias);
            t.name = token.value.get!string;
            return t;
        default:
            throw new Exception("Unexpected token in type: " ~ to!string(token.kind));
        }
    }

    Type parseFunctionType()
    {
        consume(TokenKind.LParen, "Expected '('");
        Type[] params;

        if (!check(TokenKind.RParen))
        {
            do
            {
                if (match(TokenKind.Comma))
                    continue;
                params ~= parseType();
            }
            while (match(TokenKind.Comma));
        }

        consume(TokenKind.RParen, "Expected ')' after parameters");
        consume(TokenKind.Arrow, "Expected '->' after function parameters");

        Type returnType = parseType();
        return Type.func(returnType, params);
    }

    Type parseTypeSuffixes(Type baseType)
    {
        Type current = baseType;

        while (true)
        {
            if (match(TokenKind.LBracket))
            {
                if (match(TokenKind.Colon))
                {
                    consume(TokenKind.RBracket, "Expected ']' after ':'");
                    current = Type.slice(current);
                }
                else if (check(TokenKind.Number))
                {
                    ulong size = to!ulong(advance().value.get!string);
                    consume(TokenKind.RBracket, "Expected ']' after array size");
                    current = Type.array(current, size);
                }
                else // array dinâmico []
                {
                    consume(TokenKind.RBracket, "Expected ']'");
                    current = Type.array(current, 0);
                }
            }
            else
                break;
        }

        return current;
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
        case TokenKind.Slash:
        case TokenKind.Star:
        case TokenKind.Or:
        case TokenKind.And:
        case TokenKind.EqualsEquals:
        case TokenKind.GreaterThan:
        case TokenKind.GreaterThanEquals:
        case TokenKind.LessThanEquals:
        case TokenKind.LessThan:
        case TokenKind.Modulo:
        case TokenKind.PlusEquals:
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

    bool match(TokenKind kind)
    {
        return match([kind]);
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
        case TokenKind.Or:
        case TokenKind.And:
        case TokenKind.PlusEquals:
            return Precedence.SUM;
        case TokenKind.Star:
        case TokenKind.Slash:
        case TokenKind.Modulo:
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
    this(Token[] tokens = [], DiagnosticError error)
    {
        this.error = error;
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
