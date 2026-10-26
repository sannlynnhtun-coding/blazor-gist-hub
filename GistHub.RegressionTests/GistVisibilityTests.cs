using GistHub.Components;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;

static class GistVisibilityTests
{
    public static async Task RunAsync()
    {
        using var provider = new ServiceCollection().AddLogging()
            .AddSingleton<IJSRuntime>(new NoJs()).BuildServiceProvider();
        await using var renderer = new HtmlRenderer(provider, provider.GetRequiredService<ILoggerFactory>());
        foreach (var isPublic in new[] { false, true })
        {
            var html = await renderer.Dispatcher.InvokeAsync(async () =>
            {
                var root = await renderer.RenderComponentAsync<GistCard>(ParameterView.FromDictionary(
                    new Dictionary<string, object?> {
                        ["Id"] = "abc123",
                        ["IsPublic"] = isPublic,
                        ["ShowVisibilityControls"] = true
                    }));
                return root.ToHtmlString();
            });
            var hasEditLink = html.Contains("href=\"https://gist.github.com/abc123/edit\"");
            if (isPublic ? hasEditLink || !html.Contains("GitHub does not allow making it secret")
                : !hasEditLink || !html.Contains("then use Sync Cloud") || !html.Contains("noopener noreferrer"))
                throw new Exception("Visibility must use GitHub's edit page for secret gists and be read-only for public gists.");
            if (html.Contains("Change to secret") || html.Contains("Change to public"))
                throw new Exception("Cards must not promise an unsupported local visibility toggle.");
        }
        Console.WriteLine("PASS: gist visibility links to GitHub and never offers public-to-secret conversion.");
    }

    private sealed class NoJs : IJSRuntime
    {
        public ValueTask<TValue> InvokeAsync<TValue>(string identifier, object?[]? args)
            => throw new Exception("Unexpected JS during static render: " + identifier);
        public ValueTask<TValue> InvokeAsync<TValue>(string identifier, CancellationToken cancellationToken, object?[]? args)
            => InvokeAsync<TValue>(identifier, args);
    }
}
