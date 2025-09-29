module runtime.jit.asm_gen;
import std.stdio, std.format, std.array, std.conv, std.string, std.algorithm;

enum Register : string
{
    RAX = "rax",
    RBX = "rbx",
    RCX = "rcx",
    RDX = "rdx",
    RSI = "rsi",
    RDI = "rdi",
    RSP = "rsp",
    RBP = "rbp",
    R8 = "r8",
    R9 = "r9",
    R10 = "r10",
    R11 = "r11",
    R12 = "r12",
    R13 = "r13",
    R14 = "r14",
    R15 = "r15",

    // Registradores de 32 bits
    EAX = "eax",
    EBX = "ebx",
    ECX = "ecx",
    EDX = "edx",
    ESI = "esi",
    EDI = "edi",
    ESP = "esp",
    EBP = "ebp",

    // Registradores de 16 bits
    AX = "ax",
    BX = "bx",
    CX = "cx",
    DX = "dx",

    // Registradores de 8 bits
    AL = "al",
    BL = "bl",
    CL = "cl",
    DL = "dl",
    AH = "ah",
    BH = "bh",
    CH = "ch",
    DH = "dh"
}

enum DataType
{
    BYTE, // 1 byte  - char, bool
    WORD, // 2 bytes - short
    DWORD, // 4 bytes - int, float
    QWORD, // 8 bytes - long, double, pointers
    TBYTE // 10 bytes - long double
}

struct DataTypeInfo
{
    string asmDirective;

    string movInstruction;
    string regSuffix;
    int size;
}

static immutable DataTypeInfo[DataType] TYPE_INFO = [
    DataType.BYTE: DataTypeInfo(".byte", "movb", "b", 1),
    DataType.WORD: DataTypeInfo(".word", "movw", "w", 2),
    DataType.DWORD: DataTypeInfo(".long", "movl", "l", 4),
    DataType.QWORD: DataTypeInfo(".quad", "movq", "q", 8),
    DataType.TBYTE: DataTypeInfo(".tbyte", "fld", "", 10)
];

struct Variable
{
    string name;
    bool isGlobal;
    int stackOffset;
    string dataLabel;
    DataType type;
    bool isArray;
    int arraySize;
}

struct StructField
{
    string name;
    DataType type;
    int offset;
}

struct StructDef
{
    string name;
    StructField[] fields;
    int totalSize;
}

struct LoopContext
{
    string startLabel;
    string endLabel;
    string continueLabel;
    string loopVar;
}

class AssemblyHelper
{
    private string[] dataSection;
    private string[] bssSection;
    private string[] textSection;
    private Variable[string] variables;
    private StructDef[string] structs;
    private LoopContext[] loopStack;
    private int stackOffset = 0;
    private int labelCounter = 0;
    private bool inFunction = false;
    private string currentFunction = "";
    private bool optimizeCode = true;

    // Registradores para passagem de parâmetros
    private static immutable string[] PARAM_REGS = [
        "rdi", "rsi", "rdx", "rcx", "r8", "r9"
    ];
    private static immutable string[] PARAM_REGS_32 = [
        "edi", "esi", "edx", "ecx", "r8d", "r9d"
    ];
    private static immutable string[] PARAM_REGS_16 = [
        "di", "si", "dx", "cx", "r8w", "r9w"
    ];
    private static immutable string[] PARAM_REGS_8 = [
        "dil", "sil", "dl", "cl", "r8b", "r9b"
    ];

    this()
    {
        dataSection = [];
        bssSection = [];
        textSection = [];
        variables.clear();
        structs.clear();
        loopStack = [];
    }

    void setOptimization(bool enable)
    {
        optimizeCode = enable;
    }

    void startProgram()
    {
        textSection ~= ".section .text";
        textSection ~= ".global _start";
        textSection ~= "";
        textSection ~= "_start:";
        functionProlog();
    }

    void startProgramWithFunctions()
    {
        if (textSection.length == 0)
        {
            textSection ~= ".section .text";
            textSection ~= ".global _start";
            textSection ~= "";
        }
    }

    void startProgramWithFunction(string name)
    {
        if (textSection.length == 0)
        {
            textSection ~= ".section .text";
            textSection ~= ".global " ~ name;
            textSection ~= "";
        }
    }

    void addMainFunction()
    {
        textSection ~= "_start:";
        functionProlog();
    }

    void endProgram()
    {
        textSection ~= "    movq $60, %rax    # sys_exit";
        textSection ~= "    movq $0, %rdi     # exit code 0";
        textSection ~= "    syscall";
    }

    void exitWithCode(string reg)
    {
        textSection ~= "    movq $60, %rax     # sys_exit";
        if (reg != "rdi")
            textSection ~= format("    movq %%%s, %%rdi   # exit code", reg);
        textSection ~= "    syscall";
    }

    void exitWithValue(long code)
    {
        textSection ~= "    movq $60, %rax     # sys_exit";
        textSection ~= format("    movq $%d, %%rdi    # exit code", code);
        textSection ~= "    syscall";
    }

