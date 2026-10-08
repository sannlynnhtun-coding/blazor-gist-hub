using System.Diagnostics;

namespace GistHub.LocalDownloader;

// A closed Windows launcher cannot send a graceful console signal to a hidden
// child. Watching its lifetime lets the service cancel yt-dlp/FFmpeg first.
public sealed class LauncherLifetime(IConfiguration configuration, IHostApplicationLifetime lifetime) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!int.TryParse(configuration["Downloader:ParentProcessId"], out var parentId)) return;
        try
        {
            using var parent = Process.GetProcessById(parentId);
            await parent.WaitForExitAsync(stoppingToken);
            lifetime.StopApplication();
        }
        catch (ArgumentException) { lifetime.StopApplication(); }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
    }
}
