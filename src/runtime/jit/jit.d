module runtime.jit.jit;

import std.stdio, std.string, std.process, std.file, std.path, std.format, std.conv, std.algorithm, std
    .ascii;
import runtime.jit.asm_gen;

version (linux)
{
    import core.sys.posix.sys.mman;
    import core.sys.posix.unistd;

    enum MAP_ANONYMOUS = 0x20;
}
else version (OSX)
{
    import core.sys.posix.sys.mman;
    import core.sys.posix.unistd;

    enum MAP_ANONYMOUS = 0x1000;
}
else
{
    enum MAP_ANONYMOUS = 0x20;
    enum PROT_READ = 1;
    enum PROT_WRITE = 2;
    enum PROT_EXEC = 4;
    enum MAP_PRIVATE = 2;
    extern (C) void* mmap(void*, size_t, int, int, int, long);
    extern (C) int munmap(void*, size_t);
    extern (C) int mprotect(void*, size_t, int);
}

alias JitFunction = extern (C) long function(long, long);

class Jit
{
    private string tempDir;
    private int counter;
    private void*[] allocatedPages;

    this()
    {
        tempDir = "/tmp/simple_jit";
        if (!exists(tempDir))
            mkdir(tempDir);
        counter = 0;
    }

    // ~this()
    // {
    //     foreach (page; allocatedPages)
    //         version (Posix)
    //             munmap(page, 4096);

    // }

    JitFunction compile(string assembly)
    {
        counter++;
        string baseName = format("jit_%d", counter);
        string asmFile = buildPath(tempDir, baseName ~ ".s");
        string objFile = buildPath(tempDir, baseName ~ ".o");

        try
        {
            std.file.write(asmFile, assembly);

            auto result = execute(["as", "--64", "-o", objFile, asmFile]);
            if (result.status != 0)
                throw new Exception("Assembly falhou: " ~ result.output);

            ubyte[] functionCode = extractFunctionCode(objFile, "jit_function");
            if (functionCode.length == 0)
                throw new Exception("Função não encontrada no objeto");
            return loadIntoExecutablePage(functionCode);
        }
        finally
        {
            if (exists(asmFile))
                remove(asmFile);
            if (exists(objFile))
                remove(objFile);
        }
    }

    private ubyte[] extractFunctionCode(string objFile, string functionName)
    {
        auto result = execute(["objdump", "-d", objFile]);
        if (result.status != 0)
        {
            throw new Exception("objdump falhou: " ~ result.output);
        }

        string binFile = objFile ~ ".bin";
        auto copyResult = execute([
            "objcopy", "-O", "binary", "-j", ".text", objFile, binFile
        ]);
        if (copyResult.status != 0)
        {
            throw new Exception("objcopy falhou: " ~ copyResult.output);
        }

        scope (exit)
        {
            if (exists(binFile))
                remove(binFile);
        }

        ubyte[] code = cast(ubyte[]) std.file.read(binFile);
        return code;
    }

    private JitFunction loadIntoExecutablePage(ubyte[] machineCode)
    {
        version (Posix)
        {
            // 4Kb
            void* page = mmap(null, 4096,
                PROT_READ | PROT_WRITE | PROT_EXEC,
                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

            if (page == cast(void*)-1)
            {
                throw new Exception("Falha ao alocar página executável");
            }

            import core.stdc.string : memcpy;

            memcpy(page, machineCode.ptr, machineCode.length);
            allocatedPages ~= page;
            return cast(JitFunction) page;
        }
        else
            throw new Exception("JIT não suportado nesta plataforma");
    }
}

// void main()
// {
//     auto gen = new AssemblyHelper;
//     gen.startFunction("jit_function", []);
//     gen.moveImediateToReg("60", "rax");
//     gen.moveImediateToReg("9", "rbx");
//     gen.addRegsTyped("rbx", "rax", DataType.QWORD);
//     gen.returnValue();

//     string assembly = gen.getAssembly();
//     auto jit = new Jit;
//     auto code = jit.compile(assembly);

//     long result = code();
//     writefln("%d", result);
// }

void main()
{
    import std.datetime.stopwatch;

    auto totalSw = StopWatch(AutoStart.yes);

    auto gen = new AssemblyHelper;
    gen.startFunction("jit_function", ["x", "y"]);
    gen.loadVar("x", "rax");
    gen.loadVar("y", "rbx");
    gen.addRegsTyped("rbx", "rax", DataType.QWORD);
    gen.returnValue();
    string assembly = gen.getAssembly();
    auto genTime = totalSw.peek();

    auto jit = new Jit;
    auto compileStart = totalSw.peek();
    auto code = jit.compile(assembly);
    auto compileTime = totalSw.peek() - compileStart;

    auto execStart = totalSw.peek();
    long result = code(30 << 1, 9);
    auto execTime = totalSw.peek() - execStart;

    totalSw.stop();

    writeln("Assembly generated:", assembly);
    writefln("Assembly gen: %d ms", genTime.total!"msecs");
    writefln("JIT compile: %d ms", compileTime.total!"msecs");
    writefln("Execute: %d ms", execTime.total!"msecs");
    writefln("Total: %d ms", totalSw.peek().total!"msecs");
    writefln("Result: %d", result);
}