    void declareGlobalVar(string name, DataType type, long value = 0)
    {
        if (dataSection.length == 0)
            dataSection ~= ".section .data";
        dataSection ~= format("    %s: %s %d", name, TYPE_INFO[type].asmDirective, value);
        variables[name] = Variable(name, true, 0, name, type, false, 0);
    }

    void declareGlobalArray(string name, DataType type, long[] values)
    {
        if (dataSection.length == 0)
            dataSection ~= ".section .data";
        string valueStr = values.map!(v => v.to!string).join(", ");
        dataSection ~= format("    %s: %s %s", name, TYPE_INFO[type].asmDirective, valueStr);
        dataSection ~= format("    %s_size = %d", name, values.length);
        variables[name] = Variable(name, true, 0, name, type, true, cast(int) values.length);
    }

    void declareGlobalString(string name, string value)
    {
        if (dataSection.length == 0)
            dataSection ~= ".section .data";

        string processedValue = value.replace("\\n", "\\012")
            .replace("\\t", "\\011")
            .replace("\\r", "\\015")
            .replace("\\\"", "\\042")
            .replace("\\\\", "\\134");

        dataSection ~= format("    %s: .ascii \"%s\"", name, processedValue);
        dataSection ~= format("    %s_len = . - %s", name, name);
        variables[name] = Variable(name, true, 0, name, DataType.BYTE, true, cast(int) value.length);
    }

    void declareLocalVar(string name, DataType type)
    {
        if (!inFunction)
            throw new Exception("Variáveis locais só podem ser declaradas dentro de funções");

        int size = TYPE_INFO[type].size;
        stackOffset -= size;
        // Alinha para múltiplos de 8 bytes se necessário
        if (stackOffset % 8 != 0)
            stackOffset = (stackOffset / 8) * 8;

        variables[name] = Variable(name, false, stackOffset, "", type, false, 0);
        textSection ~= format("    subq $%d, %%rsp    # espaço para %s (%s)",
            size, name, type);
    }

    void declareLocalArray(string name, DataType type, int count)
    {
        if (!inFunction)
            throw new Exception("Arrays locais só podem ser declarados dentro de funções");

        int totalSize = TYPE_INFO[type].size * count;
        stackOffset -= totalSize;

        variables[name] = Variable(name, false, stackOffset, "", type, true, count);
        textSection ~= format("    subq $%d, %%rsp    # espaço para %s[%d] (%s)",
            totalSize, name, count, type);
    }

    void defineStruct(string name, StructField[] fields)
    {
        int offset = 0;
        StructField[] alignedFields;

        foreach (field; fields)
        {
            int fieldSize = TYPE_INFO[field.type].size;
            // Alinhamento simples
            if (offset % fieldSize != 0)
                offset = ((offset / fieldSize) + 1) * fieldSize;

            alignedFields ~= StructField(field.name, field.type, offset);
            offset += fieldSize;
        }

        // Alinha o tamanho total da struct para 8 bytes
        if (offset % 8 != 0)
            offset = ((offset / 8) + 1) * 8;

        structs[name] = StructDef(name, alignedFields, offset);

        comment(format("Struct %s definida - tamanho: %d bytes", name, offset));
        foreach (field; alignedFields)
            comment(format("  %s: offset %d (%s)", field.name, field.offset, field.type));
    }

    void declareGlobalStruct(string varName, string structName, string[string] fieldValues = null)
    {
        if (structName !in structs)
            throw new Exception(format("Struct '%s' não foi definida", structName));

        if (dataSection.length == 0)
            dataSection ~= ".section .data";

        StructDef structDef = structs[structName];
        dataSection ~= format("%s: # struct %s", varName, structName);

        int currentOffset = 0;
        foreach (field; structDef.fields)
        {
            // Padding se necessário
            while (currentOffset < field.offset)
            {
                dataSection ~= "    .byte 0";
                currentOffset++;
            }

            string value = "0";
            if (field.name in fieldValues)
            {
                value = fieldValues[field.name];
            }

            dataSection ~= format("    %s %s    # %s",
                TYPE_INFO[field.type].asmDirective, value, field.name);
            currentOffset += TYPE_INFO[field.type].size;
        }

        variables[varName] = Variable(varName, true, 0, varName, DataType.QWORD, false, 0);
    }

    void loadVar(string varName, string reg = "rax")
    {
        if (varName !in variables)
            throw new Exception(format("Variável '%s' não foi declarada", varName));

        Variable var = variables[varName];
        string movInst = TYPE_INFO[var.type].movInstruction;
        string targetReg = getRegisterName(reg, var.type);

        if (var.isGlobal)
            textSection ~= format("    %s %s(%%rip), %%%s", movInst, var.dataLabel, targetReg);
        else
            textSection ~= format("    %s %d(%%rbp), %%%s", movInst, var.stackOffset, targetReg);
    }

