using System.Text;

namespace GistHub.Services;

public static class Base64Converter
{
    private static readonly Encoding Utf8 = new UTF8Encoding(false, true);
    private static readonly Encoding Latin1 = Encoding.GetEncoding("iso-8859-1", EncoderFallback.ExceptionFallback, DecoderFallback.ExceptionFallback);

    public static string ConvertText(string input, bool decode, bool eachLine = false, bool urlSafe = false, bool latin1 = false)
    {
        var encoding = latin1 ? Latin1 : Utf8;
        string ConvertLine(string value) => decode
            ? encoding.GetString(DecodeBytes(value, urlSafe))
            : EncodeBytes(encoding.GetBytes(value), urlSafe);

        return eachLine
            ? string.Join("\n", input.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n').Select(ConvertLine))
            : ConvertLine(input);
    }

    public static string EncodeBytes(byte[] bytes, bool urlSafe = false)
    {
        var result = Convert.ToBase64String(bytes);
        return urlSafe ? result.Replace('+', '-').Replace('/', '_').TrimEnd('=') : result;
    }

    public static byte[] DecodeBytes(string input, bool urlSafe = false)
    {
        var value = string.Concat(input.Where(c => !char.IsWhiteSpace(c)));
        if (urlSafe)
        {
            if (value.Contains('+') || value.Contains('/'))
                throw new FormatException("Use the URL-safe alphabet (- and _) or turn off URL-safe mode.");
            value = value.Replace('-', '+').Replace('_', '/');
            if (!value.Contains('=') && value.Length % 4 is 2 or 3)
                value = value.PadRight(value.Length + 4 - value.Length % 4, '=');
        }
        return Convert.FromBase64String(value);
    }
}
