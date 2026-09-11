using System.Text.Encodings.Web;
using System.Text.Json;

namespace GistHub.Services;

public sealed record JsonNormalizationResult(
    bool Success,
    string Output,
    string Message,
    string Summary);

public static class JsonTextNormalizer
{
    private static readonly JsonDocumentOptions DocumentOptions = new()
    {
        AllowTrailingCommas = true,
        CommentHandling = JsonCommentHandling.Skip
    };

    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        WriteIndented = true
    };

    public static JsonNormalizationResult Normalize(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return new(false, string.Empty, "Paste JSON on the left to see the deserialized object.", string.Empty);
        }

        var candidate = input.Trim();
        JsonException? lastError = null;

        // Logs and API clients often add one or more string-escaping layers.
        // Peel those layers until the underlying JSON value can be parsed.
        for (var attempt = 0; attempt < 8; attempt++)
        {
            try
            {
                using var document = JsonDocument.Parse(candidate, DocumentOptions);
                var root = document.RootElement;

                if (root.ValueKind == JsonValueKind.String)
                {
                    var decoded = root.GetString()?.Trim() ?? string.Empty;
                    if (LooksLikeNestedJson(decoded))
                    {
                        candidate = decoded;
                        continue;
                    }
                }

                return new(
                    true,
                    JsonSerializer.Serialize(root, SerializerOptions),
                    "Parsed successfully.",
                    Describe(root));
            }
            catch (JsonException exception)
            {
                lastError = exception;
            }

            // Some tools copy a string literal with its first and final quotes,
            // but with too many backslashes for it to remain valid JSON.
            if (HasOuterQuotes(candidate))
            {
                candidate = candidate[1..^1].Trim();
                continue;
            }

            if (TryDecodeUnwrappedJsonString(candidate, out var decodedCandidate))
            {
                candidate = decodedCandidate;
                continue;
            }

            // Accommodate source-code/log representations such as
            // {\\"key\\":\\"value\\"} by removing a single escaping layer.
            if (candidate.Contains("\\\\\"", StringComparison.Ordinal))
            {
                candidate = candidate.Replace("\\\\", "\\", StringComparison.Ordinal);
                continue;
            }

            break;
        }

        var line = (lastError?.LineNumber ?? 0) + 1;
        var column = (lastError?.BytePositionInLine ?? 0) + 1;
        return new(
            false,
            string.Empty,
            $"Invalid JSON near line {line}, column {column}. Check missing commas, quotes, or braces.",
            string.Empty);
    }

    private static bool TryDecodeUnwrappedJsonString(string candidate, out string decoded)
    {
        decoded = string.Empty;
        if (!LooksLikeNestedJson(candidate) || !candidate.Contains('\\'))
        {
            return false;
        }

        try
        {
            decoded = JsonSerializer.Deserialize<string>($"\"{candidate}\"")?.Trim() ?? string.Empty;
            return decoded.Length > 0;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static bool LooksLikeNestedJson(string value)
    {
        var trimmed = value.TrimStart();
        return trimmed.StartsWith('{') || trimmed.StartsWith('[');
    }

    private static bool HasOuterQuotes(string value)
        => value.Length >= 2 && value[0] == '"' && value[^1] == '"';

    private static string Describe(JsonElement root)
        => root.ValueKind switch
        {
            JsonValueKind.Object => $"Object · {root.EnumerateObject().Count()} properties",
            JsonValueKind.Array => $"Array · {root.GetArrayLength()} items",
            JsonValueKind.String => "JSON string",
            JsonValueKind.Number => "JSON number",
            JsonValueKind.True or JsonValueKind.False => "JSON boolean",
            JsonValueKind.Null => "JSON null",
            _ => "Valid JSON"
        };
}
