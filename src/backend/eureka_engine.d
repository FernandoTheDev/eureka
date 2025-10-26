module backend.eureka_engine;
import std.stdio, std.variant, std.conv, std.datetime.stopwatch, std.string;
import core.stdc.stdio;

union EValue
{
    string str; //    string
    long i64; //      int
    double f64; //    float
    bool i1; //       bool
    Value[] array; // array
}

enum Type
{
    String,
    Int,
    Float,
    Bool,
    Array
}

enum OpCode
{
    // Builtin
    PRINT,

    // Math operations {{
    // long
    ADDI,
    SUBI,
    MULI,
    DIVI,
    // double
    ADDF,
    SUBF,
    MULF,
    DIVF,
    // }}

    // Jumps
    JMP,
    JZ,
    JNZ,

    // Comparativos
    LT,
    LTE,
    GT,
    GTE,
    EQ,
    NE,

    // Load/Store stack and heap
    LOADL, // LOAD_LOCAL    = stack
    STOREL, // STORE_LOCAL  = stack
    LOADG, // LOAD_GLOBAL   = heap
    STOREG, // STORE_GLOBAL = heap

    // Arrays
    ARRN, // array new
    ARRG, // array get
    ARRS, // array set
    ARRL, // array length

    // Core
    PUSH,
    POP,
    CALL,
    TAILCALL,
    RET,
    HALT
}

struct Value
{
    Type type;
    EValue value;
}

struct Instruction
{
    OpCode op;
    Value val;
}

struct StackFrame
{
    Value[string] stack;
    long returnAddr;
}

class EurekaEngine
{
    Value[] valueStack; // global stack for temp values
    StackFrame[] frameStack;
    Value[string] heap;
    Instruction[] code;
    long pc; // program counter

    this()
    {
        // frame global -> main
        frameStack ~= StackFrame();
    }

    pragma(inline, true);
    void push(Value v)
    {
        valueStack ~= v;
    }

    pragma(inline, true);
    Value pop()
    {
        if (valueStack.length == 0)
            throw new Exception("RePrinter Virtual Machine Error - Stack underflow");
        auto v = valueStack[$ - 1];
        valueStack.length--;
        return v;
    }

    ref StackFrame currentFrame()
    {
        return frameStack[$ - 1];
    }

    Value makeInt(long i)
    {
        EValue ev;
        ev.i64 = i;
        return Value(Type.Int, ev);
    }

    Value makeStr(string s)
    {
        EValue ev;
        ev.str = s;
        return Value(Type.String, ev);
    }

    Value makeFloat(double f)
    {
        EValue ev;
        ev.f64 = f;
        return Value(Type.Float, ev);
    }

    Value makeBool(bool b)
    {
        EValue ev;
        ev.i1 = b;
        return Value(Type.Bool, ev);
    }

    Value makeArray(Value[] arr)
    {
        EValue ev;
        ev.array = arr;
        return Value(Type.Array, ev);
    }

