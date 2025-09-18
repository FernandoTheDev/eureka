module runtime.context;

import std.stdio;
import runtime.runtime_value;

class Context
{
    ulong offset = -1;
    RuntimeValue[string][] contexts = null;
    RuntimeValue[string] functions;
    Context* parent;

    bool checkRuntimeValue(string id, bool isFunc = false)
    {
        if (isFunc)
            return (id in functions) !is null;
        return (id in contexts[offset]) !is null;
    }

    ref RuntimeValue lookupRuntimeValue(string id, bool isFunc = false)
    {
        if (isFunc)
            return functions[id];
        return contexts[offset][id];
    }

    void addRuntimeValue(string id, RuntimeValue sym)
    {
        if (checkRuntimeValue(id))
            throw new Exception("Simbolo já foi adicionado.");
        contexts[offset][id] = sym;
    }

    void addFunc(string id, RuntimeValue sym)
    {
        if (checkRuntimeValue(id, true))
            throw new Exception("Função já foi adicionada.");
        functions[id] = sym;
    }

    void pushContext()
    {
        contexts ~= (RuntimeValue[string]).init;
    }

    void popContext()
    {
        contexts = contexts[0 .. $ - 1];
    }

    void nextContext()
    {
        offset += 1;
    }

    void previousContext()
    {
        if ((offset - 1) < 0)
            throw new Exception("Error context stack.");
        offset -= 1;
    }
}
