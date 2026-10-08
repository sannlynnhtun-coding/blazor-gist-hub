namespace GistHub.Models;

public sealed record InspectVideoRequest(string Url);
public sealed record StartDownloadRequest(string VideoToken, string OptionId);
public sealed record DownloaderHealth(bool Ready, string Message);
public sealed record DownloadOption(string Id, string Kind, string Quality, string Format, long? SizeBytes, bool Estimated);
public sealed record VideoPreview(string Token, string Title, string? Thumbnail, string? Channel, double? Duration, List<DownloadOption> Options);
public sealed record DownloadStatus(string Id, string State, string Message, string? FileUrl = null, string? Filename = null);
