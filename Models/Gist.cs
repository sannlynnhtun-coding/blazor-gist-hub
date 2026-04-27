using System.Text.Json.Serialization;

namespace GistHub.Models;

public class GistProfile
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = string.Empty;
    public string AccessToken { get; set; } = string.Empty;
    public string GithubUsername { get; set; } = string.Empty;
    public string Bio { get; set; } = string.Empty;
}

public class LocalGist
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("files")]
    public Dictionary<string, GistFile> Files { get; set; } = new();

    [JsonPropertyName("public")]
    public bool Public { get; set; }

    [JsonPropertyName("html_url")]
    public string HtmlUrl { get; set; } = string.Empty;

    [JsonPropertyName("created_at")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("updated_at")]
    public DateTime UpdatedAt { get; set; }

    public List<string> Tags { get; set; } = new();
    public string? CollectionName { get; set; }
    public bool IsSynced { get; set; } = true;
    public bool IsBookmarked { get; set; } = false;
}

public class GistFile
{
    [JsonPropertyName("filename")]
    public string Filename { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("language")]
    public string Language { get; set; } = string.Empty;

    [JsonPropertyName("raw_url")]
    public string RawUrl { get; set; } = string.Empty;

    [JsonPropertyName("content")]
    public string? Content { get; set; }
}