    void storeVar(string varName, string reg = "rax")
    {
        if (varName !in variables)
            throw new Exception(format("Variável '%s' não foi declarada", varName));

        Variable var = variables[varName];
        string movInst = TYPE_INFO[var.type].movInstruction;
        string sourceReg = getRegisterName(reg, var.type);

        if (var.isGlobal)
            textSection ~= format("    %s %%%s, %s(%%rip)", movInst, sourceReg, var.dataLabel);
        else
            textSection ~= format("    %s %%%s, %d(%%rbp)", movInst, sourceReg, var.stackOffset);
    }

    void loadStructField(string structVar, string fieldName, string reg = "rax")
    {
        if (structVar !in variables)
            throw new Exception(format("Variável struct '%s' não foi declarada", structVar));

        Variable var = variables[structVar];
        // Encontra a definição da struct pela análise dos campos existentes
        StructDef* structDef = null;
        foreach (ref struct_; structs)
        {
            foreach (field; struct_.fields)
            {
                if (field.name == fieldName)
                {
                    structDef = &struct_;
                    break;
                }
            }
            if (structDef)
                break;
        }

        if (!structDef)
            throw new Exception(format("Campo '%s' não encontrado em nenhuma struct", fieldName));

        StructField* field = null;
        foreach (ref f; structDef.fields)
        {
            if (f.name == fieldName)
            {
                field = &f;
                break;
            }
        }

        if (!field)
            throw new Exception(format("Campo '%s' não encontrado na struct", fieldName));

        string movInst = TYPE_INFO[field.type].movInstruction;
        if (var.isGlobal)
            textSection ~= format("    %s %s+%d(%%rip), %%%s",
                movInst, var.dataLabel, field.offset, reg);
        else
            textSection ~= format("    %s %d(%%rbp), %%%s",
                movInst, var.stackOffset + field.offset, reg);
    }

    void storeStructField(string structVar, string fieldName, string reg = "rax")
    {
        // Similar ao loadStructField, mas para store
        if (structVar !in variables)
            throw new Exception(format("Variável struct '%s' não foi declarada", structVar));

        Variable var = variables[structVar];
        StructDef* structDef = null;
        foreach (ref struct_; structs)
        {
            foreach (field; struct_.fields)
            {
                if (field.name == fieldName)
                {
                    structDef = &struct_;
                    break;
                }
            }
            if (structDef)
                break;
        }

        if (!structDef)
            throw new Exception(format("Campo '%s' não encontrado em nenhuma struct", fieldName));

        StructField* field = null;
        foreach (ref f; structDef.fields)
        {
            if (f.name == fieldName)
            {
                field = &f;
                break;
            }
        }

        string movInst = TYPE_INFO[field.type].movInstruction;

        if (var.isGlobal)
            textSection ~= format("    %s %%%s, %s+%d(%%rip)",
                movInst, reg, var.dataLabel, field.offset);
        else
            textSection ~= format("    %s %%%s, %d(%%rbp)",
                movInst, reg, var.stackOffset + field.offset);
    }

    void castRegister(DataType fromType, DataType toType, string reg = "rax")
    {
        if (fromType == toType)
            return;

        comment(format("Cast: %s -> %s", fromType, toType));

        // Zero-extension (unsigned)
        if (TYPE_INFO[fromType].size < TYPE_INFO[toType].size)
        {
            switch (fromType)
            {
            case DataType.BYTE:
                if (toType >= DataType.WORD)
                {
                    textSection ~= format("    movzbl %%%s, %%%s",
                        getRegisterName(reg, DataType.BYTE),
                        getRegisterName(reg, toType));
                }
                // if (toType > DataType.WORD)
                // {
                //     textSection ~= format("    movzbq %%%s, %%%s",
                //         getRegisterName(reg, DataType.BYTE),
                //         getRegisterName(reg, toType));
                // }
                break;
            case DataType.WORD:
                if (toType >= DataType.DWORD)
                {
                    textSection ~= format("    movzwl %%%s, %%%s",
                        getRegisterName(reg, DataType.WORD),
                        getRegisterName(reg, toType));
                }
                break;
            case DataType.DWORD:
                if (toType == DataType.QWORD)
                {
                    // movl automaticamente zera os 32 bits superiores
                    textSection ~= format("    movl %%%s, %%%s",
                        getRegisterName(reg, DataType.DWORD),
                        getRegisterName(reg, DataType.DWORD));
                }
                break;
            default:
                break;
            }
        }
        // Truncation (maior para menor)
        else if (TYPE_INFO[fromType].size > TYPE_INFO[toType].size)
        {
            // Não precisa fazer nada especial - usar parte menor do registrador
            comment(format("Truncating %s to %s", fromType, toType));
        }
    }

