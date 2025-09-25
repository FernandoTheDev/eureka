pragma(lib, "sqlite3");

import core.stdc.stdio : c_printf = printf;
import std.string : toStringz, fromStringz;
import std.conv : to;
import etc.c.sqlite3;
import frontend.type, runtime.runtime_value, config : LIMIT;

extern (C):

// Estrutura para gerenciar conexões SQLite
struct SQLiteConnection
{
    sqlite3* db;
    bool isOpen;
}

// Array global para gerenciar múltiplas conexões
private SQLiteConnection[16] connections;
private size_t connectionCount = 0;

// Função para abrir conexão com banco
RuntimeValue sqliteOpen(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1 || values[0].type.baseType != BaseType.String)
    {
        throw new Exception("sqliteOpen requires exactly one string argument (filename)");
    }

    if (connectionCount >= connections.length)
    {
        throw new Exception("Maximum number of SQLite connections reached");
    }

    sqlite3* db;
    int rc = sqlite3_open(values[0].value._string.toStringz(), &db);

    if (rc != SQLITE_OK)
    {
        string error = "SQLite error: " ~ sqlite3_errmsg(db).fromStringz().idup;
        sqlite3_close(db);
        throw new Exception(error);
    }

    connections[connectionCount].db = db;
    connections[connectionCount].isOpen = true;

    long connectionId = connectionCount;
    connectionCount++;

    return MK_INT(connectionId);
}

