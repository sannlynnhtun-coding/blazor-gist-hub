using System.Text.Json;

namespace GistHub.Services;

public sealed record JsonTableField(string Path, string Label);

public static class JsonTableFieldFilter
{
    private static string PropertyPath(string parent, string name) => parent + "/" + name.Replace("~", "~0").Replace("/", "~1");

    public static IReadOnlyList<JsonTableField> Discover(JsonElement root)
    {
        var fields = new Dictionary<string, JsonTableField>(StringComparer.Ordinal);
        void Visit(JsonElement value, string path, string label)
        {
            if (value.ValueKind == JsonValueKind.Object)
                foreach (var property in value.EnumerateObject())
                {
                    var childPath = PropertyPath(path, property.Name);
                    var childLabel = label + "[" + JsonSerializer.Serialize(property.Name) + "]";
                    if (property.Value.ValueKind is JsonValueKind.Object or JsonValueKind.Array)
                        fields.TryAdd(childPath, new(childPath, childLabel));
                    Visit(property.Value, childPath, childLabel);
                }
            else if (value.ValueKind == JsonValueKind.Array)
                foreach (var item in value.EnumerateArray()) Visit(item, path + "/~2", label + "[]");
        }
        Visit(root, "", "$");
        return fields.Values.ToArray();
    }

    public static JsonElement Apply(JsonElement root, IReadOnlySet<string> hidden)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream))
        {
            void Write(JsonElement value, string path)
            {
                if (value.ValueKind == JsonValueKind.Object)
                {
                    writer.WriteStartObject();
                    foreach (var property in value.EnumerateObject())
                    {
                        var childPath = PropertyPath(path, property.Name);
                        if (property.Value.ValueKind is JsonValueKind.Object or JsonValueKind.Array && hidden.Contains(childPath)) continue;
                        writer.WritePropertyName(property.Name);
                        Write(property.Value, childPath);
                    }
                    writer.WriteEndObject();
                }
                else if (value.ValueKind == JsonValueKind.Array)
                {
                    writer.WriteStartArray();
                    foreach (var item in value.EnumerateArray()) Write(item, path + "/~2");
                    writer.WriteEndArray();
                }
                else value.WriteTo(writer);
            }
            Write(root, "");
        }
        using var document = JsonDocument.Parse(stream.ToArray());
        return document.RootElement.Clone();
    }
}
