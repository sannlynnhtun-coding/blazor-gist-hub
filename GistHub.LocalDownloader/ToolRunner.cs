using System.Diagnostics;

namespace GistHub.LocalDownloader;

public sealed class ToolRunner(IConfiguration configuration)
{
    public string YtDlp => configuration["Downloader:YtDlp"] ?? "yt-dlp";
    public string Ffmpeg => configuration["Downloader:Ffmpeg"] ?? "ffmpeg";
    public string Ffprobe => configuration["Downloader:Ffprobe"] ?? "ffprobe";

    public async Task<string> RunAsync(string executable, IEnumerable<string> arguments, TimeSpan timeout, CancellationToken cancellationToken)
    {
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(timeout);
        var startInfo = new ProcessStartInfo(executable)
        {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true
        };
        foreach (var argument in arguments) startInfo.ArgumentList.Add(argument);
        using var process = new Process { StartInfo = startInfo };
        try { process.Start(); }
        catch (System.ComponentModel.Win32Exception)
        {
            throw new InvalidOperationException($"Cannot start {Path.GetFileName(executable)}. Run scripts/install-downloader-tools.ps1 first.");
        }

        var output = process.StandardOutput.ReadToEndAsync(deadline.Token);
        var error = process.StandardError.ReadToEndAsync(deadline.Token);
        try
        {
            await process.WaitForExitAsync(deadline.Token);
            var stdout = await output;
            var stderr = await error;
            if (process.ExitCode != 0)
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(stderr) ? "The media tool failed." : stderr.Trim()[..Math.Min(stderr.Trim().Length, 1600)]);
            return stdout;
        }
        catch (OperationCanceledException)
        {
            if (!process.HasExited) process.Kill(entireProcessTree: true);
            await process.WaitForExitAsync(CancellationToken.None);
            try { await Task.WhenAll(output, error); } catch (OperationCanceledException) { }
            if (cancellationToken.IsCancellationRequested) throw;
            throw new TimeoutException("The media operation timed out. Try a shorter video or try again later.");
        }
    }

    public List<string> BaseArguments() => ["--ignore-config", "--no-plugin-dirs", "--no-playlist", "--no-warnings", "--no-color", "--socket-timeout", "20", "--retries", "2", "--js-runtimes", "node", "--ffmpeg-location", Ffmpeg];
}
