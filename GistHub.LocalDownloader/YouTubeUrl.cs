using System.Text.RegularExpressions;

namespace GistHub.LocalDownloader;

public static partial class YouTubeUrl
{
    public static string Normalize(string? value)
    {
        if (value is null || value.Length > 2048 || !Uri.TryCreate(value.Trim(), UriKind.Absolute, out var uri)
            || uri.Scheme != "https" || !uri.IsDefaultPort || !string.IsNullOrEmpty(uri.UserInfo))
            throw new ArgumentException("Enter a valid HTTPS YouTube video URL.");

        string? id = null;
        if (uri.Host.Equals("youtu.be", StringComparison.OrdinalIgnoreCase))
            id = uri.AbsolutePath.Trim('/');
        else if (new[] { "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com" }.Contains(uri.Host.ToLowerInvariant()))
        {
            var segments = uri.AbsolutePath.Trim('/').Split('/');
            if (segments.Length == 2 && segments[0] is "shorts" or "embed" or "live")
                id = segments[1];
            else if (uri.AbsolutePath == "/watch")
                id = uri.Query.TrimStart('?').Split('&').Select(part => part.Split('=', 2))
                    .FirstOrDefault(part => part.Length == 2 && part[0] == "v")?[1];
        }

        if (id is null || !VideoId().IsMatch(id))
            throw new ArgumentException("Use a YouTube watch, Shorts, or youtu.be video link.");
        return $"https://www.youtube.com/watch?v={id}";
    }

    [GeneratedRegex("^[A-Za-z0-9_-]{11}$")]
    private static partial Regex VideoId();
}
