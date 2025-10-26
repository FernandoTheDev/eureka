module middle.semantic_analyzer;

import std.stdio, std.format, std.conv, std.algorithm;
import frontend.type, frontend.parser.ast, error;

struct Symbol
{
    Type type = Type.init;
    Node value = Node.init; // para variáveis
    bool isLet = true;
    bool isConst = false;
    bool isFunc = false;
    Symbol[] funcArgs = [];
}

class SemanticAnalyzer
{
private:
    Symbol[string][] scopes; // stack de escopos (cada escopo é um dicionário)
    Symbol[string] globalFuncs; // funções globais
    Type currentFuncReturnType; // tipo de retorno da função atual
    bool insideFunction = false; // flag para verificar se estamos dentro de uma função
    DiagnosticError error;

    void pushScope()
    {
        scopes ~= (Symbol[string]).init;
    }

    void popScope()
    {
        if (scopes.length > 0)
            scopes = scopes[0 .. $ - 1];
        else
            throw new Exception("Attempt to remove non-existent scope");
    }

    Symbol* lookupSymbol(string name)
    {
        // busca em escopos locais
        for (long i = cast(long) scopes.length - 1; i >= 0; i--)
            if (auto sym = name in scopes[i])
                return sym;
        // busca em funções globais
        if (auto func = name in globalFuncs)
            return func;

        return null;
    }

    void addSymbol(string name, Symbol sym)
    {
        if (scopes.length == 0)
            throw new Exception("No active scope for adding symbol");
        if (name in scopes[$ - 1])
            throw new Exception(format("Symbol '%s' already declared in this scope", name));
        scopes[$ - 1][name] = sym;
    }

    void checkType(Type left, Type right, string message)
    {
        if (!left.isCompatibleWith(right))
        {
            string message = format(
                "Type mismatch: expected '%s', found '%s'",
                left.toString(), right.toString()
            );
            error.addError(Diagnostic(message, node.loc));
            throw new Exception(message);
        }
    }

    Node analyze(Node node)
    {
        if (node is null)
            return null;
        switch (node.kind)
        {
        case NodeKind.VarDeclaration:
            return analyzeVarDecl(cast(VarDeclaration) node);
        case NodeKind.VarAssignmentDecl:
            return analyzeVarAssignment(cast(VarAssignmentDecl) node);
        case NodeKind.FuncDeclaration:
            return analyzeFuncDecl(cast(FunctionDeclaration) node);
        case NodeKind.CallExpr:
            return analyzeCallExpr(cast(CallExpr) node);
        case NodeKind.BinaryExpr:
            return analyzeBinaryExpr(cast(BinaryExpr) node);
        case NodeKind.UnaryExpr:
            return analyzeUnaryExpr(cast(UnaryExpr) node);
        case NodeKind.CastExpr:
            return analyzeCastExpr(cast(CastExpr) node);
        case NodeKind.Identifier:
            return analyzeIdentifier(cast(Identifier) node);
        case NodeKind.Return:
            return analyzeReturn(cast(Return) node);
        case NodeKind.IfStatement:
            return analyzeIfStmt(cast(IfStatement) node);
        case NodeKind.ElseStatement:
            return analyzeElseStmt(cast(ElseStatement) node);
        case NodeKind.ForRangeStmt:
            return analyzeForRangeStmt(cast(ForRangeStmt) node);
        case NodeKind.ForStmt:
            return analyzeForStmt(cast(ForStmt) node);
        case NodeKind.ForEachStmt:
            return analyzeForEachStmt(cast(ForEachStmt) node);
        case NodeKind.Extern:
            return analyzeExtern(cast(Extern) node);
        case NodeKind.ArrayLiteral:
            return analyzeArrayLiteral(cast(ArrayLiteral) node);

            // literais não precisam de análise especial
        case NodeKind.IntLiteral:
        case NodeKind.FloatLiteral:
        case NodeKind.DoubleLiteral:
        case NodeKind.RealLiteral:
        case NodeKind.BoolLiteral:
        case NodeKind.StringLiteral:
            return node;

        default:
            error.addError(Diagnostic("Unsupported node type: " ~ to!string(node.kind), node.loc));
            throw new Exception("Unsupported node type: " ~ to!string(node.kind));
        }
    }

