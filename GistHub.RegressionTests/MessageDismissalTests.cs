using GistHub.Components.UI;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

static class MessageDismissalTests
{
    public static async Task RunAsync()
    {
        using var provider = new ServiceCollection().AddLogging().BuildServiceProvider();
        await using var renderer = new HtmlRenderer(provider, provider.GetRequiredService<ILoggerFactory>());
        var dismissed = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
        var started = System.Diagnostics.Stopwatch.StartNew();
        await renderer.Dispatcher.InvokeAsync(() => renderer.RenderComponentAsync<AutoDismissMessage>(
            ParameterView.FromDictionary(new Dictionary<string, object?> {
                ["Message"] = "Saved",
                ["MessageChanged"] = EventCallback.Factory.Create<string>(new object(), value => dismissed.TrySetResult(value))
            })));
        await Task.Delay(9000);
        if (dismissed.Task.IsCompleted) throw new Exception("Notification dismissed before ten seconds.");
        var value = await dismissed.Task.WaitAsync(TimeSpan.FromSeconds(5));
        if (value != "" || started.Elapsed < TimeSpan.FromSeconds(10))
            throw new Exception("Notification did not clear its bound message after ten seconds.");
        Console.WriteLine("PASS: notification remains visible for ten seconds, then clears its bound message.");
    }
}
