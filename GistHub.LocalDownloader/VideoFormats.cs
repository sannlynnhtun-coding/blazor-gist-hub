using System.Text.Json;
using GistHub.Models;

namespace GistHub.LocalDownloader;

public sealed record MediaChoice(DownloadOption Display, string Selector, bool ConvertToMp3 = false);

public static class VideoFormats
{
    public static List<MediaChoice> Parse(JsonElement root)
    {
        if (!root.TryGetProperty("formats", out var formats)) return [];
        var rows = formats.EnumerateArray().Where(row => Text(row, "format_id") is { Length: > 0 }
            && !string.Equals(Text(row, "has_drm"), "true", StringComparison.OrdinalIgnoreCase)).ToList();
        var audio = rows.Where(row => Text(row, "vcodec") == "none" && Text(row, "acodec") is not null and not "none")
            .OrderByDescending(row => Number(row, "abr") ?? Number(row, "tbr") ?? 0).ToList();
        var choices = new List<MediaChoice>();
        foreach (var group in rows.Where(row => Number(row, "height") > 0 && Text(row, "vcodec") is not null and not "none"
                     && Text(row, "ext") is "mp4" or "webm")
                     .GroupBy(row => (Height: Number(row, "height"), Ext: Text(row, "ext")))
                     .OrderByDescending(group => group.Key.Height).ThenBy(group => group.Key.Ext))
        {
            var video = group.OrderByDescending(row => Number(row, "fps") ?? 0).ThenByDescending(row => Number(row, "tbr") ?? 0).First();
            var selector = Text(video, "format_id")!;
            long? size = Size(video);
            var estimated = !video.TryGetProperty("filesize", out _);
            if (Text(video, "acodec") is null or "none")
            {
                var compatibleAudio = audio.FirstOrDefault(row => Text(row, "ext") == (group.Key.Ext == "mp4" ? "m4a" : "webm"));
                if (compatibleAudio.ValueKind == JsonValueKind.Undefined) continue;
                selector += "+" + Text(compatibleAudio, "format_id");
                size = size.HasValue && Size(compatibleAudio).HasValue ? size + Size(compatibleAudio) : null;
                estimated |= !compatibleAudio.TryGetProperty("filesize", out _);
            }
            choices.Add(new(new($"video-{choices.Count}", "video", $"{group.Key.Height:0}p", group.Key.Ext!, size, estimated), selector));
        }
        foreach (var group in audio.Where(row => Text(row, "ext") is "m4a" or "webm").GroupBy(row => Text(row, "ext")))
        {
            var best = group.First();
            choices.Add(new(new($"audio-{choices.Count}", "audio", $"{Number(best, "abr") ?? Number(best, "tbr") ?? 0:0} kbps", group.Key!, Size(best), !best.TryGetProperty("filesize", out _)), Text(best, "format_id")!));
        }
        if (audio.Count > 0)
            choices.Add(new(new("audio-mp3", "audio", "MP3 conversion", "mp3", null, false), Text(audio[0], "format_id")!, true));
        return choices;
    }

    public static string? Text(JsonElement element, string name)
        => element.TryGetProperty(name, out var value) && value.ValueKind != JsonValueKind.Null ? value.ToString() : null;
    public static double? Number(JsonElement element, string name)
        => element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number) ? number : null;
    private static long? Size(JsonElement row) => (long?)(Number(row, "filesize") ?? Number(row, "filesize_approx"));
}