    Node analyzeVarDecl(VarDeclaration node)
    {
        if (node.value.convertsTo!Node)
        {
            Node valueNode = node.value.get!Node;
            valueNode = analyze(valueNode);
            checkType(node.type, valueNode.type);
            node.value = valueNode;
        }

        Symbol sym;
        sym.type = node.type;
        sym.isLet = true;
        sym.isConst = false;
        sym.value = node.value.get!Node;

        addSymbol(node.id, sym);
        return node;
    }

    Node analyzeVarAssignment(VarAssignmentDecl node)
    {
        Symbol* sym = lookupSymbol(node.id);
        if (sym is null)
        {
            error.addError(Diagnostic(format("Undeclared variable '%s'", node.id), node.loc));
            throw new Exception(format("Undeclared variable '%s'", node.id));
        }

        if (sym.isConst)
        {
            error.addError(Diagnostic(format("Cannot reassign const variable '%s'", node
                    .id), node.loc));
            throw new Exception(format("Cannot reassign const variable '%s'", node.id));
        }

        if (node.value.convertsTo!Node)
        {
            Node valueNode = node.value.get!Node;
            valueNode = analyze(valueNode);
            checkType(sym.type, valueNode.type);
            node.value = valueNode;
        }

        node.type = sym.type;
        return node;
    }

    Node analyzeFuncDecl(FunctionDeclaration node)
    {
        if (node.name in globalFuncs)
        {
            error.addError(Diagnostic(format("Function '%s' already declared", node.name), node.loc));
            throw new Exception(format("Function '%s' already declared", node.name));
        }

        Symbol funcSym;
        funcSym.isFunc = true;
        funcSym.type = node.type;

        pushScope();
        scope (exit)
            popScope();

        foreach (param; node.args)
        {
            Symbol paramSym;
            paramSym.type = param.type;
            paramSym.isLet = true;
            paramSym.isConst = false;

            addSymbol(param.name, paramSym);
            funcSym.funcArgs ~= paramSym;
        }

        bool previousInsideFunction = insideFunction;
        Type previousReturnType = currentFuncReturnType;
        insideFunction = true;
        currentFuncReturnType = node.type;

        scope (exit)
        {
            insideFunction = previousInsideFunction;
            currentFuncReturnType = previousReturnType;
        }

        globalFuncs[node.name] = funcSym;

        foreach (ref stmt; node.body)
            stmt = analyze(stmt);

        return node;
    }

    Node analyzeCallExpr(CallExpr node)
    {
        Symbol* funcSym = lookupSymbol(node.id);
        if (funcSym is null || !funcSym.isFunc)
        {
            error.addError(Diagnostic(format("Function '%s' not declared", node.id), node.loc));
            throw new Exception(format("Function '%s' not declared", node.id));
        }

        // TODO
        // Verifica número de argumentos
        // if (node.args.length != funcSym.funcArgs.length)
        // {
        //     throw new Exception(format(
        //             "Função '%s' espera %d argumentos, mas recebeu %d",
        //             node.id, funcSym.funcArgs.length, node.args.length
        //     ));
        // }

        // Analisa e verifica tipo de cada argumento
        // foreach (i, ref arg; node.args)
        // {
        //     arg = analyze(arg);

        //     if (!funcSym.funcArgs[i].type.isCompatibleWith(arg.type))
        //     {
        //         throw new Exception(format(
        //                 "Argumento %d da função '%s': esperado '%s', encontrado '%s'",
        //                 i + 1, node.id, funcSym.funcArgs[i].type.baseType, arg.type.baseType
        //         ));
        //     }
        // }

        node.type = funcSym.type;
        return node;
    }