    void signExtendRegister(DataType fromType, DataType toType, string reg = "rax")
    {
        if (fromType == toType)
            return;

        comment(format("Sign extend: %s -> %s", fromType, toType));

        switch (fromType)
        {
        case DataType.BYTE:
            if (toType >= DataType.WORD)
            {
                textSection ~= format("    movsbq %%%s, %%%s",
                    getRegisterName(reg, DataType.BYTE),
                    getRegisterName(reg, toType));
            }
            break;
        case DataType.WORD:
            if (toType >= DataType.DWORD)
            {
                textSection ~= format("    movswq %%%s, %%%s",
                    getRegisterName(reg, DataType.WORD),
                    getRegisterName(reg, toType));
            }
            break;
        case DataType.DWORD:
            if (toType == DataType.QWORD)
            {
                textSection ~= format("    movslq %%%s, %%%s",
                    getRegisterName(reg, DataType.DWORD),
                    getRegisterName(reg, toType));
            }
            break;
        default:
            break;
        }
    }

    private string getRegisterName(string baseReg, DataType type)
    {
        if (baseReg.startsWith("%"))
            baseReg = baseReg[1 .. $];

        switch (baseReg)
        {
        case "rax":
            switch (type)
            {
            case DataType.BYTE:
                return "al";
            case DataType.WORD:
                return "ax";
            case DataType.DWORD:
                return "eax";
            case DataType.QWORD:
                return "rax";
            default:
                return "rax";
            }
        case "rbx":
            switch (type)
            {
            case DataType.BYTE:
                return "bl";
            case DataType.WORD:
                return "bx";
            case DataType.DWORD:
                return "ebx";
            case DataType.QWORD:
                return "rbx";
            default:
                return "rbx";
            }
        case "rcx":
            switch (type)
            {
            case DataType.BYTE:
                return "cl";
            case DataType.WORD:
                return "cx";
            case DataType.DWORD:
                return "ecx";
            case DataType.QWORD:
                return "rcx";
            default:
                return "rcx";
            }
        case "rdx":
            switch (type)
            {
            case DataType.BYTE:
                return "dl";
            case DataType.WORD:
                return "dx";
            case DataType.DWORD:
                return "edx";
            case DataType.QWORD:
                return "rdx";
            default:
                return "rdx";
            }
        case "rsi":
            switch (type)
            {
            case DataType.BYTE:
                return "sil";
            case DataType.WORD:
                return "si";
            case DataType.DWORD:
                return "esi";
            case DataType.QWORD:
                return "rsi";
            default:
                return "rsi";
            }
        case "rdi":
            switch (type)
            {
            case DataType.BYTE:
                return "dil";
            case DataType.WORD:
                return "di";
            case DataType.DWORD:
                return "edi";
            case DataType.QWORD:
                return "rdi";
            default:
                return "rdi";
            }
        default:
            // Para r8-r15, etc., usa sufixos
            if (baseReg.startsWith("r") && baseReg.length == 3)
            {
                string regNum = baseReg[1 .. $];
                switch (type)
                {
                case DataType.BYTE:
                    return regNum ~ "b";
                case DataType.WORD:
                    return regNum ~ "w";
                case DataType.DWORD:
                    return regNum ~ "d";
                case DataType.QWORD:
                    return baseReg;
                default:
                    return baseReg;
                }
            }
            return baseReg;
        }
    }

    void startForLoop(string indexVar, string startValue, string op, string endValue, string stepValue = "1")
    {
        if (indexVar !in variables)
            throw new Exception(format("Variável de índice '%s' deve ser declarada antes do loop", indexVar));

        string startLabel = generateLabel("for_start_");
        string endLabel = generateLabel("for_end_");
        string continueLabel = generateLabel("for_continue_");

        // Inicializa variável de controle
        if (startValue in variables)
            loadVar(startValue);
        else
            loadImmediate(startValue.to!long);
        storeVar(indexVar);
        label(startLabel);

        // Condição do loop
        loadVar(indexVar);
        push();
        if (endValue in variables)
            loadVar(endValue);
        else
            loadImmediate(endValue.to!long);
        push();
        compare(op);
        jumpIfZero(endLabel);

        loopStack ~= LoopContext(startLabel, endLabel, continueLabel, indexVar);
        comment(format("FOR: %s = %s to %s step %s", indexVar, startValue, endValue, stepValue));
    }

    void endForLoop(string stepValue = "1")
    {
        if (loopStack.length == 0)
            throw new Exception("endForLoop sem startForLoop correspondente");

        LoopContext ctx = loopStack[$ - 1];
        loopStack = loopStack[0 .. $ - 1];

        label(ctx.continueLabel);

        // Incrementa variável de controle
        loadVar(ctx.loopVar);
        if (stepValue in variables)
        {
            loadVar(stepValue, "rbx");
            addRegs("rbx", "rax");
        }
        else
        {
            loadImmediate(stepValue.to!long, "rbx");
            addRegs("rbx", "rax");
        }
        storeVar(ctx.loopVar);

        jump(ctx.startLabel);
        label(ctx.endLabel);
        comment("END FOR");
    }

    void startWhileLoop(string condition = "")
    {
        string startLabel = generateLabel("while_start_");
        string endLabel = generateLabel("while_end_");
        string continueLabel = startLabel;

        label(startLabel);

        loopStack ~= LoopContext(startLabel, endLabel, continueLabel, "");
        comment("WHILE loop start");
    }

