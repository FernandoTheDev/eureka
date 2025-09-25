module runtime.runtime;

import std.stdio, std.format, std.conv, core.sys.posix.dlfcn, std.string, std.file, std.algorithm, std
    .array;
import runtime.runtime_value, runtime.context, runtime.typechecker, runtime.runtime_cast, config : LIMIT;
import frontend.parser.ast, frontend.type, error;

struct LibraryHandle
{
    void* handle;
    string path;
    bool isLoaded;
}

struct CachedFunction
{
    void* funcPtr;
    string libPath;
    bool isResolved;
}

class EurekaRuntime
{
private:
    Context context;
    TypeChecker typeChecker;
    string[] dlsopnso;
    DiagnosticError error;

    LibraryHandle[string] libraryCache; // path -> handle
    CachedFunction[string] functionCache; // funcName -> function info
    string[] loadOrder; // Library loading order
    alias ExternFunc = RuntimeValue function(RuntimeValue[LIMIT], size_t);

public:
    this(Context context, string[] dlsopnso = [], DiagnosticError error)
    {
        this.context = context;
        this.typeChecker = new TypeChecker();
        this.dlsopnso = dlsopnso;
        this.error = error;

        // Preload all libraries in constructor
        this.preloadLibraries();
    }

    ~this()
    {
        // Don't call cleanup() in destructor to avoid GC issues
        try
        {
            this.cleanupLibraries();
        }
        catch (Exception e)
        {
            // Ignore exceptions in destructor
        }
    }

    void preloadLibraries()
    {
        foreach (libPath; dlsopnso)
        {
            void* lib = dlopen(libPath.toStringz(), RTLD_LAZY);
            if (lib)
            {
                libraryCache[libPath] = LibraryHandle(lib, libPath, true);
                loadOrder ~= libPath; // Maintain loading order
            }
            else
            {
                writefln("Warning: Could not preload library '%s': %s", libPath, fromStringz(
                        dlerror()));
                libraryCache[libPath] = LibraryHandle(null, libPath, false);
            }
        }
    }

    void cleanupLibraries()
    {
        // Close libraries in LIFO order using loadOrder
        foreach_reverse (libPath; loadOrder)
        {
            if (libPath in libraryCache)
            {
                auto libHandle = &libraryCache[libPath];
                if (libHandle.isLoaded && libHandle.handle)
                {
                    dlclose(libHandle.handle);
                    libHandle.handle = null;
                    libHandle.isLoaded = false;
                }
            }
        }
    }

    void cleanup()
    {
        this.cleanupLibraries();
        libraryCache.clear();
        functionCache.clear();
        loadOrder.length = 0;
    }

    ExternFunc resolveExternFunction(string funcName)
    {
        if (funcName in functionCache && functionCache[funcName].isResolved)
        {
            return cast(ExternFunc) functionCache[funcName].funcPtr;
        }

        foreach (libPath, ref libHandle; libraryCache)
        {
            if (!libHandle.isLoaded || !libHandle.handle)
                continue;

            void* funcPtr = dlsym(libHandle.handle, funcName.toStringz());
            if (funcPtr)
            {
                functionCache[funcName] = CachedFunction(funcPtr, libPath, true);
                return cast(ExternFunc) funcPtr;
            }
        }

        // Function not found - cache negative result to avoid future searches
        functionCache[funcName] = CachedFunction(null, "", false);
        return null;
    }

