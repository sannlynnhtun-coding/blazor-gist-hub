using System.Net;
using System.Text;

namespace GistHub.Services;

public static class JsonSyntaxHighlighter
{
    public static string Highlight(string? json)
    {
        if (string.IsNullOrEmpty(json))
        {
            return string.Empty;
        }

        var highlighted = new StringBuilder(json.Length + (json.Length / 2));
        var index = 0;

        while (index < json.Length)
        {
            var current = json[index];

            if (current == '"')
            {
                var start = index++;
                var isEscaped = false;

                while (index < json.Length)
                {
                    var character = json[index++];
                    if (character == '"' && !isEscaped)
                    {
                        break;
                    }

                    if (character == '\\')
                    {
                        isEscaped = !isEscaped;
                    }
                    else
                    {
                        isEscaped = false;
                    }
                }

                var lookAhead = index;
                while (lookAhead < json.Length && char.IsWhiteSpace(json[lookAhead]))
                {
                    lookAhead++;
                }

                var tokenClass = lookAhead < json.Length && json[lookAhead] == ':'
                    ? "json-token-field"
                    : "json-token-string";

                AppendToken(highlighted, tokenClass, json[start..index]);
                continue;
            }

            if (current == '-' || char.IsDigit(current))
            {
                var start = index++;
                while (index < json.Length && IsNumberCharacter(json[index]))
                {
                    index++;
                }

                AppendToken(highlighted, "json-token-number", json[start..index]);
                continue;
            }

            if (StartsWithToken(json, index, "true") || StartsWithToken(json, index, "false"))
            {
                var length = json[index] == 't' ? 4 : 5;
                AppendToken(highlighted, "json-token-boolean", json.Substring(index, length));
                index += length;
                continue;
            }

            if (StartsWithToken(json, index, "null"))
            {
                AppendToken(highlighted, "json-token-null", "null");
                index += 4;
                continue;
            }

            if (current is '{' or '}' or '[' or ']' or ':' or ',')
            {
                AppendToken(highlighted, "json-token-punctuation", current.ToString());
                index++;
                continue;
            }

            highlighted.Append(WebUtility.HtmlEncode(current.ToString()));
            index++;
        }

        return highlighted.ToString();
    }

    private static bool IsNumberCharacter(char character)
        => char.IsDigit(character) || character is '-' or '+' or '.' or 'e' or 'E';

    private static bool StartsWithToken(string json, int index, string token)
        => index + token.Length <= json.Length &&
           json.AsSpan(index, token.Length).SequenceEqual(token.AsSpan());

    private static void AppendToken(StringBuilder highlighted, string tokenClass, string token)
    {
        highlighted
            .Append("<span class=\"")
            .Append(tokenClass)
            .Append("\">")
            .Append(WebUtility.HtmlEncode(token))
            .Append("</span>");
    }
}