    void whileCondition(string var1, string op, string var2)
    {
        if (loopStack.length == 0)
            throw new Exception("whileCondition sem startWhileLoop");

        if (var1 in variables)
            loadVar(var1);
        else
            loadImmediate(var1.to!long);
        push();

        if (var2 in variables)
            loadVar(var2);
        else
            loadImmediate(var2.to!long);
        push();

        compare(op);
        jumpIfZero(loopStack[$ - 1].endLabel);
    }

    void endWhileLoop()
    {
        if (loopStack.length == 0)
            throw new Exception("endWhileLoop sem startWhileLoop correspondente");

        LoopContext ctx = loopStack[$ - 1];
        loopStack = loopStack[0 .. $ - 1];

        jump(ctx.startLabel);
        label(ctx.endLabel);
        comment("END WHILE");
    }

    void breakLoop()
    {
        if (loopStack.length == 0)
            throw new Exception("break fora de loop");
        jump(loopStack[$ - 1].endLabel);
    }

    void continueLoop()
    {
        if (loopStack.length == 0)
            throw new Exception("continue fora de loop");
        jump(loopStack[$ - 1].continueLabel);
    }

    void optimizeRedundantMoves()
    {
        if (!optimizeCode)
            return;

        for (int i = 0; i < cast(int) textSection.length - 1; i++)
        {
            string current = textSection[i].strip();
            string next = textSection[i + 1].strip();

            // Remove movq %rax, %rax
            if (current.canFind("movq %") && current.canFind(", %"))
            {
                auto parts = current.split(", ");
                if (parts.length == 2 && parts[0].endsWith(parts[1].split("%")[1]))
                {
                    textSection[i] = "    # Optimized: removed redundant move";
                    continue;
                }
            }

            // Remove push/pop consecutivos do mesmo registrador
            if (current.startsWith("    pushq %") && next.startsWith("    popq %"))
            {
                string pushReg = current.split("%")[1];
                string popReg = next.split("%")[1];
                if (pushReg == popReg)
                {
                    textSection[i] = "    # Optimized: removed push/pop pair";
                    textSection[i + 1] = "";
                    i++; // Pula próxima iteração
                }
            }
        }
    }

    void loadImmediate(long value, string reg = "rax")
    {
        textSection ~= format("    movq $%d, %%%s", value, reg);
    }

    void loadImmediate(string value, string reg = "rax")
    {
        textSection ~= format("    movq $%s, %%%s", value, reg);
    }

    void loadAddress(string label, string reg = "rax")
    {
        textSection ~= format("    leaq %s(%%rip), %%%s", label, reg);
    }

    void addRegs(string src, string dst)
    {
        textSection ~= format("    addq %%%s, %%%s", src, dst);
    }

    void addRegsTyped(string src, string dst, DataType type)
    {
        string addInst = "addq";
        if (type == DataType.DWORD)
            addInst = "addl";
        else if (type == DataType.WORD)
            addInst = "addw";
        else if (type == DataType.BYTE)
            addInst = "addb";

        string srcReg = getRegisterName(src, type);
        string dstReg = getRegisterName(dst, type);
        textSection ~= format("    %s %%%s, %%%s", addInst, srcReg, dstReg);
    }

    void subRegs(string src, string dst)
    {
        textSection ~= format("    subq %%%s, %%%s", src, dst);
    }

    void mulRegs(string src, string dst)
    {
        textSection ~= format("    imulq %%%s, %%%s", src, dst);
    }

    void divRegs(string divisor)
    {
        textSection ~= "    cqo                 # extende sinal";
        textSection ~= format("    idivq %%%s         # rax = rdx:rax / %s, rdx = resto", divisor, divisor);
    }

    void binaryOp(string op)
    {
        textSection ~= "    popq %rcx           # operando direito";
        textSection ~= "    popq %rax           # operando esquerdo";

        switch (op)
        {
        case "+":
            textSection ~= "    addq %rcx, %rax";
            break;
        case "-":
            textSection ~= "    subq %rcx, %rax";
            break;
        case "*":
            textSection ~= "    imulq %rcx, %rax";
            break;
        case "/":
            textSection ~= "    cqo";
            textSection ~= "    idivq %rcx";
            break;
        case "%":
            textSection ~= "    cqo";
            textSection ~= "    idivq %rcx";
            textSection ~= "    movq %rdx, %rax";
            break;
        case "&":
            textSection ~= "    andq %rcx, %rax";
            break;
        case "|":
            textSection ~= "    orq %rcx, %rax";
            break;
        case "^":
            textSection ~= "    xorq %rcx, %rax";
            break;
        case "<<":
            textSection ~= "    shlq %cl, %rax";
            break;
        case ">>":
            textSection ~= "    shrq %cl, %rax";
            break;
        default:
            throw new Exception(format("Operador '%s' não suportado", op));
        }

        textSection ~= "    pushq %rax          # resultado";
    }

