using GistHub.Models;

namespace GistHub.Services;

public enum GistSearchMatchKind
{
    Description,
    Tag,
    Filename,
    Content
}

public sealed record GistSearchResult(
    string GistId,
    string Title,
    bool IsBookmarked,
    string MatchedFilename,
    GistSearchMatchKind MatchKind,
    string Snippet,
    int Score,
    DateTime UpdatedAt);

public sealed record GistSearchResponse(
    IReadOnlyList<GistSearchResult> Results,
    int TotalCount);

public sealed class GistSearchService
{
    public const int DefaultResultLimit = 50;

    private const int DescriptionContainsScore = 140;
    private const int TagContainsScore = 100;
    private const int FilenameContainsScore = 60;
    private const int ContentContainsScore = 20;
    private const int SnippetContextBefore = 72;
    private const int SnippetContextAfter = 108;

    public GistSearchResponse Search(
        IEnumerable<LocalGist> gists,
        string? query,
        bool bookmarksOnly,
        int limit = DefaultResultLimit)
    {
        ArgumentNullException.ThrowIfNull(gists);

        var terms = Tokenize(query);
        if (terms.Count == 0 || limit <= 0)
        {
            return new GistSearchResponse([], 0);
        }

        var matches = gists
            .Where(gist => !bookmarksOnly || gist.IsBookmarked)
            .Select(gist => CreateResult(gist, terms))
            .Where(result => result is not null)
            .Cast<GistSearchResult>()
            .OrderByDescending(result => result.Score)
            .ThenByDescending(result => result.UpdatedAt)
            .ToList();

        return new GistSearchResponse(matches.Take(limit).ToList(), matches.Count);
    }

    public static IReadOnlyList<string> Tokenize(string? query)
        => (query ?? string.Empty)
            .Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

    private static GistSearchResult? CreateResult(LocalGist gist, IReadOnlyList<string> terms)
    {
        var description = gist.Description ?? string.Empty;
        var tags = gist.Tags ?? [];
        var files = gist.Files ?? new Dictionary<string, GistFile>();
        var totalScore = 0;
        var strongestMatch = new FieldMatch(GistSearchMatchKind.Content, 0, string.Empty, string.Empty, string.Empty);

        foreach (var term in terms)
        {
            var termMatch = FindStrongestMatch(description, tags, files, term);
            if (termMatch.Score == 0)
            {
                return null;
            }

            totalScore += termMatch.Score;
            if (termMatch.Score > strongestMatch.Score)
            {
                strongestMatch = termMatch;
            }
        }

        var filename = strongestMatch.Kind is GistSearchMatchKind.Filename or GistSearchMatchKind.Content
            ? strongestMatch.Filename
            : string.Empty;
        var snippet = strongestMatch.Kind switch
        {
            GistSearchMatchKind.Description => CreateSnippet(description, strongestMatch.Term),
            GistSearchMatchKind.Tag => $"Tag: #{strongestMatch.Value}",
            GistSearchMatchKind.Filename => CreateFilenameSnippet(files, strongestMatch),
            _ => CreateSnippet(strongestMatch.Value, strongestMatch.Term)
        };

        return new GistSearchResult(
            gist.Id,
            string.IsNullOrWhiteSpace(description) ? "Untitled Snippet" : description,
            gist.IsBookmarked,
            filename,
            strongestMatch.Kind,
            snippet,
            totalScore,
            gist.UpdatedAt);
    }