    Node analyzeBinaryExpr(BinaryExpr node)
    {
        node.left = analyze(node.left);
        node.right = analyze(node.right);

        if (node.op == "==" || node.op == "!=" || node.op == "<" ||
            node.op == ">" || node.op == "<=" || node.op == ">=")
        {
            node.type = new Type(Types.Literal, BaseType.Bool);
            return node;
        }

        if (node.op == "&&" || node.op == "||")
        {
            if (node.left.type.baseType != BaseType.Bool || node.right.type.baseType != BaseType
                .Bool)
            {
                error.addError(Diagnostic("Logical operators require boolean operands", node.loc));
                throw new Exception("Logical operators require boolean operands");
            }

            node.type = new Type(Types.Literal, BaseType.Bool);
            return node;
        }

        checkType(node.left.type, node.right.type);
        node.type = node.left.type;
        return node;
    }

    Node analyzeUnaryExpr(UnaryExpr node)
    {
        node.operand = analyze(node.operand);

        if (node.op == "!")
        {
            if (node.operand.type.baseType != BaseType.Bool)
            {
                error.addError(Diagnostic("Operator '!' requires boolean operand", node.loc));
                throw new Exception("Operator '!' requires boolean operand");
            }

            node.type = new Type(Types.Literal, BaseType.Bool);
        }
        else if (node.op == "-" || node.op == "+")
        {
            if (!node.operand.type.isNumeric())
            {
                error.addError(Diagnostic(format("Operator '%s' requires numeric operand", node.op), node
                        .loc));
                throw new Exception(format("Operator '%s' requires numeric operand", node.op));
            }

            node.type = node.operand.type;
        }
        else if (node.op == "++" || node.op == "--")
        {
            if (!node.operand.type.isNumeric())
            {
                error.addError(Diagnostic(format("Operator '%s' requires numeric operand", node.op), node
                        .loc));
                throw new Exception(format("Operator '%s' requires numeric operand", node.op));
            }

            node.type = node.operand.type;
        }

        return node;
    }

    Node analyzeCastExpr(CastExpr node)
    {
        Node valueNode = node.value.get!Node;
        valueNode = analyze(valueNode);
        node.value = valueNode;

        return node;
    }

    Node analyzeIdentifier(Identifier node)
    {
        Symbol* sym = lookupSymbol(node.value.get!string);
        if (sym is null)
        {
            error.addError(Diagnostic(format("Identifier '%s' not declared", node.value.get!string), node
                    .loc));
            throw new Exception(format("Identifier '%s' not declared", node.value.get!string));
        }

        node.type = sym.type;
        return node;
    }

    Node analyzeReturn(Return node)
    {
        if (!insideFunction)
        {
            error.addError(Diagnostic("'return' out of function", node.loc));
            throw new Exception("'return' out of function");
        }

        if (node.ret && node.value.convertsTo!Node)
        {
            Node returnValue = node.value.get!Node;
            returnValue = analyze(returnValue);
            node.value = returnValue;
            checkType(currentFuncReturnType, returnValue.type);
        }
        else if (!node.ret && currentFuncReturnType.baseType != BaseType.Void)
        {
            error.addError(Diagnostic("Function must return a value", node.loc));
            throw new Exception("Function must return a value");
        }

        return node;
    }

    Node analyzeIfStmt(IfStatement node)
    {
        node.condition = analyze(node.condition);
        if (node.condition.type.baseType != BaseType.Bool)
        {
            error.addError(Diagnostic("'If' condition must be boolean", node.loc));
            throw new Exception("'If' condition must be boolean");
        }

        pushScope();
        scope (exit)
            popScope();

        foreach (ref stmt; node.body)
            stmt = analyze(stmt);

        if (node.else_ !is null)
            node.else_ = analyze(node.else_);

        return node;
    }

    Node analyzeElseStmt(ElseStatement node)
    {
        pushScope();
        scope (exit)
            popScope();

        foreach (ref stmt; node.body)
            stmt = analyze(stmt);

        return node;
    }