// Função para fechar conexão
RuntimeValue sqliteClose(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1 || values[0].type.baseType != BaseType.Int)
    {
        throw new Exception("sqliteClose requires exactly one integer argument (connection ID)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    sqlite3_close(connections[connId].db);
    connections[connId].isOpen = false;

    return MK_VOID();
}

// Função para executar SQL simples (sem retorno)
RuntimeValue sqliteExec(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 2 ||
        values[0].type.baseType != BaseType.Int ||
        values[1].type.baseType != BaseType.String)
    {
        throw new Exception("sqliteExec requires connection ID (int) and SQL query (string)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    sqlite3* db = connections[connId].db;
    int rc = sqlite3_exec(db, values[1].value._string.toStringz(), null, null, null);

    if (rc != SQLITE_OK)
    {
        string error = "SQLite error: " ~ sqlite3_errmsg(db).fromStringz().idup;
        throw new Exception(error);
    }

    return MK_VOID();
}

// Função simples para contar linhas
RuntimeValue sqliteCount(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 2 ||
        values[0].type.baseType != BaseType.Int ||
        values[1].type.baseType != BaseType.String)
    {
        throw new Exception("sqliteCount requires connection ID (int) and SQL query (string)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    sqlite3* db = connections[connId].db;
    sqlite3_stmt* stmt;

    int rc = sqlite3_prepare_v2(db, values[1].value._string.toStringz(), -1, &stmt, null);
    if (rc != SQLITE_OK)
    {
        string error = "SQLite prepare error: " ~ sqlite3_errmsg(db).fromStringz().idup;
        throw new Exception(error);
    }

    long count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW)
    {
        count++;
        if (count > 10_000)
            break; // Limite de segurança
    }

    sqlite3_finalize(stmt);
    return MK_INT(count);
}

// Função básica para consultar uma única linha/coluna
RuntimeValue sqliteQuerySingle(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 2 ||
        values[0].type.baseType != BaseType.Int ||
        values[1].type.baseType != BaseType.String)
    {
        throw new Exception("sqliteQuerySingle requires connection ID (int) and SQL query (string)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    sqlite3* db = connections[connId].db;
    sqlite3_stmt* stmt;

    int rc = sqlite3_prepare_v2(db, values[1].value._string.toStringz(), -1, &stmt, null);
    if (rc != SQLITE_OK)
    {
        string error = "SQLite prepare error: " ~ sqlite3_errmsg(db).fromStringz().idup;
        throw new Exception(error);
    }

    RuntimeValue result = MK_STRING("NULL");

    if (sqlite3_step(stmt) == SQLITE_ROW)
    {
        int type = sqlite3_column_type(stmt, 0);
        switch (type)
        {
        case SQLITE_INTEGER:
            result = MK_INT(sqlite3_column_int64(stmt, 0));
            break;
        case SQLITE3_TEXT:
            const(char)* text = cast(const(char)*) sqlite3_column_text(stmt, 0);
            if (text)
            {
                result = MK_STRING(text.fromStringz().idup);
            }
            break;
        case SQLITE_FLOAT:
            // Como não temos tipo float, converter para string
            double value = sqlite3_column_double(stmt, 0);
            result = MK_STRING(value.to!string);
            break;
        default:
            result = MK_STRING("NULL");
            break;
        }
    }

    sqlite3_finalize(stmt);
    return result;
}

// Função para preparar statement com parâmetros
RuntimeValue sqlitePrepare(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount < 2 || values[0].type.baseType != BaseType.Int || values[1].type.baseType != BaseType
        .String)
    {
        throw new Exception("sqlitePrepare requires at least connection ID (int) and SQL (string)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    sqlite3* db = connections[connId].db;
    sqlite3_stmt* stmt;

    int rc = sqlite3_prepare_v2(db, values[1].value._string.toStringz(), -1, &stmt, null);
    if (rc != SQLITE_OK)
    {
        string error = "SQLite prepare error: " ~ sqlite3_errmsg(db).fromStringz().idup;
        throw new Exception(error);
    }

    // Bind parameters se fornecidos
    for (size_t i = 2; i < argCount; i++)
    {
        int paramIndex = cast(int)(i - 1); // SQLite usa índices baseados em 1
        RuntimeValue param = values[i];

        switch (param.type.baseType)
        {
        case BaseType.Int:
            sqlite3_bind_int64(stmt, paramIndex, param.value._int);
            break;
        case BaseType.String:
            sqlite3_bind_text(stmt, paramIndex, param.value._string.toStringz(), -1, SQLITE_TRANSIENT);
            break;
        case BaseType.Bool:
            sqlite3_bind_int(stmt, paramIndex, param.value._bool ? 1 : 0);
            break;
        default:
            sqlite3_finalize(stmt);
            throw new Exception("Unsupported parameter type for SQLite binding");
        }
    }

    // Executar o statement
    rc = sqlite3_step(stmt);
    if (rc != SQLITE_DONE && rc != SQLITE_ROW)
    {
        string error = "SQLite execution error: " ~ sqlite3_errmsg(db).fromStringz().idup;
        sqlite3_finalize(stmt);
        throw new Exception(error);
    }

    sqlite3_finalize(stmt);
    return MK_VOID();
}

// Função para obter último ID inserido
RuntimeValue sqliteLastInsertId(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1 || values[0].type.baseType != BaseType.Int)
    {
        throw new Exception(
            "sqliteLastInsertId requires exactly one integer argument (connection ID)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    long lastId = sqlite3_last_insert_rowid(connections[connId].db);
    return MK_INT(lastId);
}

// Função para contar linhas afetadas
RuntimeValue sqliteChanges(RuntimeValue[LIMIT] values, size_t argCount)
{
    if (argCount != 1 || values[0].type.baseType != BaseType.Int)
    {
        throw new Exception("sqliteChanges requires exactly one integer argument (connection ID)");
    }

    long connId = values[0].value._int;
    if (connId < 0 || connId >= connectionCount || !connections[connId].isOpen)
    {
        throw new Exception("Invalid SQLite connection ID");
    }

    int changes = sqlite3_changes(connections[connId].db);
    return MK_INT(changes);
}

RuntimeValue sqliteVersion(RuntimeValue[LIMIT] values, size_t argCount)
{
    const(char)* versionPtr = sqlite3_libversion();
    if (versionPtr is null)
    {
        return MK_STRING("unknown");
    }

    // Criar uma cópia segura da string
    import core.stdc.string : strlen, strncpy;
    import core.stdc.stdlib : malloc, free;

    size_t len = strlen(versionPtr);
    if (len == 0)
    {
        return MK_STRING("unknown");
    }

    // Limitar o tamanho para evitar problemas
    if (len > 100)
        len = 100;

    char[] buffer = new char[len + 1];
    for (size_t i = 0; i < len; i++)
    {
        buffer[i] = versionPtr[i];
    }
    buffer[len] = '\0';

    string version_ = cast(string) buffer[0 .. len];
    return MK_STRING(version_);
}