    RuntimeValue eval(Node node)
    {
        RuntimeValue value;
        switch (node.kind)
        {
        case NodeKind.BoolLiteral:
            return MK_BOOL(node.value.get!bool);

        case NodeKind.IntLiteral:
            return MK_INT(node.value.get!long);

        case NodeKind.DoubleLiteral:
            return MK_DOUBLE(node.value.get!double);

        case NodeKind.RealLiteral:
            return MK_REAL(node.value.get!real);

        case NodeKind.FloatLiteral:
            return MK_FLOAT(node.value.get!float);

        case NodeKind.StringLiteral:
            return MK_STRING(node.value.get!string);

        case NodeKind.Identifier:
            Identifier id = cast(Identifier) node;
            string varName = id.value.get!string;
            if (!this.context.checkRuntimeValue(varName))
            {
                error.addError(Diagnostic(format("Variable '%s' was not declared.", varName), id
                        .loc));
                throw new Exception(format("Variable '%s' was not declared.", varName));
            }
            return this.context.lookupRuntimeValue(varName);

        case NodeKind.VarDeclaration:
            VarDeclaration var = cast(VarDeclaration) node;
            value = this.eval(var.value.get!Node);

            if (!typeChecker.isComp(var.type, value.type))
            {
                error.addError(Diagnostic(format("Incompatible type: expected '%s', received '%s'.",
                        cast(string) var.type.baseType, cast(string) value.type.baseType), var.loc));
                throw new Exception(format("Incompatible type: expected '%s', received '%s'.",
                        cast(string) var.type.baseType, cast(string) value.type.baseType));
            }

            this.context.addRuntimeValue(var.id, value);
            return value;

        case NodeKind.VarAssignmentDecl:
            VarAssignmentDecl var = cast(VarAssignmentDecl) node;
            value = this.eval(var.value.get!Node);

            if (!this.context.checkRuntimeValue(var.id))
            {
                error.addError(Diagnostic(format("Variable '%s' does not exists.", var.id)));
                throw new Exception(format("Variable '%s' does not exists.", var.id));
            }

            RuntimeValue var_ = this.context.lookupRuntimeValue(var.id);

            if (!typeChecker.isComp(var_.type, value.type))
            {
                error.addError(Diagnostic(format("Incompatible type: expected '%s', received '%s'.",
                        cast(string) var_.type.baseType, cast(string) value.type.baseType), var.loc));
                throw new Exception(format("Incompatible type: expected '%s', received '%s'.",
                        cast(string) var_.type.baseType, cast(string) value.type.baseType));
            }

            this.context.updateRuntimeValue(var.id, value);
            return value;
        case NodeKind.BinaryExpr:
            BinaryExpr binExpr = cast(BinaryExpr) node;
            RuntimeValue left = this.eval(binExpr.left);
            RuntimeValue right = this.eval(binExpr.right);
            // TODO: improve this
            if (binExpr.op == "+=")
            {
                if (!binExpr.left.kind == NodeKind.Identifier)
                {
                    // Error:
                }
                Identifier lft = cast(Identifier) binExpr.left;
                if (left.type.type == Types.Array)
                {
                    left.value._array ~= right;
                    this.context.updateRuntimeValue(lft.value.get!string, left);
                    return left;
                }
            }
            return this.evalBinaryExpr(left, right, binExpr
                    .op);
        case NodeKind.CallExpr:
            CallExpr callExpr = cast(CallExpr) node;
            return this.evalCallExpr(callExpr);

        case NodeKind.FuncDeclaration:
            FunctionDeclaration funcDecl = cast(FunctionDeclaration) node;
            RuntimeValue funcValue = MK_FUNCTION(
                funcDecl);
            this.context.addFunc(funcDecl.name, funcValue);
            return funcValue;

        case NodeKind.Extern:
            RuntimeValue funcValue = MK_FUNCTION(node.value.get!FunctionDeclaration);
            funcValue.asExtern = true;
            this.context.addFunc(
                node.value.get!FunctionDeclaration.name, funcValue);
            return funcValue;

        case NodeKind.Return:
            Return retNode = cast(Return) node;
            value = this.eval(retNode.value.get!Node);
            value.haveReturn = true;
            return value;
        case NodeKind.IfStatement:
            IfStatement ifStatement = cast(IfStatement) node;
            return this.evalIfStatement(
                ifStatement);
        case NodeKind.UseStatement:
            UseStatement useStatement = cast(UseStatement) node;
            return this.evalUseStatement(
                useStatement);
        case NodeKind.CastExpr:
            CastExpr cast_ = cast(CastExpr) node;
            value = this.eval(cast_.value.get!Node);
            return new CastHandler(this.typeChecker).executeCast(cast_.target, value);

        case NodeKind.ForRangeStmt:
            ForRangeStmt forRangeStmt = cast(ForRangeStmt) node;
            return this.evalForRangeStmt(
                forRangeStmt);
        case NodeKind.ForStmt:
            ForStmt forStmt = cast(ForStmt) node;
            return this.evalForStmt(forStmt);

        case NodeKind.ForEachStmt:
            ForEachStmt forEachStmt = cast(ForEachStmt) node;
            return this.evalForEachStmt(
                forEachStmt);
        case NodeKind.UnaryExpr:
            UnaryExpr unaryExpr = cast(UnaryExpr) node;
            return this.evalUnaryExpr(unaryExpr);

        case NodeKind.ArrayLiteral:
            ArrayLiteral arr = cast(ArrayLiteral) node;
            Node[] nodes = arr.value.get!(Node[]);
            RuntimeValue[] values;
            foreach (Node n; nodes)
            {
                values ~= this.eval(n);
                if (values[$ - 1].type.baseType != arr.type.baseType
                    && arr.type.baseType != BaseType.Mixed)
                {
                    error.addError(Diagnostic(format("Incompatible type: expected '%s', received '%s'.",
                            cast(string) arr.type.baseType, cast(string) values[$ - 1]
                            .type.baseType), n
                            .loc));
                    throw new Exception(format("Incompatible type: expected '%s', received '%s'.",
                            cast(string) arr.type.baseType, cast(string) values[$ - 1]
                            .type.baseType));
                }
            }
            return MK_ARRAY(values, arr.type);

        case NodeKind.Program:
            Program prog = cast(Program) node;
            foreach (Node n; prog.body)
                value = this.eval(n);
            return value;
        default:
            throw new Exception(format("Unknown node type: '%s'.", node.kind));
        }
    }