    Node analyzeForRangeStmt(ForRangeStmt node)
    {
        node.start = analyze(node.start);
        node.end = analyze(node.end);

        if (!node.start.type.isNumeric() || !node.end.type.isNumeric())
        {
            error.addError(Diagnostic("Range expressions must be numeric", node.loc));
            throw new Exception("Range expressions must be numeric");
        }

        if (node.step !is null)
        {
            node.step = analyze(node.step);
            if (!node.step.type.isNumeric())
            {
                error.addError(Diagnostic("Step expression must be numeric", node.loc));
                throw new Exception("Step expression must be numeric");
            }
        }

        pushScope();
        scope (exit)
            popScope();

        if (node.hasIterator)
        {
            Symbol iterSym;
            iterSym.type = node.start.type;
            iterSym.isLet = true;
            iterSym.isConst = true;
            addSymbol(node.iterator, iterSym);
        }

        foreach (ref stmt; node.body)
            stmt = analyze(stmt);

        return node;
    }

    Node analyzeForStmt(ForStmt node)
    {
        pushScope();
        scope (exit)
            popScope();

        if (node.init_ !is null)
            node.init_ = analyze(node.init_);

        if (node.condition !is null)
        {
            node.condition = analyze(node.condition);
            if (node.condition.type.baseType != BaseType.Bool)
            {
                error.addError(Diagnostic("Loop condition must be boolean", node.loc));
                throw new Exception("Loop condition must be boolean");
            }
        }

        if (node.increment !is null)
            node.increment = analyze(node.increment);

        foreach (ref stmt; node.body)
            stmt = analyze(stmt);

        return node;
    }

    Node analyzeForEachStmt(ForEachStmt node)
    {
        node.iterable = analyze(node.iterable);

        if (node.iterable.kind != NodeKind.ArrayLiteral &&
            node.iterable.kind != NodeKind.Identifier)
        {
            error.addError(Diagnostic("ForEach requires an array or array identifier", node.loc));
            throw new Exception("ForEach requires an array or array identifier");
        }

        pushScope();
        scope (exit)
            popScope();

        // Adiciona iterador ao escopo
        Symbol iterSym;
        iterSym.type = node.iterable.type;
        iterSym.isLet = true;
        iterSym.isConst = true;
        addSymbol(node.iterator, iterSym);

        foreach (ref stmt; node.body)
            stmt = analyze(stmt);

        return node;
    }

    Node analyzeExtern(Extern node)
    {
        FunctionDeclaration funcDecl = node.value.get!FunctionDeclaration;
        Symbol funcSym;
        funcSym.isFunc = true;
        funcSym.type = funcDecl.type;

        foreach (param; funcDecl.args)
        {
            Symbol paramSym;
            paramSym.type = param.type;
            funcSym.funcArgs ~= paramSym;
        }

        globalFuncs[funcDecl.name] = funcSym;
        return node;
    }

    Node analyzeArrayLiteral(ArrayLiteral node)
    {
        Node[] elements = node.value.get!(Node[]);

        if (elements.length > 0)
        {
            foreach (ref elem; elements[0 .. $])
            {
                elem = analyze(elem);
                if (node.type.baseType != elem.type.baseType && node.type.baseType != BaseType
                    .Mixed)
                {
                    error.addError(Diagnostic("All array elements must have the same type", node
                            .loc));
                    throw new Exception("Todos os elementos do array devem ter o mesmo tipo");
                }
            }
        }

        return node;
    }

public:
    this(DiagnosticError error)
    {
        this.error = error;
    }

    void analyze(ref Program program)
    {
        pushScope();
        globalFuncs["print"] = Symbol(new Type(Types.Void, BaseType.Void), Node.init, false, true, true);
        try
            foreach (ref stmt; program.body)
                stmt = analyze(stmt);
                finally
                    popScope();
    }
}
