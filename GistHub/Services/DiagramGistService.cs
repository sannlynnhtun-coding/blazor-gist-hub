using GistHub.Models;
using System.Text.RegularExpressions;

namespace GistHub.Services;

public sealed class DiagramGistService(IGithubService github)
{
    public static string ParseId(string value)
    {
        value = value.Trim();
        if (Uri.TryCreate(value, UriKind.Absolute, out var uri))
        {
            if (uri.Scheme != "https" || uri.Host != "gist.github.com") throw new InvalidOperationException("Use a gist.github.com URL or a Gist ID.");
            value = uri.AbsolutePath.Trim('/').Split('/').Last();
        }
        if (!Regex.IsMatch(value, "\\A[0-9a-fA-F]{5,40}\\z")) throw new InvalidOperationException("Enter a valid Gist ID or URL.");
        return value;
    }

    public async Task<LocalGist> LoadAsync(string id, string? token)
        => await github.GetGistByIdAsync(ParseId(id), token)
            ?? throw new InvalidOperationException(github.LastError?.Message ?? "Could not load this Gist. Check access and try again.");

    public static string ReadSource(LocalGist gist, string filename)
    {
        if (!gist.Files.TryGetValue(filename, out var file) || file.Truncated || string.IsNullOrWhiteSpace(file.Content))
            throw new InvalidOperationException("The full diagram source is unavailable. Download the original .drawio file and import it locally.");
        return file.Content;
    }

    public async Task<LocalGist> SaveAsync(DiagramDocument doc, GistProfile profile, string filename, bool isPublic, bool createNew)
    {
        if (doc.Owner != "github:" + profile.GithubUsername.Trim().ToLowerInvariant())
            throw new InvalidOperationException("Copy this draft into the active account before saving to GitHub.");
        LocalGist? result;
        if (!createNew && doc.GistId is not null && doc.GistFilename is not null)
        {
            var remote = await LoadAsync(doc.GistId, profile.AccessToken);
            if (!string.Equals(remote.Owner?.Login, profile.GithubUsername, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("This Gist belongs to another account. Use Save as new Gist.");
            if (ReadSource(remote, doc.GistFilename) != doc.RemoteXml)
                throw new InvalidOperationException("The diagram changed on GitHub. Open its latest version as a new draft, or choose Save as new Gist to keep your work.");
            result = await github.UpdateGistAsync(remote.Id, remote.Description,
                new() { [doc.GistFilename] = new() { Content = doc.Xml } }, profile.AccessToken);
        }
        else
        {
            filename = filename.Trim();
            if (!Regex.IsMatch(filename, "\\A[^<>:\"/\\\\|?*\\x00-\\x1f]{1,120}\\.drawio\\z", RegexOptions.IgnoreCase))
                throw new InvalidOperationException("Use a filename ending in .drawio without path separators or special characters.");
            result = await github.CreateGistAsync(doc.Title, isPublic,
                new() { [filename] = new() { Content = doc.Xml } }, profile.AccessToken);
        }
        return result ?? throw new InvalidOperationException(github.LastError?.Message ?? "GitHub did not confirm the save. Check My Gists before retrying to avoid duplicate creation. Your local draft is retained.");
    }
}
