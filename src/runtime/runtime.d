module runtime.runtime;

import std.stdio, std.format, std.conv, core.sys.posix.dlfcn, std.string, std.file;
import runtime.runtime_value, runtime.context, runtime.typechecker, config : LIMIT;
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
    alias ExternFunc = RuntimeValue function(RuntimeValue[LIMIT], ulong);

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

        case NodeKind.BinaryExpr:
            BinaryExpr binExpr = cast(BinaryExpr) node;
            RuntimeValue left = this.eval(binExpr.left);
            RuntimeValue right = this.eval(binExpr.right);

            return this.evalBinaryExpr(left, right, binExpr.op);

        case NodeKind.CallExpr:
            CallExpr callExpr = cast(CallExpr) node;
            return this.evalCallExpr(callExpr);

        case NodeKind.FuncDeclaration:
            FunctionDeclaration funcDecl = cast(FunctionDeclaration) node;
            RuntimeValue funcValue = MK_FUNCTION(funcDecl);
            this.context.addFunc(funcDecl.name, funcValue);
            return funcValue;

        case NodeKind.Extern:
            RuntimeValue funcValue = MK_FUNCTION(node.value.get!FunctionDeclaration);
            funcValue.asExtern = true;
            this.context.addFunc(node.value.get!FunctionDeclaration.name, funcValue);
            return funcValue;

        case NodeKind.Return:
            Return retNode = cast(Return) node;
            value = this.eval(retNode.value.get!Node);
            value.haveReturn = true;
            return value;

        case NodeKind.IfStatement:
            IfStatement ifStatement = cast(IfStatement) node;
            return this.evalIfStatement(ifStatement);

        case NodeKind.UseStatement:
            UseStatement useStatement = cast(UseStatement) node;
            return this.evalUseStatement(useStatement);

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
    RuntimeValue evalUseStatement(UseStatement node)
    {
        import std.path : buildPath;
        import std.file : readText, exists;
        import std.format : format;

        string file = buildPath(node.loc.dir, node.value.get!string);

        if (!exists(file))
        {
            error.addError(Diagnostic(format("File does not exists '%s'.", file), node.loc));
            throw new Exception(format("File does not exists '%s'.", file));
        }

        string fileContent = readText(file);

        import frontend.lexer.lexer, frontend.lexer.token, frontend.parser.parser;

        Lexer lexer = new Lexer(file, fileContent, ".", new DiagnosticError());
        Token[] tokens = lexer.tokenize();
        Program prog = new Parser(tokens).parse();

        foreach (Node n; prog.body)
        {
            if (n.kind != NodeKind.FuncDeclaration && n.kind != NodeKind.Extern && n.kind != NodeKind
                .UseStatement)
                continue;

            if (node.symbols.length == 0)
            {
                this.eval(n);
                continue;
            }

            string symbolName = getNodeSymbolName(n);
            if (symbolName !is null && symbolName in node.symbols)
                this.eval(n);
        }

        return MK_VOID();
    }

    string getNodeSymbolName(Node n)
    {
        if (n.kind == NodeKind.FuncDeclaration)
            return (cast(FunctionDeclaration) n).name;

        if (n.kind == NodeKind.Extern)
            return (cast(Extern) n).value.get!FunctionDeclaration.name;

        return null;
    }

    RuntimeValue evalIfStatement(IfStatement node)
    {
        RuntimeValue if_ = MK_VOID();
        RuntimeValue condition = this.eval(node.condition);

        if (condition.type.baseType != BaseType.Bool)
            throw new Exception("The condition of the ifStatement must be of type 'bool'.");

        if (condition.value._bool)
        {
            foreach (Node n; node.body)
            {
                RuntimeValue val = this.eval(n);
                if (val.haveReturn)
                {
                    return val;
                }
            }
        }
        else if (node.else_ !is null)
        {
            if (node.else_.kind == NodeKind.IfStatement)
                return this.evalIfStatement(cast(IfStatement) node.else_);
            ElseStatement else_ = cast(ElseStatement) node.else_;
            foreach (Node n; else_.body)
            {
                RuntimeValue val = this.eval(n);
                if (val.haveReturn)
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
                return MK_INT(left.value._int + right.value._int);
            else if (left.type.baseType == BaseType.String || right.type.baseType == BaseType
                .String)
            {
                string leftStr = (left.type.baseType == BaseType.String) ?
                    left.value._string : to!string(left.value._int);
                string rightStr = (right.type.baseType == BaseType.String) ?
                    right.value._string : to!string(right.value._int);
                return MK_STRING(leftStr ~ rightStr);
            }
            break;

        case "-":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
                return MK_INT(left.value._int - right.value._int);
            break;

        case "*":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
                return MK_INT(left.value._int * right.value._int);
            break;

        case "/":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
            {
                if (right.value._int == 0)
                    throw new Exception("Division by zero.");
                return MK_INT(left.value._int / right.value._int);
            }
            break;

        case "%":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
            {
                if (right.value._int == 0)
                    throw new Exception("Modulo by zero.");
                return MK_INT(left.value._int % right.value._int);
            }
            break;

        case "==":
            return MK_BOOL(this.compareValues(left, right));

        case "!=":
            return MK_BOOL(!this.compareValues(left, right));

        case "<":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
                return MK_BOOL(left.value._int < right.value._int);
            break;

        case ">":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
                return MK_BOOL(left.value._int > right.value._int);
            break;

        case "<=":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
                return MK_BOOL(left.value._int <= right.value._int);
            break;

        case ">=":
            if (typeChecker.isNumericType(left.type) && typeChecker.isNumericType(right.type))
                return MK_BOOL(left.value._int >= right.value._int);
            break;

        default:
            throw new Exception(format("Unknown binary operator: '%s'.", op));
        }

        throw new Exception(format("Operation '%s' not supported for given types.", op));
    }

    bool compareValues(RuntimeValue left, RuntimeValue right)
    {
        if (left.type.baseType != right.type.baseType)
            return false;

        switch (left.type.baseType)
        {
        case BaseType.Int:
            return left.value._int == right.value._int;
        case BaseType.String:
            return left.value._string == right.value._string;
        default:
            return false;
        }
    }

    RuntimeValue evalCallExpr(CallExpr callExpr)
    {
        if (!this.context.checkRuntimeValue(callExpr.id, true))
        {
            error.addError(Diagnostic(format("Function '%s' was not declared.", callExpr.id), callExpr
                    .loc));
            throw new Exception(format("Function '%s' was not declared.", callExpr.id));
        }

        RuntimeValue funcValue = this.context.lookupRuntimeValue(callExpr.id, true);
        FunctionDeclaration funcDecl = funcValue.value._function;
        long argsMin = 0;
        bool isVariadic = false;
        RuntimeValue[LIMIT] args;

        for (size_t i = 0; i < funcDecl.args.length; i++)
        {
            if (funcDecl.args[i].type.undefined)
            {
                isVariadic = true;
                break;
            }
            argsMin++;
        }

        if (callExpr.args.length < argsMin)
            throw new Exception(format("Function '%s' expects at least %d arguments, but %d were provided.",
                    callExpr.id, argsMin, callExpr.args.length));

        if (!isVariadic && callExpr.args.length != argsMin)
            throw new Exception(format("Function '%s' expects exactly %d arguments, but %d were provided.",
                    callExpr.id, argsMin, callExpr.args.length));

        // Argument evaluation
        for (size_t i = 0; i < callExpr.args.length; i++)
        {
            RuntimeValue argValue = this.eval(callExpr.args[i]);

            if (i < funcDecl.args.length && !funcDecl.args[i].type.undefined)
            {
                if (!typeChecker.isComp(funcDecl.args[i].type, argValue.type))
                    throw new Exception(format("Argument %d of function '%s': incompatible type.", i + 1, callExpr
                            .id));
            }
            args[i] = argValue;
        }

        if (funcValue.asExtern)
        {
            ExternFunc func = this.resolveExternFunction(funcDecl.name);
            if (!func)
                throw new Exception(format("Error: External function '%s' not found in any loaded library.", funcDecl
                        .name));
            // writefln("Calling function: %s with %d args", callExpr.id, callExpr.args.length);
            // writeln(callExpr.args);
            return func(args, cast(ulong) callExpr.args.length);
        }

        this.context.pushContext();

        try
        {
            for (size_t i = 0; i < callExpr.args.length && i < funcDecl.args.length;
                i++)
                this.context.addRuntimeValue(funcDecl.args[i].name, args[i]);

            RuntimeValue result;
            foreach (Node stmt; funcDecl.body)
            {
                result = this.eval(stmt);
                if (result.haveReturn)
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
            return libraryCache[libPath].isLoaded;

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
