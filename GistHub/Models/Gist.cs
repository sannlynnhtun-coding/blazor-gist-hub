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
    public List<string> CollectionNames { get; set; } = new();
    // Legacy single-collection field kept for backward compatibility.
    public string? CollectionName { get; set; }
    public bool IsSynced { get; set; } = true;
    public bool IsBookmarked { get; set; } = false;
    // A local-only rank used when displaying bookmarked gists. Zero means no custom position yet.
    public int BookmarkOrder { get; set; }

    [JsonPropertyName("owner")]
    public GistOwner? Owner { get; set; }
}

public class GistGroup
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}

public class GistOwner
{
    [JsonPropertyName("login")]
    public string Login { get; set; } = string.Empty;

    [JsonPropertyName("avatar_url")]
    public string AvatarUrl { get; set; } = string.Empty;

    [JsonPropertyName("html_url")]
    public string HtmlUrl { get; set; } = string.Empty;
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
