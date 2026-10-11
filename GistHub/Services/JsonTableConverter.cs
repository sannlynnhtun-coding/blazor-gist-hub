using System.Net;
using System.Text.Json;

namespace GistHub.Services;

public sealed record JsonTableData(IReadOnlyList<string> Columns, IReadOnlyList<IReadOnlyList<JsonElement>> Rows);

public static class JsonTableConverter
{
    public static JsonTableData Create(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Array)
        {
            var items = value.EnumerateArray().ToArray();
            if (items.Length > 0 && items.All(item => item.ValueKind == JsonValueKind.Object))
            {
                var columns = items.SelectMany(item => item.EnumerateObject().Select(property => property.Name)).Distinct(StringComparer.Ordinal).ToArray();
                return new(columns, items.Select(item => (IReadOnlyList<JsonElement>)columns.Select(column => item.TryGetProperty(column, out var cell) ? cell : default).ToArray()).ToArray());
            }
            return new(["Index", "Value"], items.Select((item, index) => (IReadOnlyList<JsonElement>)new[] { JsonSerializer.SerializeToElement(index), item }).ToArray());
        }
        if (value.ValueKind == JsonValueKind.Object)
            return new(["Key", "Value"], value.EnumerateObject().Select(property => (IReadOnlyList<JsonElement>)new[] { JsonSerializer.SerializeToElement(property.Name), property.Value }).ToArray());
        return new(["Value"], [new[] { value }]);
    }

    public static string Text(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Undefined => "",
        JsonValueKind.String => value.GetString() ?? "",
        _ => value.GetRawText()
    };

    public static string Csv(JsonTableData table)
    {
        // Prevent spreadsheet applications from interpreting user data as formulas.
        static string Quote(string text)
        {
            if (text.TrimStart().StartsWith('=') || text.TrimStart().StartsWith('+') || text.TrimStart().StartsWith('-') || text.TrimStart().StartsWith('@') || text.StartsWith('\t') || text.StartsWith('\r')) text = "'" + text;
            return "\"" + text.Replace("\"", "\"\"") + "\"";
        }
        return string.Join("\r\n", new[] { string.Join(",", table.Columns.Select(Quote)) }.Concat(table.Rows.Select(row => string.Join(",", row.Select(cell => Quote(Text(cell)))))));
    }

    public static string Html(JsonElement value)
    {
        var table = Create(value);
        string Cell(JsonElement cell) => cell.ValueKind is JsonValueKind.Object or JsonValueKind.Array ? Html(cell) : WebUtility.HtmlEncode(Text(cell));
        return "<table><thead><tr>" + string.Concat(table.Columns.Select(column => "<th>" + WebUtility.HtmlEncode(column) + "</th>")) + "</tr></thead><tbody>" + string.Concat(table.Rows.Select(row => "<tr>" + string.Concat(row.Select(cell => "<td>" + Cell(cell) + "</td>")) + "</tr>")) + "</tbody></table>";
    }
}
