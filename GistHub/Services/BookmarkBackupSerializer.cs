using System.Text.Json;
using System.Text.Json.Serialization;
using GistHub.Models;

namespace GistHub.Services;

public static class BookmarkBackupSerializer
{
    public const string Format = "gisthub-bookmarks";
    public const int CurrentVersion = 1;

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    public static string CreateJson(
        IEnumerable<LocalGist> gists,
        string githubUsername,
        DateTimeOffset? exportedAtUtc = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(githubUsername);

        var bookmarks = gists
            .Where(gist => gist.IsBookmarked && !string.IsNullOrWhiteSpace(gist.Id))
            .OrderBy(gist => gist.BookmarkOrder > 0 ? 0 : 1)
            .ThenBy(gist => gist.BookmarkOrder > 0 ? gist.BookmarkOrder : int.MaxValue)
            .ThenByDescending(gist => gist.UpdatedAt)
            .Select((gist, index) => new BookmarkBackupItem
            {
                GistId = gist.Id,
                Order = index + 1
            })
            .ToList();

        var backup = new BookmarkBackupDocument
        {
            Format = Format,
            Version = CurrentVersion,
            GithubUsername = githubUsername.Trim(),
            ExportedAtUtc = exportedAtUtc ?? DateTimeOffset.UtcNow,
            Bookmarks = bookmarks
        };

        return JsonSerializer.Serialize(backup, JsonOptions);
    }

    public static bool TryParse(
        string json,
        string githubUsername,
        out BookmarkBackupDocument? backup,
        out string validationError)
    {
        backup = null;
        validationError = string.Empty;

        if (string.IsNullOrWhiteSpace(json))
        {
            validationError = "The bookmark backup is empty.";
            return false;
        }

        BookmarkBackupDocument? parsed;
        try
        {
            parsed = JsonSerializer.Deserialize<BookmarkBackupDocument>(json, JsonOptions);
        }
        catch (JsonException ex)
        {
            validationError = $"Invalid bookmark JSON: {ex.Message}";
            return false;
        }

        if (parsed is null || !string.Equals(parsed.Format, Format, StringComparison.Ordinal))
        {
            validationError = "This file is not a GistHub bookmark backup.";
            return false;
        }

        if (parsed.Version != CurrentVersion)
        {
            validationError = $"Bookmark backup version {parsed.Version} is not supported.";
            return false;
        }

        if (!string.Equals(parsed.GithubUsername?.Trim(), githubUsername.Trim(), StringComparison.OrdinalIgnoreCase))
        {
            validationError = $"This backup belongs to @{parsed.GithubUsername?.Trim() ?? "unknown"}, not @{githubUsername.Trim()}.";
            return false;
        }

        if (parsed.Bookmarks is null)
        {
            validationError = "The bookmark list is missing.";
            return false;
        }

        if (parsed.Bookmarks.Any(item => string.IsNullOrWhiteSpace(item.GistId) || item.Order <= 0))
        {
            validationError = "Every bookmark must have a gistId and a positive order.";
            return false;
        }

        if (parsed.Bookmarks
            .GroupBy(item => item.GistId.Trim(), StringComparer.OrdinalIgnoreCase)
            .Any(group => group.Count() > 1))
        {
            validationError = "The bookmark backup contains duplicate gist IDs.";
            return false;
        }

        backup = parsed;
        return true;
    }
}

public sealed class BookmarkBackupDocument
{
    public string Format { get; set; } = string.Empty;
    public int Version { get; set; }
    public string GithubUsername { get; set; } = string.Empty;
    public DateTimeOffset ExportedAtUtc { get; set; }
    public List<BookmarkBackupItem>? Bookmarks { get; set; }
}

public sealed class BookmarkBackupItem
{
    [JsonPropertyName("gistId")]
    public string GistId { get; set; } = string.Empty;

    public int Order { get; set; }
}