    void printCacheStats()
    {
        writefln("=== Cache Statistics ===");
        writefln("Libraries loaded: %d/%d",
            libraryCache.values.count!(lib => lib.isLoaded),
            libraryCache.length);
        writefln("Functions cached: %d", functionCache.length);
        writefln("Functions resolved: %d",
            functionCache.values.count!(func => func.isResolved));
    }

private:

    RuntimeValue evalForRangeStmt(ForRangeStmt node)
    {
        RuntimeValue result = MK_VOID();
        RuntimeValue startValue = this.eval(node.start);
        RuntimeValue endValue = this.eval(node.end);
        if (!typeChecker.isNumericType(startValue.type) || !typeChecker
            .isNumericType(
                endValue.type))
        {
            error.addError(Diagnostic("Range expressions must be numeric types", node.loc));
            throw new Exception("Range expressions must be numeric types");
        }

        RuntimeValue stepValue;
        if (node.step !is null)
        {
            stepValue = this.eval(node.step);
            if (!typeChecker.isNumericType(stepValue.type))
            {
                error.addError(Diagnostic("Step expression must be numeric type", node.loc));
                throw new Exception("Step expression must be numeric type");
            }
        }
        else
        {
            long start = startValue.value._int;
            long end = endValue.value._int;
            stepValue = MK_INT(start <= end ? 1 : -1);
        }
        if (startValue.type.baseType == BaseType.Int && endValue.type.baseType == BaseType
            .Int)
            result = this.executeIntegerRangeLoop(node, startValue.value._int,
                endValue.value._int, stepValue.value._int);
        else
            result = this.executeDecimalRangeLoop(node, startValue, endValue, stepValue);
        return result;
    }

    RuntimeValue executeLoopTest(long start, long end, Node[] body, ref RuntimeValue result)
    {
        if (start >= end)
            return result;

        foreach (Node stmt; body)
        {
            result = this.eval(stmt);
            if (result.haveReturn)
                return result; // TODO: implementar break/continue quando adicionados
        }

        return executeLoopTest(start + 1, end, body, result);
    }

    RuntimeValue executeIntegerRangeLoop(ForRangeStmt node, long start, long end, long step)
    {
        RuntimeValue result = MK_VOID();
        long current = start;
        if (step == 0)
        {
            error.addError(Diagnostic("Step cannot be zero in range loop", node.loc));
            throw new Exception("Step cannot be zero in range loop");
        }

        bool shouldContinue(long curr)
        {
            if (step > 0)
                return node.inclusive ? (curr <= end) : (curr < end);
            else
                return node.inclusive ? (curr >= end) : (curr > end);
        }

        if (node.hasIterator)
            this.context.addRuntimeValue(node.iterator, MK_INT(current));

        // result = executeLoopTest(current, end, node.body, result);
        while (shouldContinue(current))
        {
            if (node.hasIterator)
                this.context.updateRuntimeValue(node.iterator, MK_INT(current));

            foreach (Node stmt; node.body)
            {
                result = this.eval(stmt);
                if (result.haveReturn)
                    return result; // TODO: implementar break/continue quando adicionados
            }

            current += step;
        }
        if (node.hasIterator)
            this.context.removeRuntimeValue(node.iterator);

        return result;
    }

    RuntimeValue executeDecimalRangeLoop(ForRangeStmt node, RuntimeValue startValue,
        RuntimeValue endValue, RuntimeValue stepValue)
    {
        RuntimeValue result = MK_VOID();
        double current = this.toDouble(
            startValue);
        double end = this.toDouble(endValue);
        double step = this.toDouble(stepValue);
        if (step == 0.0)
        {
            error.addError(Diagnostic("Step cannot be zero in decimal range loop", node
                    .loc));
            throw new Exception(
                "Step cannot be zero in decimal range loop");
        }

        bool shouldContinue(double curr)
        {
            if (step > 0)
                return node.inclusive ? (curr <= end) : (curr < end);
            else
                return node.inclusive ? (curr >= end) : (
                    curr > end);
        }

        if (node.hasIterator)
            this.context.addRuntimeValue(node.iterator, this.createNumericValue(current, startValue
                    .type.baseType));
        while (shouldContinue(current))
        {
            if (node.hasIterator)
                this.context.updateRuntimeValue(node.iterator, this.createNumericValue(
                        current, startValue
                        .type.baseType));
            foreach (Node stmt; node.body)
            {
                result = this.eval(stmt);
                if (result.haveReturn)
                    return result;
            }

            current += step;
        }
        if (node.hasIterator)
            this.context.removeRuntimeValue(node.iterator);

        return result;
    }