    void compare(string op)
    {
        textSection ~= "    popq %rcx           # operando direito";
        textSection ~= "    popq %rax           # operando esquerdo";
        textSection ~= "    cmpq %rcx, %rax";

        switch (op)
        {
        case "==":
            textSection ~= "    sete %al";
            break;
        case "!=":
            textSection ~= "    setne %al";
            break;
        case "<":
            textSection ~= "    setl %al";
            break;
        case "<=":
            textSection ~= "    setle %al";
            break;
        case ">":
            textSection ~= "    setg %al";
            break;
        case ">=":
            textSection ~= "    setge %al";
            break;
        default:
            throw new Exception(format("Operador de comparação '%s' não suportado", op));
        }

        textSection ~= "    movzbq %al, %rax    # zero-extend para 64 bits";
        textSection ~= "    pushq %rax";
    }

    void push(string reg = "rax")
    {
        textSection ~= format("    pushq %%%s", reg);
    }

    void pop(string reg = "rax")
    {
        textSection ~= format("    popq %%%s", reg);
    }

    void pushImmediate(long value)
    {
        textSection ~= format("    pushq $%d", value);
    }

    string generateLabel(string prefix = "L")
    {
        return format("%s%d", prefix, labelCounter++);
    }

    void label(string labelName)
    {
        textSection ~= format("%s:", labelName);
    }

    void jump(string labelName)
    {
        textSection ~= format("    jmp %s", labelName);
    }

    void jumpIfZero(string labelName)
    {
        textSection ~= "    popq %rax";
        textSection ~= "    testq %rax, %rax";
        textSection ~= format("    jz %s", labelName);
    }

    void jumpIfNotZero(string labelName)
    {
        textSection ~= "    popq %rax";
        textSection ~= "    testq %rax, %rax";
        textSection ~= format("    jnz %s", labelName);
    }

    void startFunction(string name, string[] params = [])
    {
        if (params.length > PARAM_REGS.length)
        {
            throw new Exception(format("Máximo de %d parâmetros suportados", PARAM_REGS.length));
        }

        inFunction = true;
        currentFunction = name;

        // Limpa variáveis locais da função anterior
        string[] toRemove;
        foreach (varName, var; variables)
        {
            if (!var.isGlobal)
            {
                toRemove ~= varName;
            }
        }
        foreach (varName; toRemove)
        {
            variables.remove(varName);
        }

        stackOffset = 0;

        textSection ~= "";
        textSection ~= format("%s:", name);
        functionProlog();

        // Mapeia parâmetros para variáveis locais
        foreach (i, param; params)
        {
            declareLocalVar(param, DataType.QWORD); // Default para 64-bit
            textSection ~= format("    movq %%%s, %d(%%rbp)    # parâmetro %s",
                PARAM_REGS[i], variables[param].stackOffset, param);
        }
    }

    void startTypedFunction(string name, DataType returnType,
        string[] paramNames, DataType[] paramTypes)
    {
        if (paramNames.length != paramTypes.length)
            throw new Exception("Número de nomes e tipos de parâmetros deve ser igual");
        if (paramNames.length > PARAM_REGS.length)
            throw new Exception(format("Máximo de %d parâmetros suportados", PARAM_REGS.length));

        inFunction = true;
        currentFunction = name;

        // Limpa variáveis locais da função anterior
        string[] toRemove;
        foreach (varName, var; variables)
            if (!var.isGlobal)
                toRemove ~= varName;
        foreach (varName; toRemove)
            variables.remove(varName);

        stackOffset = 0;
        textSection ~= "";
        textSection ~= format("%s:    # returns %s", name, returnType);
        functionProlog();

        // Mapeia parâmetros tipados
        foreach (i, param; paramNames)
        {
            declareLocalVar(param, paramTypes[i]);
            string paramReg = getParamRegister(paramTypes[i], i);
            string movInst = TYPE_INFO[paramTypes[i]].movInstruction;

            textSection ~= format("    %s %%%s, %d(%%rbp)    # %s %s",
                movInst, paramReg, variables[param].stackOffset,
                paramTypes[i], param);
        }
    }

    private string getParamRegister(DataType type, ulong index)
    {
        return getParamRegister(type, cast(int) index);
    }

    private string getParamRegister(DataType type, int index)
    {
        switch (type)
        {
        case DataType.BYTE:
            return PARAM_REGS_8[index];
        case DataType.WORD:
            return PARAM_REGS_16[index];
        case DataType.DWORD:
            return PARAM_REGS_32[index];
        case DataType.QWORD:
            return PARAM_REGS[index];
        default:
            return PARAM_REGS[index];
        }
    }

    void endFunction()
    {
        functionEpilog();
        textSection ~= "    ret";
        textSection ~= "";
        inFunction = false;
        currentFunction = "";
    }

    void returnValue(string reg = "rax")
    {
        if (reg != "rax")
            textSection ~= format("    movq %%%s, %%rax", reg);
        functionEpilog();
        textSection ~= "    ret";
    }

