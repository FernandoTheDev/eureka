module runtime.context;

import std.stdio;
import runtime.runtime_value;

class Context
{
    long offset = 0;
    RuntimeValue[string][] contexts;
    RuntimeValue[string] functions;

    this()
    {
        contexts ~= (RuntimeValue[string]).init;
    }

    bool checkRuntimeValue(string id, bool isFunc = false)
    {
        if (isFunc)
            return (id in functions) !is null;
        if (offset < 0 || offset >= contexts.length)
            return false;
        return (id in contexts[offset]) !is null;
    }

    ref RuntimeValue lookupRuntimeValue(string id, bool isFunc = false)
    {
        if (isFunc)
        {
            if ((id in functions) is null)
                throw new Exception("Função não encontrada: " ~ id);
            return functions[id];
        }
        if (offset < 0 || offset >= contexts.length)
            throw new Exception("Offset de contexto inválido");
        if ((id in contexts[offset]) is null)
            throw new Exception("Variável não encontrada: " ~ id);
        return contexts[offset][id];
    }

    void addRuntimeValue(string id, RuntimeValue sym)
    {
        if (checkRuntimeValue(id))
            throw new Exception("Símbolo já foi adicionado: " ~ id);
        if (offset < 0 || offset >= contexts.length)
            throw new Exception("Offset de contexto inválido");
        contexts[offset][id] = sym;
    }

    void removeRuntimeValue(string id)
    {
        if (!checkRuntimeValue(id))
            throw new Exception("Símbolo não existe: " ~ id);
        if (offset < 0 || offset >= contexts.length)
            throw new Exception("Offset de contexto inválido");
        contexts[offset].remove(id);
    }

    void updateRuntimeValue(string id, RuntimeValue value)
    {
        if (!checkRuntimeValue(id))
            throw new Exception("Símbolo não existe: " ~ id);
        if (offset < 0 || offset >= contexts.length)
            throw new Exception("Offset de contexto inválido");
        contexts[offset][id] = value;
    }

    void addFunc(string id, RuntimeValue sym)
    {
        if (checkRuntimeValue(id, true))
            throw new Exception("Função já foi adicionada: " ~ id);
        functions[id] = sym;
    }

    void pushContext()
    {
        contexts ~= (RuntimeValue[string]).init;
        offset = cast(long) contexts.length - 1;
    }

    void popContext()
    {
        if (contexts.length <= 1)
            throw new Exception("Não é possível remover o contexto raiz");
        contexts = contexts[0 .. $ - 1];
        if (offset >= contexts.length)
            offset = cast(long) contexts.length - 1;
    }

    void nextContext()
    {
        if (offset + 1 >= contexts.length)
            throw new Exception("Não há próximo contexto disponível");
        offset += 1;
    }

    void previousContext()
    {
        if (offset - 1 < 0)
            throw new Exception("Erro no stack de contextos");
        offset -= 1;
    }
}