    RuntimeValue evalForStmt(ForStmt node)
    {
        RuntimeValue result = MK_VOID();

        if (node.init_ !is null)
            this.eval(node.init_);

        while (true)
        {
            if (
                node
                .condition !is null)
            {
                RuntimeValue conditionValue = this.eval(
                    node.condition);
                if (conditionValue.type.baseType != BaseType
                    .Bool)
                {
                    error.addError(Diagnostic("For loop condition must be boolean", node
                            .loc));
                    throw new Exception("For loop condition must be boolean");
                }

                if (
                    !conditionValue.value
                    ._bool)
                    break;
            }

            foreach (Node stmt; node.body)
            {
                result = this.eval(
                    stmt);
                if (
                    result
                    .haveReturn)
                    return result;
            }

            if (
                node
                .increment !is null)
                this.eval(
                    node.increment);
        }
        if (node.init_ !is null)
            this.context.removeRuntimeValue((cast(VarDeclaration) node.init_).id);

        return result;
    }

    RuntimeValue evalForEachStmt(ForEachStmt node)
    {
        RuntimeValue result = MK_VOID();
        RuntimeValue iterable = this.eval(
            node.iterable);
        if (
            iterable.type.baseType != BaseType
            .String)
        {
            error.addError(Diagnostic(
                    "ForEach currently only supports string iteration", node
                    .loc));
            throw new Exception("ForEach currently only supports string iteration");
        }

        string str = iterable.value._string;
        this.context.addRuntimeValue(node.iterator, MK_STRING(
                "..."));
        foreach (size_t i, char c; str)
        {
            this.context.updateRuntimeValue(node.iterator, MK_STRING([c]));
            foreach (Node stmt; node.body)
            {
                result = this.eval(
                    stmt);
                if (
                    result
                    .haveReturn)
                    return result;
            }
        }
        this.context.removeRuntimeValue(node.iterator);

        return result;
    }

    RuntimeValue evalUnaryExpr(UnaryExpr node)
    {
        RuntimeValue operandValue = this.eval(
            node.operand);
        switch (node.op)
        {
        case "++":
            if (!typeChecker.isNumericType(
                    operandValue.type))
            {
                error.addError(Diagnostic(
                        "Increment operator requires numeric type", node
                        .loc));
                throw new Exception(
                    "Increment operator requires numeric type");
            }

            if (node.postFix)
            {
                RuntimeValue original = operandValue;
                this.incrementVariable(node.operand, 1);
                return original;
            }
            else
            {
                this.incrementVariable(node.operand, 1);
                return this.eval(
                    node.operand);
            }

        case "--":
            if (!typeChecker.isNumericType(
                    operandValue.type))
            {
                error.addError(Diagnostic(
                        "Decrement operator requires numeric type", node
                        .loc));
                throw new Exception(
                    "Decrement operator requires numeric type");
            }

            if (node.postFix)
            {
                RuntimeValue original = operandValue;
                this.incrementVariable(node.operand, -1);
                return original;
            }
            else
            {
                this.incrementVariable(node.operand, -1);
                return this.eval(
                    node.operand);
            }

        case "+":
            if (!typeChecker.isNumericType(
                    operandValue.type))
            {
                error.addError(Diagnostic(
                        "Unary plus requires numeric type", node
                        .loc));
                throw new Exception(
                    "Unary plus requires numeric type");
            }
            return operandValue; // +x é simplesmente x

        case "-":
            if (!typeChecker.isNumericType(
                    operandValue.type))
            {
                error.addError(Diagnostic(
                        "Unary minus requires numeric type", node
                        .loc));
                throw new Exception(
                    "Unary minus requires numeric type");
            }

            switch (operandValue.type.baseType)
            {
            case BaseType.Int:
                return MK_INT(
                    -operandValue.value._int);
            case BaseType.Float:
                return MK_FLOAT(
                    -operandValue.value._float);
            case BaseType.Double:
                return MK_DOUBLE(
                    -operandValue.value._double);
            case BaseType.Real:
                return MK_REAL(
                    -operandValue.value._real);
            default:
                throw new Exception(
                    "Unsupported numeric type for unary minus");
            }

        case "!":
            if (
                operandValue.type.baseType != BaseType
                .Bool)
            {
                error.addError(Diagnostic(
                        "Logical not requires boolean type", node
                        .loc));
                throw new Exception(
                    "Logical not requires boolean type");
            }
            return MK_BOOL(
                !operandValue.value._bool);

        default:
            error.addError(
                Diagnostic(format("Unknown unary operator: '%s'", node
                    .op), node.loc));
            throw new Exception(
                format("Unknown unary operator: '%s'", node
                    .op));
        }
    }