    void returnImmediate(long value)
    {
        textSection ~= format("    movq $%d, %%rax", value);
        functionEpilog();
        textSection ~= "    ret";
    }

    void callFunction(string name, int argCount = 0)
    {
        textSection ~= format("    call %s", name);
        textSection ~= "    pushq %rax          # resultado da função";
    }

    void setupFunctionCall(string[] args)
    {
        if (args.length > PARAM_REGS.length)
            throw new Exception(format("Máximo de %d argumentos suportados", PARAM_REGS.length));

        foreach (i, arg; args)
            if (arg in variables)
                loadVar(arg, PARAM_REGS[i]);
            else
                try
                    loadImmediate(arg.to!long, PARAM_REGS[i]);
                catch (Exception)
                    loadImmediate(arg, PARAM_REGS[i]);
    }

    void setupTypedFunctionCall(string[] args, DataType[] argTypes)
    {
        if (args.length != argTypes.length)
            throw new Exception("Número de argumentos e tipos deve ser igual");
        if (args.length > PARAM_REGS.length)
            throw new Exception(format("Máximo de %d argumentos suportados", PARAM_REGS.length));

        foreach (i, arg; args)
        {
            string paramReg = getParamRegister(argTypes[i], i);

            if (arg in variables)
            {
                Variable var = variables[arg];
                string movInst = TYPE_INFO[var.type].movInstruction;

                if (var.isGlobal)
                    textSection ~= format("    %s %s(%%rip), %%%s", movInst, var.dataLabel, paramReg);
                else
                    textSection ~= format("    %s %d(%%rbp), %%%s", movInst, var.stackOffset, paramReg);

                // Cast se necessário
                if (var.type != argTypes[i])
                {
                    castRegister(var.type, argTypes[i], paramReg.split("r")[0] ~ "rax");
                    textSection ~= format("    movq %%rax, %%%s", paramReg);
                }
            }
            else
            {
                try
                {
                    long value = arg.to!long;
                    string movInst = TYPE_INFO[argTypes[i]].movInstruction;
                    textSection ~= format("    %s $%d, %%%s", movInst, value, paramReg);
                }
                catch (Exception)
                {
                    textSection ~= format("    movq $%s, %%%s", arg, paramReg);
                }
            }
        }
    }

    // === I/O AVANÇADO ===
    void syscall()
    {
        textSection ~= "    syscall";
    }

    void writeString(string stringVar)
    {
        if (stringVar !in variables)
        {
            throw new Exception(format("String '%s' não foi declarada", stringVar));
        }

        textSection ~= "    movq $1, %rax       # sys_write";
        textSection ~= "    movq $1, %rdi       # stdout";
        textSection ~= format("    leaq %s(%%rip), %%rsi", stringVar);
        textSection ~= format("    movq $%s_len, %%rdx", stringVar);
        textSection ~= "    syscall";
    }

    void writeStringLiteral(string text)
    {
        string labelName = generateLabel("str_");
        declareGlobalString(labelName, text);
        writeString(labelName);
    }

    void printInteger(string reg = "rax")
    {
        // Implementação básica para imprimir números
        comment("Print integer (simplified)");

        // Salva registradores
        textSection ~= format("    pushq %%%s", reg);
        textSection ~= "    pushq %rbx";
        textSection ~= "    pushq %rcx";
        textSection ~= "    pushq %rdx";

        // Para números pequenos (0-9), conversão simples
        textSection ~= format("    movq %%%s, %%rax", reg == "rax" ? "rax" : reg);
        textSection ~= "    addq 0', %rax";
        textSection ~= "    pushq %rax";

        // Write syscall
        textSection ~= "    movq $1, %rax       # sys_write";
        textSection ~= "    movq $1, %rdi       # stdout";
        textSection ~= "    movq %rsp, %rsi     # endereço do char na stack";
        textSection ~= "    movq $1, %rdx       # 1 byte";
        textSection ~= "    syscall";

        // Limpa stack e restaura registradores
        textSection ~= "    addq $8, %rsp       # remove char da stack";
        textSection ~= "    popq %rdx";
        textSection ~= "    popq %rcx";
        textSection ~= "    popq %rbx";
        textSection ~= format("    popq %%%s", reg);
    }

    void printNewline()
    {
        textSection ~= "    movq $1, %rax       # sys_write";
        textSection ~= "    movq $1, %rdi       # stdout";
        textSection ~= "    pushq \\n'";
        textSection ~= "    movq %rsp, %rsi";
        textSection ~= "    movq $1, %rdx";
        textSection ~= "    syscall";
        textSection ~= "    addq $8, %rsp       # limpa stack";
    }

    // === MACROS E TEMPLATES ===
    void defineMacro(string name, string[] paramNames, string[] instructions)
    {
        comment(format("MACRO %s(%s) defined", name, paramNames.join(", ")));
        // Por simplicidade, armazena como comentários
        // Uma implementação completa substituiria parâmetros por valores
        foreach (inst; instructions)
        {
            comment(format("  %s", inst));
        }
    }

