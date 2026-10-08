using System.Collections.Concurrent;
using System.Text.Json;
using GistHub.Models;

namespace GistHub.LocalDownloader;

public sealed class DownloaderService(ToolRunner tools, IHostApplicationLifetime lifetime, ILogger<DownloaderService> logger) : IHostedService
{
    private sealed record Preview(string Url, string Title, List<MediaChoice> Choices, DateTimeOffset Created);
    private sealed class Job(string id)
    {
        public DownloadStatus Status = new(id, "queued", "Waiting for the local downloader…");
        public readonly CancellationTokenSource Cancellation = new();
        public string? File;
        public Task Work = Task.CompletedTask;
        public DateTimeOffset Created = DateTimeOffset.UtcNow;
    }
    private readonly ConcurrentDictionary<string, Preview> videos = new();
    private readonly ConcurrentDictionary<string, Job> jobs = new();
    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly string downloadRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GistHub", "Downloader");

    public async Task<DownloaderHealth> HealthAsync(CancellationToken token)
    {
        try
        {
            await tools.RunAsync(tools.YtDlp, ["--version"], TimeSpan.FromSeconds(10), token);
            await tools.RunAsync(tools.Ffmpeg, ["-version"], TimeSpan.FromSeconds(10), token);
            await tools.RunAsync(tools.Ffprobe, ["-version"], TimeSpan.FromSeconds(10), token);
            var nodeVersion = await tools.RunAsync("node", ["--version"], TimeSpan.FromSeconds(10), token);
            if (!Version.TryParse(nodeVersion.Trim().TrimStart('v'), out var version) || version.Major < 22)
                return new(false, "Install Node.js 22 or later, then restart the launcher.");
            return new(true, "Local downloader is ready.");
        }
        catch (Exception ex) when (ex is InvalidOperationException or TimeoutException) { return new(false, ex.Message); }
    }

    public async Task<VideoPreview> InspectAsync(string url, CancellationToken token)
    {
        url = YouTubeUrl.Normalize(url);
        Prune();
        if (videos.Count >= 100) throw new InvalidOperationException("Too many previews. Wait for older previews to expire.");
        if (!await gate.WaitAsync(0, token)) throw new InvalidOperationException("The downloader is busy. Wait for the current operation to finish.");
        try
        {
            var args = tools.BaseArguments();
            args.AddRange(["--dump-single-json", "--skip-download", "--", url]);
            using var document = JsonDocument.Parse(await tools.RunAsync(tools.YtDlp, args, TimeSpan.FromSeconds(90), token));
            var root = document.RootElement;
            if (VideoFormats.Text(root, "is_live") == "True" || VideoFormats.Text(root, "live_status") is "is_live" or "is_upcoming")
                throw new ArgumentException("Live and upcoming videos are not supported. Choose a completed video.");
            var choices = VideoFormats.Parse(root);
            if (choices.Count == 0) throw new InvalidOperationException("No downloadable video or audio formats were found.");
            var id = Guid.NewGuid().ToString("N");
            var title = VideoFormats.Text(root, "title") ?? "YouTube video";
            videos[id] = new(url, title, choices, DateTimeOffset.UtcNow);
            var thumbnail = VideoFormats.Text(root, "thumbnail");
            if (!Uri.TryCreate(thumbnail, UriKind.Absolute, out var image) || image.Scheme != "https") thumbnail = null;
            return new(id, title, thumbnail, VideoFormats.Text(root, "channel"), VideoFormats.Number(root, "duration"), choices.Select(choice => choice.Display).ToList());
        }
        finally { gate.Release(); }
    }

