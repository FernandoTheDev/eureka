module error;

import std.stdio, std.file, std.string, std.conv, std.algorithm;
import frontend.lexer.token : Token, TokenKind, Loc;

string strRepeat(string s, ulong times)
{
    string result;
    foreach (_; 0 .. times)
        result ~= s;
    return result;
}

enum DiagnosticSeverity : string
{
    WARNING = "warning",
    ERROR = "error",
}

struct DiagnosticOptions
{
    bool showSuggestions = true;
    bool onlyWarnings = false;
    bool highlightTokens = true;
}

struct Suggestion
{
    string message;
    string replacement;
}

struct Diagnostic
{
    string message;
    Loc loc;
    Suggestion[] suggestions;
    TokenKind tkType;
    DiagnosticSeverity severity;
}

class DiagnosticError
{
private:
    Diagnostic[] diagnostics;
    DiagnosticOptions options;

public:
    this(DiagnosticOptions options = DiagnosticOptions())
    {
        this.options = options;
    }

    Suggestion makeSuggestion(string message, string replacement = "")
    {
        return Suggestion(message, replacement);
    }

    void addError(Diagnostic d)
    {
        d.severity = DiagnosticSeverity.ERROR;
        this.diagnostics ~= d;
    }

    void addWarning(Diagnostic d)
    {
        d.severity = DiagnosticSeverity.WARNING;
        this.diagnostics ~= d;
    }

    string formatDiagnostic(const Diagnostic diagnostic)
    {
        const loc = diagnostic.loc;
        const message = diagnostic.message;
        const severity = diagnostic.severity;
        const suggestions = diagnostic.suggestions;

        string severityText = severity == DiagnosticSeverity.ERROR ? "error" : "warning";

        string output = "";
        output ~= severityText ~ ": " ~ message ~ "\n";
        output ~= "  → " ~ loc.filename ~ ":" ~ to!string(loc.line) ~ "\n\n";

        string lineNum = to!string(loc.line);
        output ~= format("%6s | %s\n", lineNum, getLineText(to!ulong(lineNum), loc.filename));

        string padding = "       | ";
        string prefixSpaces = strRepeat(" ", loc.start);
        int underlineLength = cast(int)(loc.end - loc.start);
        if (underlineLength < 1)
            underlineLength = 1;
        string underline = strRepeat("^", underlineLength);

        output ~= padding ~ prefixSpaces ~ underline ~ "\n";

        // Suggestions
        if (this.options.showSuggestions && suggestions.length > 0)
        {
            output ~= "\n";
            foreach (suggestion; suggestions)
            {
                output ~= "Sugestão: " ~ suggestion.message ~ "\n";
                if (suggestion.replacement.length > 0)
                {
                    output ~= "Correção: " ~ suggestion.replacement ~ "\n";
                }
            }
        }

        return output;
    }

    string formatDiagnostics()
    {
        if (this.diagnostics.length == 0)
        {
            return "";
        }

        string[] formattedDiagnostics;
        foreach (diagnostic; this.diagnostics)
        {
            formattedDiagnostics ~= formatDiagnostic(diagnostic);
        }

        return formattedDiagnostics.join("\n\n");
    }

    void printDiagnostics()
    {
        string output = formatDiagnostics();
        string summary = getSummary();
        if (output.length > 0)
        {
            writeln(output);
        }
        writeln(summary);
    }

    bool hasErrors()
    {
        return this.diagnostics.any!(d => d.severity == DiagnosticSeverity.ERROR);
    }

    bool hasWarnings()
    {
        return this.diagnostics.any!(d => d.severity == DiagnosticSeverity.WARNING);
    }

    int getErrorCount()
    {
        return cast(int) this.diagnostics.count!(d => d.severity == DiagnosticSeverity.ERROR);
    }

    int getWarningCount()
    {
        return cast(int) this.diagnostics.count!(d => d.severity == DiagnosticSeverity.WARNING);
    }

    void clear()
    {
        this.diagnostics = [];
    }

    void updateOptions(DiagnosticOptions newOptions)
    {
        this.options = newOptions;
    }

    string getSummary()
    {
        int errorCount = getErrorCount();
        int warningCount = getWarningCount();

        if (errorCount == 0 && warningCount == 0)
        {
            return "Nenhum problema encontrado!";
        }

        string errorText = errorCount == 1 ? "erro" : "erros";
        string warningText = warningCount == 1 ? "aviso" : "avisos";

        string summaryPrefix = "Encontrado: ";
        string[] parts;

        if (errorCount > 0)
        {
            parts ~= to!string(errorCount) ~ " " ~ errorText;
        }

        if (warningCount > 0)
        {
            parts ~= to!string(warningCount) ~ " " ~ warningText;
        }

        return summaryPrefix ~ parts.join(" e ");
    }

    string getLineText(ulong line, string file)
    {
        // TODO: validar se o offset (line - 1) é válido
        string[] data = readText(file).split("\n");
        return data[line - 1];
    }
}