    void incrementVariable(Node varNode, long delta)
    {
        if (varNode.kind != NodeKind.Identifier)
        {
            error.addError(Diagnostic(
                    "Can only increment/decrement variables", varNode
                    .loc));
            throw new Exception(
                "Can only increment/decrement variables");
        }

        Identifier id = cast(Identifier) varNode;
        string varName = id
            .value.get!string;

        if (!this.context.checkRuntimeValue(
                varName))
        {
            error.addError(
                Diagnostic(format("Variable '%s' not found", varName), varNode
                    .loc));
            throw new Exception(
                format("Variable '%s' not found", varName));
        }

        RuntimeValue currentValue = this.context.lookupRuntimeValue(
            varName);
        if (
            !typeChecker.isNumericType(
                currentValue.type))
        {
            error.addError(Diagnostic(
                    "Cannot increment/decrement non-numeric variable", varNode
                    .loc));
            throw new Exception("Cannot increment/decrement non-numeric variable");
        }

        RuntimeValue newValue;
        switch (currentValue.type.baseType)
        {
        case BaseType.Int:
            newValue = MK_INT(
                currentValue.value._int + delta);
            break;
        case BaseType.Float:
            newValue = MK_FLOAT(
                currentValue.value._float + delta);
            break;
        case BaseType.Double:
            newValue = MK_DOUBLE(
                currentValue.value._double + delta);
            break;
        case BaseType.Real:
            newValue = MK_REAL(
                currentValue.value._real + delta);
            break;
        default:
            throw new Exception("Unsupported numeric type for increment/decrement");
        }

        this.context.updateRuntimeValue(varName, newValue);
    }