    private static FieldMatch FindStrongestMatch(
        string description,
        IEnumerable<string> tags,
        IReadOnlyDictionary<string, GistFile> files,
        string term)
    {
        var descriptionScore = ScoreText(description, term, DescriptionContainsScore);
        if (descriptionScore > 0)
        {
            return new FieldMatch(GistSearchMatchKind.Description, descriptionScore, string.Empty, description, term);
        }

        foreach (var tag in tags)
        {
            var tagScore = ScoreText(tag, term, TagContainsScore);
            if (tagScore > 0)
            {
                return new FieldMatch(GistSearchMatchKind.Tag, tagScore, string.Empty, tag, term);
            }
        }

        FieldMatch strongestFilename = new(GistSearchMatchKind.Filename, 0, string.Empty, string.Empty, string.Empty);
        foreach (var fileEntry in files)
        {
            var filename = ResolveFilename(fileEntry);
            var filenameScore = ScoreText(filename, term, FilenameContainsScore);
            if (filenameScore > strongestFilename.Score)
            {
                strongestFilename = new FieldMatch(GistSearchMatchKind.Filename, filenameScore, filename, filename, term);
            }
        }

        if (strongestFilename.Score > 0)
        {
            return strongestFilename;
        }

        return FindBestContentMatch(files, [term]);
    }

    private static FieldMatch FindBestContentMatch(
        IReadOnlyDictionary<string, GistFile> files,
        IReadOnlyList<string> terms)
    {
        FieldMatch strongest = new(GistSearchMatchKind.Content, 0, string.Empty, string.Empty, string.Empty);

        foreach (var fileEntry in files)
        {
            var content = fileEntry.Value?.Content ?? string.Empty;
            foreach (var term in terms)
            {
                var score = ScoreText(content, term, ContentContainsScore);
                if (score > strongest.Score)
                {
                    strongest = new FieldMatch(
                        GistSearchMatchKind.Content,
                        score,
                        ResolveFilename(fileEntry),
                        content,
                        term);
                }
            }
        }

        return strongest;
    }

    private static int ScoreText(string? value, string term, int containsScore)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return 0;
        }

        if (string.Equals(value, term, StringComparison.OrdinalIgnoreCase))
        {
            return containsScore + 20;
        }

        if (value.StartsWith(term, StringComparison.OrdinalIgnoreCase))
        {
            return containsScore + 10;
        }

        return value.Contains(term, StringComparison.OrdinalIgnoreCase)
            ? containsScore
            : 0;
    }

    private static string FindFileContent(IReadOnlyDictionary<string, GistFile> files, string filename)
    {
        if (!string.IsNullOrWhiteSpace(filename))
        {
            var matchingEntry = files.FirstOrDefault(entry =>
                string.Equals(ResolveFilename(entry), filename, StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrWhiteSpace(matchingEntry.Value?.Content))
            {
                return matchingEntry.Value.Content!;
            }
        }

        return files.Values.FirstOrDefault(file => !string.IsNullOrWhiteSpace(file?.Content))?.Content
            ?? string.Empty;
    }

    private static string CreateFilenameSnippet(
        IReadOnlyDictionary<string, GistFile> files,
        FieldMatch match)
    {
        var content = FindFileContent(files, match.Filename);
        return string.IsNullOrWhiteSpace(content)
            ? $"File: {match.Filename}"
            : CreateSnippet(content, match.Term);
    }

    private static string ResolveFilename(KeyValuePair<string, GistFile> entry)
        => string.IsNullOrWhiteSpace(entry.Value?.Filename) ? entry.Key : entry.Value.Filename;

    private static string CreateSnippet(string? content, string term)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return string.Empty;
        }

        var matchIndex = content.IndexOf(term, StringComparison.OrdinalIgnoreCase);
        var start = matchIndex >= 0
            ? Math.Max(0, matchIndex - SnippetContextBefore)
            : 0;
        var desiredLength = matchIndex >= 0
            ? term.Length + SnippetContextBefore + SnippetContextAfter
            : SnippetContextBefore + SnippetContextAfter;
        var length = Math.Min(content.Length - start, desiredLength);
        var snippet = content.Substring(start, length)
            .Replace("\r", string.Empty, StringComparison.Ordinal)
            .Replace("\t", "    ", StringComparison.Ordinal)
            .Trim();

        if (start > 0)
        {
            snippet = $"...{snippet}";
        }

        if (start + length < content.Length)
        {
            snippet = $"{snippet}...";
        }

        return snippet;
    }

    private sealed record FieldMatch(
        GistSearchMatchKind Kind,
        int Score,
        string Filename,
        string Value,
        string Term);
}
