using System.Reflection;
using GistHub.Models;
using GistHub.Services;
using Microsoft.AspNetCore.Components;

var login = new GistHub.Pages.Login();
SetProperty(login, "Storage", new FakeStorageService());
SetProperty(login, "AppState", new AppState());
SetProperty(login, "Navigation", new FakeNavigationManager());
SetProperty(login, "Github", new ThrowingGithubService());
SetProperty(login, "ProfileName", "Test profile");
SetProperty(login, "Token", "test-token");

Exception? submitError = null;
try
{
    await InvokeAsync(login, "HandleLogin");
}
catch (Exception ex)
{
    submitError = ex;
}

Assert(submitError is null, "Login submission should handle service errors instead of throwing.");
Assert(!GetProperty<bool>(login, "IsLoading"), "Login must leave the loading state after an error.");
Assert(!string.IsNullOrWhiteSpace(GetProperty<string>(login, "ErrorMessage")), "Login must expose an error message for the toast.");

Console.WriteLine("PASS: login errors stop loading and expose a toast message.");

var bookmarkGists = new List<LocalGist>
{
    new() { Id = "newer", IsBookmarked = true, BookmarkOrder = 2, UpdatedAt = new DateTime(2026, 1, 2) },
    new() { Id = "first", IsBookmarked = true, BookmarkOrder = 1, UpdatedAt = new DateTime(2026, 1, 1) },
    new() { Id = "ignored", IsBookmarked = false, UpdatedAt = new DateTime(2026, 1, 3) }
};
var bookmarkJson = BookmarkBackupSerializer.CreateJson(
    bookmarkGists,
    "ExampleUser",
    new DateTimeOffset(2026, 1, 3, 4, 5, 6, TimeSpan.Zero));

Assert(
    BookmarkBackupSerializer.TryParse(bookmarkJson, "exampleuser", out var bookmarkBackup, out var bookmarkError),
    $"Generated bookmark JSON should parse: {bookmarkError}");
Assert(bookmarkBackup!.Bookmarks!.Count == 2, "Only bookmarked gists should be exported.");
Assert(bookmarkBackup.Bookmarks[0].GistId == "first", "Bookmark order should be preserved in the backup.");
Assert(
    !BookmarkBackupSerializer.TryParse(bookmarkJson, "another-user", out _, out var accountError) && accountError.Contains("belongs to"),
    "A bookmark backup from another account must be rejected.");

Console.WriteLine("PASS: bookmark backups preserve order and enforce account scope.");

var searchService = new GistSearchService();
var searchGists = new List<LocalGist>
{
    new()
    {
        Id = "description-match",
        Description = "Needle deployment helper",
        Tags = ["ops"],
        Files = new Dictionary<string, GistFile>
        {
            ["deploy.ps1"] = new() { Filename = "deploy.ps1", Content = "Write-Host 'ready'" }
        },
        IsBookmarked = true,
        UpdatedAt = new DateTime(2026, 1, 3)
    },
    new()
    {
        Id = "content-match",
        Description = "General utilities",
        Tags = ["reference"],
        Files = new Dictionary<string, GistFile>
        {
            ["first.cs"] = new() { Filename = "first.cs", Content = "var needle = FindValue();" },
            ["second.cs"] = new() { Filename = "second.cs", Content = "Console.WriteLine(NEEDLE);" }
        },
        UpdatedAt = new DateTime(2026, 1, 4)
    },
    new()
    {
        Id = "filename-and-tag-match",
        Description = "Handy command",
        Tags = ["NeedleTag"],
        Files = new Dictionary<string, GistFile>
        {
            ["needle-script.sh"] = new() { Filename = "needle-script.sh", Content = "echo ready" }
        },
        UpdatedAt = new DateTime(2026, 1, 2)
    }
};

var needleResults = searchService.Search(searchGists, "NEEDLE", bookmarksOnly: false);
Assert(needleResults.TotalCount == 3, "Search should match descriptions, tags, filenames, and content without case sensitivity.");
Assert(needleResults.Results.Count(result => result.GistId == "content-match") == 1, "A gist with multiple matching files must appear once.");
Assert(needleResults.Results[0].GistId == "description-match", "Description matches should rank ahead of tag, filename, and content matches.");
Assert(needleResults.Results[0].Snippet.Contains("Needle deployment", StringComparison.OrdinalIgnoreCase), "Description matches should show description context rather than unrelated file content.");
Assert(needleResults.Results.First(result => result.GistId == "content-match").Snippet.Contains("needle", StringComparison.OrdinalIgnoreCase), "Content matches should include the matching text in their snippet.");

var exactTagResult = searchService.Search(
    [
        new LocalGist { Id = "exact-tag", Description = "Reference", Tags = ["needle"], UpdatedAt = new DateTime(2026, 1, 1) },
        new LocalGist { Id = "filename", Description = "Reference", Files = new() { ["needle"] = new() { Filename = "needle" } }, UpdatedAt = new DateTime(2026, 1, 2) }
    ],
    "needle",
    bookmarksOnly: false);
Assert(exactTagResult.Results[0].GistId == "exact-tag", "An exact tag match should rank ahead of a filename match even when the filename is newer.");

