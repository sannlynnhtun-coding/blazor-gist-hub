using System.Net;
using System.Text;
using System.Text.Json;
using GistHub.Models;
using GistHub.Services;

static class DiagramGistTests
{
    public static async Task RunAsync()
    {
        var handler = new DiagramHandler();
        var service = new DiagramGistService(new GithubService(new HttpClient(handler), "https://api.github.com"));
        var profile = new GistProfile { GithubUsername = "alice", AccessToken = "test-placeholder" };
        var doc = new DiagramDocument { Owner = "github:alice", Title = "Architecture", Xml = "<mxfile/>", GistId = "abcde", GistFilename = "diagram.drawio", RemoteXml = "old" };
        await service.SaveAsync(doc, profile, "ignored.drawio", false, false);
        using (var body = JsonDocument.Parse(handler.LastWrite!))
        {
            Check(handler.Method == HttpMethod.Patch, "Linked diagrams use PATCH");
            Check(body.RootElement.GetProperty("files").EnumerateObject().Count() == 1, "Updates send only the linked file");
            Check(body.RootElement.GetProperty("files").GetProperty("diagram.drawio").GetProperty("content").GetString() == "<mxfile/>", "Updates contain the current source");
            Check(body.RootElement.GetProperty("description").GetString() == "Remote description", "Updates preserve the Gist description");
        }
        handler.LastWrite = null; handler.RemoteSource = "changed elsewhere";
        await Reject(() => service.SaveAsync(doc, profile, "diagram.drawio", false, false));
        Check(handler.LastWrite is null, "Remote changes block writes");
        handler.RemoteSource = "old"; handler.Owner = "bob";
        await Reject(() => service.SaveAsync(doc, profile, "diagram.drawio", false, false));
        Check(handler.LastWrite is null, "Other owners cannot be overwritten");
        handler.Owner = "alice"; handler.Truncated = true;
        await Reject(() => service.SaveAsync(doc, profile, "diagram.drawio", false, false));
        Check(handler.LastWrite is null, "Truncated remote source cannot be used as a baseline");
        handler.Truncated = false;
        await service.SaveAsync(doc, profile, "new.drawio", false, true);
        using (var body = JsonDocument.Parse(handler.LastWrite!))
            Check(handler.Method == HttpMethod.Post && !body.RootElement.GetProperty("public").GetBoolean(), "New Gists honor secret visibility");
        handler.LastWrite = null;
        doc.Owner = "guest";
        await Reject(() => service.SaveAsync(doc, profile, "new.drawio", true, true));
        Check(handler.LastWrite is null, "Account mismatches block writes");
        doc.Owner = "github:alice";
        await Reject(() => service.SaveAsync(doc, profile, "../bad.drawio", false, true));
        Check(handler.LastWrite is null, "Invalid filenames are rejected");
        handler.FailWrites = true;
        await Reject(() => service.SaveAsync(doc, profile, "new.drawio", false, true));
        Check(DiagramGistService.ParseId("https://gist.github.com/alice/abcde") == "abcde", "Gist URLs resolve to IDs");
        Console.WriteLine("PASS: diagram Gist updates preserve unrelated files and reject conflicts, truncated sources, owner mismatches, bad names, and failed writes.");
    }

    private static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
    private static async Task Reject(Func<Task<LocalGist>> work)
    {
        try { await work(); } catch (InvalidOperationException) { return; }
        throw new Exception("Expected the unsafe or failed operation to be rejected.");
    }

    private sealed class DiagramHandler : HttpMessageHandler
    {
        public string RemoteSource = "old", Owner = "alice";
        public bool Truncated, FailWrites;
        public string? LastWrite;
        public HttpMethod? Method;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.Method != HttpMethod.Get)
            {
                Method = request.Method;
                LastWrite = await request.Content!.ReadAsStringAsync(cancellationToken);
                if (FailWrites) return new(HttpStatusCode.Forbidden) { Content = new StringContent("{\"message\":\"API rate limit exceeded\"}") };
            }
            var json = JsonSerializer.Serialize(new {
                id = "abcde", description = "Remote description", owner = new { login = Owner },
                files = new Dictionary<string, object> {
                    ["diagram.drawio"] = new { content = RemoteSource, truncated = Truncated },
                    ["README.md"] = new { content = "Keep me" }
                }
            });
            return new(HttpStatusCode.OK) { Content = new StringContent(json, Encoding.UTF8, "application/json") };
        }
    }
}