    public DownloadStatus Start(StartDownloadRequest request)
    {
        Prune();
        if (!videos.TryGetValue(request.VideoToken, out var video)) throw new ArgumentException("This preview expired. Look up the video again.");
        var choice = video.Choices.FirstOrDefault(item => item.Display.Id == request.OptionId) ?? throw new ArgumentException("Select an available format.");
        if (jobs.Values.Count(job => job.Status.State is "queued" or "downloading") >= 4) throw new InvalidOperationException("The download queue is full.");
        var id = Guid.NewGuid().ToString("N");
        var job = new Job(id);
        jobs[id] = job;
        job.Work = RunJobAsync(job, video, choice);
        return job.Status;
    }
    public Task StartAsync(CancellationToken token) => Task.CompletedTask;
    public async Task StopAsync(CancellationToken token)
    {
        foreach (var job in jobs.Values) job.Cancellation.Cancel();
        await Task.WhenAll(jobs.Values.Select(job => job.Work)).WaitAsync(token);
    }
    public DownloadStatus? GetStatus(string id) => jobs.TryGetValue(id, out var job) ? job.Status : null;
    public bool Cancel(string id)
    {
        if (!jobs.TryGetValue(id, out var job)) return false;
        if (job.Status.State is "queued" or "downloading") job.Cancellation.Cancel();
        return true;
    }
    public (string Path, string Filename)? GetFile(string id)
    {
        if (!jobs.TryGetValue(id, out var job) || job.Status.State != "complete" || job.File is null || !File.Exists(job.File)) return null;
        return (job.File, job.Status.Filename!);
    }

    private async Task RunJobAsync(Job job, Preview video, MediaChoice choice)
    {
        var id = job.Status.Id;
        var folder = Path.Combine(downloadRoot, id);
        using var cancellation = CancellationTokenSource.CreateLinkedTokenSource(job.Cancellation.Token, lifetime.ApplicationStopping);
        var acquired = false;
        try
        {
            await gate.WaitAsync(cancellation.Token);
            acquired = true;
            Directory.CreateDirectory(folder);
            job.Status = new(id, "downloading", "Downloading and preparing your file…");
            var args = tools.BaseArguments();
            args.AddRange(["--no-progress", "--no-simulate", "--max-filesize", "2G", "--output", Path.Combine(folder, "media.%(ext)s"), "--format", choice.Selector]);
            if (choice.ConvertToMp3) args.AddRange(["--extract-audio", "--audio-format", "mp3", "--audio-quality", "0"]);
            else if (choice.Display.Kind == "video") args.AddRange(["--merge-output-format", choice.Display.Format]);
            args.AddRange(["--", video.Url]);
            await tools.RunAsync(tools.YtDlp, args, TimeSpan.FromMinutes(30), cancellation.Token);
            cancellation.Token.ThrowIfCancellationRequested();
            var file = Path.Combine(folder, "media." + choice.Display.Format);
            if (!File.Exists(file) || new FileInfo(file).Length == 0) throw new InvalidOperationException("No complete file was produced.");
            var filename = string.Concat(video.Title.Select(c => Path.GetInvalidFileNameChars().Contains(c) || char.IsControl(c) ? '_' : c));
            filename = filename[..Math.Min(filename.Length, 120)].Trim(' ', '.');
            job.File = file;
            job.Status = new(id, "complete", "Your file is ready.", $"api/downloader/downloads/{id}/file", $"{filename}.{choice.Display.Format}");
        }
        catch (OperationCanceledException) { job.Status = new(id, "cancelled", "Download cancelled."); }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Local download {Id} failed", id);
            job.Status = new(id, "failed", ex.Message);
        }
        finally
        {
            if (acquired) gate.Release();
            if (job.Status.State != "complete") DeleteFolder(folder);
        }
    }
    private void Prune()
    {
        var cutoff = DateTimeOffset.UtcNow.AddHours(-1);
        foreach (var pair in videos.Where(pair => pair.Value.Created < cutoff)) videos.TryRemove(pair.Key, out _);
        foreach (var pair in jobs.Where(pair => pair.Value.Created < cutoff && pair.Value.Status.State is not ("queued" or "downloading")))
            if (jobs.TryRemove(pair.Key, out var oldJob))
            {
                oldJob.Cancellation.Dispose();
                DeleteFolder(Path.Combine(downloadRoot, pair.Key));
            }
        if (Directory.Exists(downloadRoot))
            foreach (var directory in Directory.EnumerateDirectories(downloadRoot))
                if (Guid.TryParseExact(Path.GetFileName(directory), "N", out _) && !jobs.ContainsKey(Path.GetFileName(directory))
                    && Directory.GetLastWriteTimeUtc(directory) < cutoff.UtcDateTime) DeleteFolder(directory);
    }
    private void DeleteFolder(string folder)
    {
        try { if (Directory.Exists(folder)) Directory.Delete(folder, recursive: true); }
        catch (IOException ex) { logger.LogDebug(ex, "Temporary download cleanup deferred"); }
        catch (UnauthorizedAccessException ex) { logger.LogDebug(ex, "Temporary download cleanup deferred"); }
    }
}