    void run()
    {
        pc = 0;
        while (pc < code.length)
        {
            Instruction inst = code[pc];

            switch (inst.op)
            {
            case OpCode.PUSH:
                push(inst.val);
                pc++;
                break;

            case OpCode.POP:
                pop();
                pc++;
                break;

            case OpCode.ADDI:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a + b));
                pc++;
                break;

            case OpCode.SUBI:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a - b));
                pc++;
                break;

            case OpCode.MULI:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a * b));
                pc++;
                break;

            case OpCode.DIVI:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a / b));
                pc++;
                break;

            case OpCode.LOADL:
                string name = inst.val.value.str;
                push(currentFrame().stack[name]);
                pc++;
                break;

            case OpCode.STOREL:
                string name = inst.val.value.str;
                currentFrame().stack[name] = pop();
                pc++;
                break;

            case OpCode.LOADG:
                string name = inst.val.value.str;
                push(heap[name]);
                pc++;
                break;

            case OpCode.STOREG:
                string name = inst.val.value.str;
                heap[name] = pop();
                pc++;
                break;

            case OpCode.JMP:
                pc = inst.val.value.i64;
                break;

            case OpCode.JZ:
                long cond = pop().value.i64;
                if (cond == 0)
                    pc = inst.val.value.i64;
                else
                    pc++;
                break;

            case OpCode.JNZ:
                long cond = pop().value.i64;
                if (cond != 0)
                    pc = inst.val.value.i64;
                else
                    pc++;
                break;

            case OpCode.LT:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a < b ? 1 : 0));
                pc++;
                break;

            case OpCode.LTE:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a <= b ? 1 : 0));
                pc++;
                break;

            case OpCode.GT:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a > b ? 1 : 0));
                pc++;
                break;

            case OpCode.GTE:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a >= b ? 1 : 0));
                pc++;
                break;

            case OpCode.EQ:
                long b = pop().value.i64;
                long a = pop().value.i64;
                push(makeInt(a == b ? 1 : 0));
                pc++;
                break;

            case OpCode.ARRN: // array new
                long size = pop().value.i64;
                Value[] arr = new Value[size];
                for (long i = size - 1; i >= 0; i--)
                    arr[i] = pop();
                push(this.makeArray(arr));
                pc++;
                break;

            case OpCode.ARRG: // array get (idx)
                long idx = pop().value.i64;
                Value[] arr = pop().value.array;
                push(arr[idx]);
                pc++;
                break;

            case OpCode.ARRS: // array set -> arr[idx] = n
                Value val = pop();
                long idx = pop().value.i64;
                Value[] arr = pop().value.array;
                arr[idx] = val;
                push(this.makeArray(arr));
                pc++;
                break;

            case OpCode.ARRL: // array length
                Value[] arr = pop().value.array;
                push(this.makeInt(arr.length));
                pc++;
                break;

            case OpCode.CALL:
                StackFrame newFrame; // Cria novo stack frame
                newFrame.returnAddr = pc + 1;
                frameStack ~= newFrame;
                pc = inst.val.value.i64; // Jump para a função
                break;

            case OpCode.RET:
                if (frameStack.length <= 1)
                    throw new Exception("Cannot return from global frame");
                long returnAddr = currentFrame().returnAddr;
                frameStack.length--;
                pc = returnAddr;
                break;

            case OpCode.PRINT:
                Value v = pop();
                final switch (v.type)
                {
                case Type.Int:
                    printf("%lld".toStringz(), v.value.i64);
                    break;
                case Type.Float:
                    printf("%..8f".toStringz(), v.value.f64);
                    break;
                case Type.String:
                    printf(v.value.str.toStringz());
                    break;
                case Type.Bool:
                    printf("%s".toStringz(), v.value.i1 ? "true".toStringz() : "false".toStringz());
                    break;
                case Type.Array:
                    printf("<Array>".toStringz());
                    break;
                }
                pc++;
                break;

            case OpCode.HALT:
                return;
            default:
                throw new Exception(
                    "RePrinter Virtual Machine Error - Invalid OpCode: " ~ to!string(inst.op));
            }
        }
    }
}

class EurekaCodeGen
{
private:
    EurekaEngine engine;
    int[] callPatchIndices; // indices in program that need to be patched
    string[] callPatchNames; // corresponding label names to patch

public:
    Instruction[] program;
    int[string] labels; // label -> address (index in program)

    this(EurekaEngine eng)
    {
        engine = eng;
    }

    EurekaCodeGen emit(Instruction inst)
    {
        program ~= inst;
        return this;
    }

    EurekaCodeGen label(string name)
    {
        if (name in labels)
            throw new Exception("Label already exists: " ~ name);
        labels[name] = cast(int) program.length;
        return this;
    }

    EurekaCodeGen push(Value v)
    {
        emit(Instruction(OpCode.PUSH, v));
        return this;
    }

    EurekaCodeGen pop()
    {
        emit(Instruction(OpCode.POP));
        return this;
    }

    EurekaCodeGen storeLocal(string name)
    {
        emit(Instruction(OpCode.STOREL, engine.makeStr(name)));
        return this;
    }

    EurekaCodeGen loadLocal(string name)
    {
        emit(Instruction(OpCode.LOADL, engine.makeStr(name)));
        return this;
    }

    EurekaCodeGen callLabel(string name)
    {
        auto placeholder = engine.makeInt(-1);
        emit(Instruction(OpCode.CALL, placeholder));
        callPatchIndices ~= cast(int) program.length - 1;
        callPatchNames ~= name;
        return this;
    }

    Instruction[] build()
    {
        // patch calls
        foreach (i, lbl; callPatchNames)
        {
            if (!(lbl in labels))
                throw new Exception("Undefined label referenced: " ~ lbl);
            int targetAddr = labels[lbl];
            int patchIdx = callPatchIndices[i];
            EValue ev;
            ev.i64 = cast(long) targetAddr;
            Value v;
            v.type = Type.Int;
            v.value = ev;
            program[patchIdx].val = v;
        }
        return program;
    }
}
