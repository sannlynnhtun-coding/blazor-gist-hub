using System.Text.Json;
using GistHub.LocalDownloader;
using GistHub.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;

const string fixture = """
{"title":"Test / media", "duration":12, "channel":"Example", "formats":[
 {"format_id":"100","height":720,"ext":"mp4","vcodec":"avc1","acodec":"none","filesize":1000,"tbr":100},
 {"format_id":"299","height":1080,"ext":"mp4","vcodec":"avc1","acodec":"none","filesize":2000},
 {"format_id":"500","height":480,"ext":"mp4","vcodec":"avc1","acodec":"none","filesize":700},
 {"format_id":"140","height":null,"ext":"m4a","vcodec":"none","acodec":"mp4a","filesize":200,"abr":128},
 {"format_id":"251","height":null,"ext":"webm","vcodec":"none","acodec":"opus","filesize_approx":150,"abr":100},
 {"format_id":"drm","height":2160,"ext":"mp4","vcodec":"avc1","acodec":"none","has_drm":true}
]}
""";
// Also act as a deterministic child process for job tests.
if (args.Length > 0)
{
    if (args.Contains("--dump-single-json")) Console.WriteLine(fixture);
    else if (args.Contains("--output"))
    {
        var selector = args[Array.IndexOf(args, "--format") + 1];
        if (selector.StartsWith("299")) await Task.Delay(30000);
        if (selector.StartsWith("500")) { Console.Error.WriteLine("Fixture download failed"); Environment.Exit(1); }
        var ext = args.Contains("--audio-format") ? "mp3" : selector == "140" ? "m4a" : "mp4";
        await File.WriteAllBytesAsync(args[Array.IndexOf(args, "--output") + 1].Replace("%(ext)s", ext), [1, 2, 3, 4]);
    }
    else Console.WriteLine("fixture 1.0");
    return;
}
foreach (var url in new[] { "https://youtu.be/BaW_jenozKc?t=2", "https://www.youtube.com/watch?v=BaW_jenozKc&list=ignored", "https://youtube.com/shorts/BaW_jenozKc" })
    Assert(YouTubeUrl.Normalize(url) == "https://www.youtube.com/watch?v=BaW_jenozKc", "URLs must normalize and discard extra parameters.");
foreach (var url in new[] { "http://youtube.com/watch?v=BaW_jenozKc", "https://youtube.com.evil.test/watch?v=BaW_jenozKc", "https://youtube.com@127.0.0.1/watch?v=BaW_jenozKc", "https://youtube.com:9000/watch?v=BaW_jenozKc", "https://youtube.com/playlist?list=123", "file:///etc/passwd", "--exec=malicious" })
{
    var rejected = false;
    try { YouTubeUrl.Normalize(url); } catch (ArgumentException) { rejected = true; }
    Assert(rejected, "Unsafe URL must be rejected: " + url);
}
using var json = JsonDocument.Parse(fixture);
var formats = VideoFormats.Parse(json.RootElement);
Assert(formats.Count == 6, "Offer only playable non-DRM formats.");
var video720 = formats.Single(c => c.Display.Quality == "720p");
Assert(video720.Selector == "100+140" && video720.Display.SizeBytes == 1200, "Pair video with compatible audio and combined size.");
Assert(formats.Single(c => c.Display.Format == "webm").Display.Estimated, "Mark approximate sizes.");
Assert(formats.Single(c => c.ConvertToMp3).Display.SizeBytes is null, "Do not invent MP3 size.");
var executable = Environment.ProcessPath!;
Assert(!Path.GetFileNameWithoutExtension(executable).Equals("dotnet", StringComparison.OrdinalIgnoreCase), "Use dotnet run for the test apphost.");
var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
{
    ["Downloader:YtDlp"] = executable, ["Downloader:Ffmpeg"] = executable, ["Downloader:Ffprobe"] = executable
}).Build();
var runner = new ToolRunner(config);
var service = new DownloaderService(runner, new TestLifetime(), NullLogger<DownloaderService>.Instance);
var preview = await service.InspectAsync("https://youtu.be/BaW_jenozKc", CancellationToken.None);
var complete = await Wait(service, service.Start(new(preview.Token, video720.Display.Id)).Id);
Assert(complete.State == "complete" && service.GetFile(complete.Id) is not null, "Completed job exposes a real file.");
Assert(!complete.Filename!.Contains('/'), "Sanitize filenames.");
var mp3 = await Wait(service, service.Start(new(preview.Token, "audio-mp3")).Id);
Assert(mp3.State == "complete" && mp3.Filename!.EndsWith(".mp3"), "MP3 jobs request conversion.");
var slow = service.Start(new(preview.Token, formats.Single(c => c.Display.Quality == "1080p").Display.Id));
await Task.Delay(300);
service.Cancel(slow.Id);
Assert((await Wait(service, slow.Id)).State == "cancelled" && service.GetFile(slow.Id) is null, "Cancel kills the tool and exposes no partial file.");
var failed = await Wait(service, service.Start(new(preview.Token, formats.Single(c => c.Display.Quality == "480p").Display.Id)).Id);
Assert(failed.State == "failed" && failed.Message.Contains("Fixture download failed") && service.GetFile(failed.Id) is null, "Failures surface without partial files.");
Assert(service.GetFile("../outside") is null, "IDs must not resolve arbitrary paths.");
var timedOut = false;
try { await runner.RunAsync(executable, ["--output", "unused", "--format", "299"], TimeSpan.FromMilliseconds(200), CancellationToken.None); }
catch (TimeoutException) { timedOut = true; }
Assert(timedOut, "Timeout must terminate the child process.");
Console.WriteLine("PASS: URL validation, audio pairing, sizes, process jobs, MP3 requests, cancellation, failures, and timeouts.");
static void Assert(bool condition, string message) { if (!condition) throw new Exception(message); }
static async Task<DownloadStatus> Wait(DownloaderService service, string id)
{
    using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
    while (true)
    {
        var status = service.GetStatus(id)!;
        if (status.State is not ("queued" or "downloading")) return status;
        await Task.Delay(50, timeout.Token);
    }
}
sealed class TestLifetime : IHostApplicationLifetime
{
    public CancellationToken ApplicationStarted => CancellationToken.None;
    public CancellationToken ApplicationStopping => CancellationToken.None;
    public CancellationToken ApplicationStopped => CancellationToken.None;
    public void StopApplication() { }
}