var tiedDescriptionResults = searchService.Search(
    [
        new LocalGist { Id = "older", Description = "needle note", UpdatedAt = new DateTime(2026, 1, 1) },
        new LocalGist { Id = "newer", Description = "needle note", UpdatedAt = new DateTime(2026, 1, 2) }
    ],
    "needle",
    bookmarksOnly: false);
Assert(tiedDescriptionResults.Results[0].GistId == "newer", "Equally relevant matches should sort by the newest update time.");

var boundaryContent = $"{new string('a', 100)}needle{new string('b', 150)}";
var boundaryResult = searchService.Search(
    [new LocalGist { Id = "boundary", Description = "Reference", Files = new() { ["long.txt"] = new() { Filename = "long.txt", Content = boundaryContent } } }],
    "needle",
    bookmarksOnly: false).Results[0];
Assert(boundaryResult.Snippet.StartsWith("...", StringComparison.Ordinal) && boundaryResult.Snippet.EndsWith("...", StringComparison.Ordinal), "Long content snippets should show both clipped boundaries.");
Assert(boundaryResult.Snippet.Contains("needle", StringComparison.OrdinalIgnoreCase), "A clipped content snippet must keep the matched term in context.");

var bookmarkedResults = searchService.Search(searchGists, "needle", bookmarksOnly: true);
Assert(bookmarkedResults.TotalCount == 1 && bookmarkedResults.Results[0].GistId == "description-match", "Bookmark filtering should exclude unbookmarked search matches.");

var multiWordResults = searchService.Search(searchGists, "utilities needle", bookmarksOnly: false);
Assert(multiWordResults.TotalCount == 1 && multiWordResults.Results[0].GistId == "content-match", "Every word in a multi-word query should match somewhere in the same gist.");

var limitedResults = searchService.Search(searchGists, "needle", bookmarksOnly: false, limit: 2);
Assert(limitedResults.TotalCount == 3 && limitedResults.Results.Count == 2, "Search should retain the total count while limiting rendered results.");

Console.WriteLine("PASS: local gist search ranks fields, groups by gist, filters bookmarks, and returns safe context snippets.");

static void SetProperty(object target, string name, object value)
{
    var property = target.GetType().GetProperty(name, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
        ?? throw new InvalidOperationException($"Property '{name}' was not found.");
    property.SetValue(target, value);
}

static T GetProperty<T>(object target, string name)
{
    var property = target.GetType().GetProperty(name, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
        ?? throw new InvalidOperationException($"Property '{name}' was not found.");
    return (T)property.GetValue(target)!;
}

static async Task InvokeAsync(object target, string name)
{
    var method = target.GetType().GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic)
        ?? throw new InvalidOperationException($"Method '{name}' was not found.");

    try
    {
        await (Task)method.Invoke(target, null)!;
    }
    catch (TargetInvocationException ex) when (ex.InnerException is not null)
    {
        throw ex.InnerException;
    }
}

static void Assert(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}

sealed class ThrowingGithubService : IGithubService
{
    public GithubApiError? LastError => null;

    public Task<GithubUser?> GetUserInfoAsync(string token)
        => throw new HttpRequestException("GitHub is unreachable.");

    public Task<List<LocalGist>> GetPublicGistsAsync(string? token = null) => throw new NotSupportedException();
    public Task<List<LocalGist>> GetUserGistsAsync(string token) => throw new NotSupportedException();
    public Task<bool> DeleteGistAsync(string gistId, string token) => throw new NotSupportedException();
    public Task<LocalGist?> CreateGistAsync(string description, bool isPublic, Dictionary<string, GistFile> files, string token) => throw new NotSupportedException();
    public Task<LocalGist?> UpdateGistAsync(string id, string description, Dictionary<string, GistFile> files, string token) => throw new NotSupportedException();
    public Task<LocalGist?> GetGistByIdAsync(string id, string? token = null) => throw new NotSupportedException();
    public Task<List<LocalGist>> GetUserPublicGistsAsync(string username, string? token = null) => throw new NotSupportedException();
}

sealed class FakeStorageService : IStorageService
{
    public Task InitAsync() => Task.CompletedTask;
    public Task SaveProfileAsync(GistProfile profile) => Task.CompletedTask;
    public Task<List<GistProfile>> GetProfilesAsync() => Task.FromResult(new List<GistProfile>());
    public Task DeleteProfileAsync(string id) => Task.CompletedTask;
    public Task SaveGistAsync(LocalGist gist) => Task.CompletedTask;
    public Task<List<LocalGist>> GetLocalGistsAsync() => Task.FromResult(new List<LocalGist>());
    public Task<List<LocalGist>> GetLocalGistsAsync(string username) => Task.FromResult(new List<LocalGist>());
    public Task DeleteGistAsync(string id) => Task.CompletedTask;
    public Task SaveGroupAsync(GistGroup group) => Task.CompletedTask;
    public Task<List<GistGroup>> GetGroupsAsync() => Task.FromResult(new List<GistGroup>());
    public Task DeleteGroupAsync(string id) => Task.CompletedTask;
}

sealed class FakeNavigationManager : NavigationManager
{
    public FakeNavigationManager() => Initialize("http://localhost/", "http://localhost/login");

    protected override void NavigateToCore(string uri, NavigationOptions options)
    {
    }
}