    double toDouble(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.Int:
            return cast(double) value
                .value._int;
        case BaseType.Float:
            return cast(double) value
                .value._float;
        case BaseType.Double:
            return value.value._double;
        case BaseType.Real:
            return cast(double) value
                .value._real;
        default:
            throw new Exception(
                "Cannot convert to double: not a numeric type");
        }
    }

    RuntimeValue createNumericValue(double value, BaseType targetType)
    {
        switch (targetType)
        {
        case BaseType.Int:
            return MK_INT(cast(long) value);
        case BaseType.Float:
            return MK_FLOAT(cast(float) value);
        case BaseType.Double:
            return MK_DOUBLE(value);
        case BaseType.Real:
            return MK_REAL(cast(real) value);
        default:
            return MK_DOUBLE(value); // fallback
        }
    }

    RuntimeValue evalUseStatement(
        UseStatement node)
    {
        import std.path : buildPath;
        import std.file : readText, exists;
        import std.format : format;

        string file = buildPath(node.loc.dir, node
                .value.get!string);

        if (!exists(file))
        {
            error.addError(
                Diagnostic(format("File does not exists '%s'.", file), node
                    .loc));
            throw new Exception(
                format("File does not exists '%s'.", file));
        }

        string fileContent = readText(file);

        import frontend.lexer.lexer, frontend.lexer.token, frontend
            .parser.parser;

        Lexer lexer = new Lexer(file, fileContent, ".", new DiagnosticError());
        Token[] tokens = lexer.tokenize();
        Program prog = new Parser(tokens, this
                .error).parse();

        foreach (Node n; prog.body)
        {
            if (n.kind != NodeKind.FuncDeclaration && n.kind != NodeKind.Extern && n
                .kind != NodeKind
                .UseStatement)
                continue;
            if (
                node.symbols.length == 0)
            {
                this.eval(n);
                continue;
            }

            string symbolName = getNodeSymbolName(
                n);
            if (symbolName !is null && symbolName in node
                .symbols)
                this.eval(n);
        }

        return MK_VOID();
    }

    string getNodeSymbolName(Node n)
    {
        if (
            n.kind == NodeKind
            .FuncDeclaration)
            return (
                cast(FunctionDeclaration) n)
                .name;
        if (
            n.kind == NodeKind
            .Extern)
            return (
                cast(Extern) n).value
                .get!FunctionDeclaration
                .name;
        return null;
    }

    RuntimeValue evalIfStatement(
        IfStatement node)
    {
        RuntimeValue if_ = MK_VOID();
        RuntimeValue condition = this.eval(
            node.condition);

        if (
            condition.type.baseType != BaseType
            .Bool)
            throw new Exception("The condition of the ifStatement must be of type 'bool'.");

        if (condition.value._bool)
        {
            foreach (Node n; node.body)
            {
                RuntimeValue val = this.eval(
                    n);
                if (val.haveReturn)
                {
                    return val;
                }
            }
        }
        else if (node.else_ !is null)
        {
            if (
                node.else_.kind == NodeKind
                .IfStatement)
                return this.evalIfStatement(
                    cast(IfStatement) node
                        .else_);
            ElseStatement else_ = cast(
                ElseStatement) node
                .else_;
            foreach (Node n; else_.body)
            {
                RuntimeValue val = this.eval(
                    n);
                if (
                    val
                    .haveReturn)
                {
                    return val;
                }
            }
        }

        return if_;
    }

    RuntimeValue evalBinaryExpr(RuntimeValue left, RuntimeValue right, string op)
    {
        Type resultType = typeChecker.inferType(left.type, right.type);

        switch (op)
        {
        case "+":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
            {
                return this.performArithmeticOperation(left, right, op, resultType);
            }
            else if (left.type.baseType == BaseType.String || right.type.baseType == BaseType
                .String)
            {
                string leftStr = this.valueToString(left);
                string rightStr = this.valueToString(right);
                return MK_STRING(leftStr ~ rightStr);
            }
            break;

        case "-":
        case "*":
        case "/":
        case "%":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
            {
                return this.performArithmeticOperation(left, right, op, resultType);
            }
            break;

        case "==":
            return MK_BOOL(this.compareValues(left, right));

        case "!=":
            return MK_BOOL(!this.compareValues(left, right));

        case "<":
        case ">":
        case "<=":
        case ">=":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
            {
                return this.performComparisonOperation(left, right, op);
            }
            else if (left.type.baseType == BaseType.String && right.type.baseType == BaseType
                .String)
            {
                string leftStr = left.value._string;
                string rightStr = right.value._string;

                switch (op)
                {
                case "<":
                    return MK_BOOL(leftStr < rightStr);
                case ">":
                    return MK_BOOL(leftStr > rightStr);
                case "<=":
                    return MK_BOOL(leftStr <= rightStr);
                case ">=":
                    return MK_BOOL(leftStr >= rightStr);
                default:
                    break;
                }
            }
            break;

        default:
            writeln(left);
            throw new Exception(format("Unknown binary operator: '%s'.", op));
        }

        throw new Exception(format("Operation '%s' not supported for types '%s' and '%s'.",
                op, cast(string) left.type.baseType, cast(string) right.type.baseType));
    }

    RuntimeValue performArithmeticOperation(RuntimeValue left, RuntimeValue right, string op, Type resultType)
    {
        auto leftConverted = this.convertToType(left, resultType.baseType);
        auto rightConverted = this.convertToType(right, resultType.baseType);

        switch (resultType.baseType)
        {
        case BaseType.Real:
            real leftVal = leftConverted.value._real;
            real rightVal = rightConverted.value._real;

            switch (op)
            {
            case "+":
                return MK_REAL(leftVal + rightVal);
            case "-":
                return MK_REAL(leftVal - rightVal);
            case "*":
                return MK_REAL(leftVal * rightVal);
            case "/":
                if (rightVal == 0.0L)
                    throw new Exception("Division by zero.");
                return MK_REAL(leftVal / rightVal);
            case "%":
                if (rightVal == 0.0L)
                    throw new Exception("Modulo by zero.");
                return MK_REAL(leftVal % rightVal);
            default:
                break;
            }
            break;

        case BaseType.Double:
            double leftVal = leftConverted.value._double;
            double rightVal = rightConverted.value._double;

            switch (op)
            {
            case "+":
                return MK_DOUBLE(leftVal + rightVal);
            case "-":
                return MK_DOUBLE(leftVal - rightVal);
            case "*":
                return MK_DOUBLE(leftVal * rightVal);
            case "/":
                if (rightVal == 0.0)
                    throw new Exception("Division by zero.");
                return MK_DOUBLE(leftVal / rightVal);
            case "%":
                if (rightVal == 0.0)
                    throw new Exception("Modulo by zero.");
                return MK_DOUBLE(leftVal % rightVal);
            default:
                break;
            }
            break;

        case BaseType.Float:
            float leftVal = leftConverted.value._float;
            float rightVal = rightConverted.value._float;

            switch (op)
            {
            case "+":
                return MK_FLOAT(leftVal + rightVal);
            case "-":
                return MK_FLOAT(leftVal - rightVal);
            case "*":
                return MK_FLOAT(leftVal * rightVal);
            case "/":
                if (rightVal == 0.0f)
                    throw new Exception("Division by zero.");
                return MK_FLOAT(leftVal / rightVal);
            case "%":
                if (rightVal == 0.0f)
                    throw new Exception("Modulo by zero.");
                return MK_FLOAT(leftVal % rightVal);
            default:
                break;
            }
            break;

        case BaseType.Int:
        default:
            long leftVal = leftConverted.value._int;
            long rightVal = rightConverted.value._int;

            switch (op)
            {
            case "+":
                return MK_INT(leftVal + rightVal);
            case "-":
                return MK_INT(leftVal - rightVal);
            case "*":
                return MK_INT(leftVal * rightVal);
            case "/":
                if (rightVal == 0)
                    throw new Exception("Division by zero.");
                return MK_INT(leftVal / rightVal);
            case "%":
                if (rightVal == 0)
                    throw new Exception("Modulo by zero.");
                return MK_INT(leftVal % rightVal);
            default:
                break;
            }
            break;
        }

        throw new Exception(format("Arithmetic operation '%s' not supported for type '%s'.",
                op, cast(string) resultType.baseType));
    }

    RuntimeValue performComparisonOperation(RuntimeValue left, RuntimeValue right, string op)
    {
        Type comparisonType = typeChecker.inferType(left.type, right.type);
        auto leftConverted = this.convertToType(left, comparisonType.baseType);
        auto rightConverted = this.convertToType(right, comparisonType.baseType);

        switch (comparisonType.baseType)
        {
        case BaseType.Real:
            real leftVal = leftConverted.value._real;
            real rightVal = rightConverted.value._real;

            switch (op)
            {
            case "<":
                return MK_BOOL(leftVal < rightVal);
            case ">":
                return MK_BOOL(leftVal > rightVal);
            case "<=":
                return MK_BOOL(leftVal <= rightVal);
            case ">=":
                return MK_BOOL(leftVal >= rightVal);
            default:
                break;
            }
            break;

        case BaseType.Double:
            double leftVal = leftConverted.value._double;
            double rightVal = rightConverted.value._double;

            switch (op)
            {
            case "<":
                return MK_BOOL(leftVal < rightVal);
            case ">":
                return MK_BOOL(leftVal > rightVal);
            case "<=":
                return MK_BOOL(leftVal <= rightVal);
            case ">=":
                return MK_BOOL(leftVal >= rightVal);
            default:
                break;
            }
            break;

        case BaseType.Float:
            float leftVal = leftConverted.value._float;
            float rightVal = rightConverted.value._float;

            switch (op)
            {
            case "<":
                return MK_BOOL(leftVal < rightVal);
            case ">":
                return MK_BOOL(leftVal > rightVal);
            case "<=":
                return MK_BOOL(leftVal <= rightVal);
            case ">=":
                return MK_BOOL(leftVal >= rightVal);
            default:
                break;
            }
            break;

        case BaseType.Int:
        default:
            long leftVal = leftConverted.value._int;
            long rightVal = rightConverted.value._int;

            switch (op)
            {
            case "<":
                return MK_BOOL(leftVal < rightVal);
            case ">":
                return MK_BOOL(leftVal > rightVal);
            case "<=":
                return MK_BOOL(leftVal <= rightVal);
            case ">=":
                return MK_BOOL(leftVal >= rightVal);
            default:
                break;
            }
            break;
        }

        throw new Exception(format("Comparison operation '%s' not supported for type '%s'.",
                op, cast(string) comparisonType.baseType));
    }

    RuntimeValue convertToType(RuntimeValue value, BaseType targetType)
    {
        if (value.type.baseType == targetType)
            return value; // Já é do tipo correto

        switch (targetType)
        {
        case BaseType.Real:
            switch (value.type.baseType)
            {
            case BaseType.Int:
                return MK_REAL(cast(real) value.value._int);
            case BaseType.Float:
                return MK_REAL(cast(real) value.value._float);
            case BaseType.Double:
                return MK_REAL(cast(real) value.value._double);
            default:
                break;
            }
            break;

        case BaseType.Double:
            switch (value.type.baseType)
            {
            case BaseType.Int:
                return MK_DOUBLE(cast(double) value.value._int);
            case BaseType.Float:
                return MK_DOUBLE(cast(double) value.value._float);
            case BaseType.Real:
                return MK_DOUBLE(cast(double) value.value._real);
            default:
                break;
            }
            break;

        case BaseType.Float:
            switch (value.type.baseType)
            {
            case BaseType.Int:
                return MK_FLOAT(cast(float) value.value._int);
            case BaseType.Double:
                return MK_FLOAT(cast(float) value.value._double);
            case BaseType.Real:
                return MK_FLOAT(cast(float) value.value._real);
            default:
                break;
            }
            break;

        case BaseType.Int:
            switch (value.type.baseType)
            {
            case BaseType.Float:
                return MK_INT(cast(long) value.value._float);
            case BaseType.Double:
                return MK_INT(cast(long) value.value._double);
            case BaseType.Real:
                return MK_INT(cast(long) value.value._real);
            default:
                break;
            }
            break;

        default:
            break;
        }

        throw new Exception(format("Cannot convert from '%s' to '%s'.",
                cast(string) value.type.baseType, cast(string) targetType));
    }

    string valueToString(RuntimeValue value)
    {
        switch (value.type.baseType)
        {
        case BaseType.String:
            return value.value._string;
        case BaseType.Int:
            return to!string(value.value._int);
        case BaseType.Float:
            return to!string(value.value._float);
        case BaseType.Double:
            return to!string(value.value._double);
        case BaseType.Real:
            return to!string(value.value._real);
        case BaseType.Bool:
            return value.value._bool ? "true" : "false";
        default:
            return "unknown";
        }
    }

    // Versão melhorada do compareValues para suportar mais tipos
    bool compareValues(RuntimeValue left, RuntimeValue right)
    {
        // Se são tipos diferentes, tenta converter para comparar
        if (left.type.baseType != right.type.baseType)
        {
            // Se ambos são numéricos, converte para o tipo de maior precisão
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
            {
                Type comparisonType = typeChecker.inferType(left.type, right.type);
                auto leftConverted = this.convertToType(left, comparisonType.baseType);
                auto rightConverted = this.convertToType(right, comparisonType.baseType);
                return this.compareValues(leftConverted, rightConverted);
            }
            return false; // Tipos incompatíveis
        }

        switch (left.type.baseType)
        {
        case BaseType.Int:
            return left.value._int == right.value._int;
        case BaseType.Float:
            return left.value._float == right.value._float;
        case BaseType.Double:
            return left.value._double == right.value._double;
        case BaseType.Real:
            return left.value._real == right.value._real;
        case BaseType.String:
            return left.value._string == right.value._string;
        case BaseType.Bool:
            return left.value._bool == right.value._bool;
        default:
            return false;
        }
    }

    RuntimeValue evalCallExpr(
        CallExpr callExpr)
    {
        if (!this.context.checkRuntimeValue(callExpr.id, true))
        {
            error.addError(Diagnostic(
                    format("Function '%s' was not declared.", callExpr
                    .id), callExpr
                    .loc));
            throw new Exception(format(
                    "Function '%s' was not declared.", callExpr
                    .id));
        }

        RuntimeValue funcValue = this.context
            .lookupRuntimeValue(callExpr.id, true);
        FunctionDeclaration funcDecl = funcValue.value
            ._function;
        long argsMin = 0;
        bool isVariadic = false;
        RuntimeValue[LIMIT] args;

        for (size_t i = 0; i < funcDecl.args
            .length; i++)
        {
            if (
                funcDecl.args[i].type
                .undefined)
            {
                isVariadic = true;
                break;
            }
            argsMin++;
        }

        if (
            callExpr.args.length < argsMin)
            throw new Exception(format("Function '%s' expects at least %d arguments, but %d were provided.",
                    callExpr.id, argsMin, callExpr.args
                    .length));

        if (!isVariadic && callExpr.args.length != argsMin)
            throw new Exception(
                format("Function '%s' expects exactly %d arguments, but %d were provided.",
                    callExpr.id, argsMin, callExpr.args
                    .length));

        // Argument evaluation
        for (size_t i = 0; i < callExpr.args
            .length; i++)
        {
            RuntimeValue argValue = this.eval(callExpr.args[i]);

            if (i < funcDecl.args.length && !funcDecl.args[i].type.undefined)
            {
                if (!typeChecker.isComp(
                        funcDecl.args[i].type, argValue
                        .type))
                    throw new Exception(format("Argument %d of function '%s': incompatible type.", i + 1, callExpr
                            .id));
            }
            args[i] = argValue;
        }

        if (funcValue.asExtern)
        {
            ExternFunc func = this.resolveExternFunction(
                funcDecl.name);
            if (!func)
                throw new Exception(format("Error: External function '%s' not found in any loaded library.", funcDecl
                        .name));
            // writefln("Calling function: %s with %d args", callExpr.id, callExpr.args.length);
            // writeln(callExpr.args);
            return func(args, callExpr.args.length);
        }

        this.context.pushContext();

        try
        {
            for (size_t i = 0; i < callExpr.args.length && i < funcDecl
                .args.length; i++)
                this.context.addRuntimeValue(
                    funcDecl.args[i].name, args[i]);

            RuntimeValue result;
            foreach (
                Node stmt; funcDecl
                .body)
            {
                result = this.eval(
                    stmt);
                if (
                    result
                    .haveReturn)
                {
                    result.haveReturn = false;
                    break;
                }
            }

            return result;
        }
        finally
        {
            // this.context.previousContext();
            this.context.popContext();
        }
    }

    void reloadLibraries()
    {
        this.cleanup();
        this.preloadLibraries();
    }

    bool addLibrary(string libPath)
    {
        if (libPath in libraryCache)
            return libraryCache[libPath]
                .isLoaded;

        void* lib = dlopen(libPath.toStringz(), RTLD_LAZY);
        if (lib)
        {
            libraryCache[libPath] = LibraryHandle(lib, libPath, true);
            loadOrder ~= libPath; // Add to loading order
            dlsopnso ~= libPath; // Add to original array
            return true;
        }
        else
        {
            libraryCache[libPath] = LibraryHandle(null, libPath, false);
            return false;
        }
    }
}