    void useMacro(string name, string[] args)
    {
        comment(format("MACRO %s(%s) invoked", name, args.join(", ")));
        // Implementação simplificada - em uma versão completa,
        // expandiria as instruções do macro com os argumentos
    }

    // === DEBUGGING E SÍMBOLOS ===
    void addDebugInfo(string sourceFile, int lineNumber)
    {
        if (optimizeCode)
            return; // Pula debug info se otimizando

        textSection ~= format("    # %s:%d", sourceFile, lineNumber);
    }

    void addDebugSymbol(string symbolName, string symbolType)
    {
        comment(format("DEBUG: %s %s", symbolType, symbolName));
    }

    // === BIBLIOTECA EXTERNA (LIBC) ===
    void linkLibC()
    {
        // Adiciona declarações para usar libc
        textSection = [".section .text", ".global main", ""] ~ textSection;

        // Muda _start para main
        for (int i = 0; i < textSection.length; i++)
        {
            if (textSection[i] == "_start:")
            {
                textSection[i] = "main:";
                break;
            }
        }

        comment("Linked with libc - use gcc to compile");
    }

    void callLibCFunction(string funcName, string[] args)
    {
        setupFunctionCall(args);
        textSection ~= format("    call %s", funcName);
        textSection ~= "    pushq %rax          # resultado da função libc";
    }

    // === UTILITÁRIOS ===
    private void functionProlog()
    {
        textSection ~= "    pushq %rbp";
        textSection ~= "    movq %rsp, %rbp";
    }

    private void functionEpilog()
    {
        textSection ~= "    movq %rbp, %rsp";
        textSection ~= "    popq %rbp";
    }

    void comment(string text)
    {
        textSection ~= format("    # %s", text);
    }

    void rawInstruction(string instruction)
    {
        textSection ~= format("    %s", instruction);
    }

    void clearRegister(string reg)
    {
        textSection ~= format("    xorq %%%s, %%%s", reg, reg);
    }

    void moveRegToReg(string src, string dst)
    {
        textSection ~= format("    movq %%%s, %%%s", src, dst);
    }

    void moveImediateToReg(string src, string dst)
    {
        textSection ~= format("    movq $%s, %%%s", src, dst);
    }

    void incrementVar(string varName)
    {
        if (varName in variables)
        {
            Variable var = variables[varName];
            string incInst = "incq";
            if (var.type == DataType.DWORD)
                incInst = "incl";
            else if (var.type == DataType.WORD)
                incInst = "incw";
            else if (var.type == DataType.BYTE)
                incInst = "incb";

            if (var.isGlobal)
            {
                textSection ~= format("    %s %s(%%rip)", incInst, var.dataLabel);
            }
            else
            {
                textSection ~= format("    %s %d(%%rbp)", incInst, var.stackOffset);
            }
        }
    }

    void decrementVar(string varName)
    {
        if (varName in variables)
        {
            Variable var = variables[varName];
            string decInst = "decq";
            if (var.type == DataType.DWORD)
                decInst = "decl";
            else if (var.type == DataType.WORD)
                decInst = "decw";
            else if (var.type == DataType.BYTE)
                decInst = "decb";

            if (var.isGlobal)
            {
                textSection ~= format("    %s %s(%%rip)", decInst, var.dataLabel);
            }
            else
            {
                textSection ~= format("    %s %d(%%rbp)", decInst, var.stackOffset);
            }
        }
    }

    // === OUTPUT ===
    string getAssembly()
    {
        // Otimizações finais
        if (optimizeCode)
        {
            optimizeRedundantMoves();
        }

        string[] result;

        if (dataSection.length > 0)
        {
            result ~= dataSection;
            result ~= "";
        }

        if (bssSection.length > 0)
        {
            result ~= bssSection;
            result ~= "";
        }

        result ~= textSection;

        return result.join("\n");
    }

    void saveToFile(string filename)
    {
        import std.file;

        std.file.write(filename, getAssembly());
    }

    void printAssembly()
    {
        writeln(getAssembly());
    }

    void printVariables()
    {
        writeln("=== VARIÁVEIS DECLARADAS ===");
        foreach (name, var; variables)
        {
            string typeInfo = format("%s%s", var.type, var.isArray ? format("[%d]", var.arraySize)
                    : "");
            if (var.isGlobal)
            {
                writefln("Global: %s %s -> %s", typeInfo, name, var.dataLabel);
            }
            else
            {
                writefln("Local:  %s %s -> rbp%+d", typeInfo, name, var.stackOffset);
            }
        }
    }

    void printStructs()
    {
        writeln("=== STRUCTS DEFINIDAS ===");
        foreach (name, structDef; structs)
        {
            writefln("Struct %s (size: %d bytes):", name, structDef.totalSize);
            foreach (field; structDef.fields)
            {
                writefln("  %s %s @ offset %d", field.type, field.name, field.offset);
            }
        }
    }
}
