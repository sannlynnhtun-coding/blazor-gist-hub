using System.Net;
using GistHub.LocalDownloader;
using GistHub.Models;
using Microsoft.AspNetCore.StaticFiles;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureKestrel(options =>
{
    options.Listen(IPAddress.Loopback, 5188);
    options.Limits.MaxRequestBodySize = 4096;
});
builder.Services.AddSingleton<ToolRunner>();
builder.Services.AddSingleton<DownloaderService>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<DownloaderService>());
builder.Services.AddHostedService<LauncherLifetime>();
builder.Services.AddProblemDetails();
var app = builder.Build();
app.Use(async (context, next) =>
{
    var request = context.Request;
    if (request.Host.Host is not ("localhost" or "127.0.0.1") || request.Host.Port != 5188
        || context.Connection.RemoteIpAddress is not { } remote || !IPAddress.IsLoopback(remote))
    { context.Response.StatusCode = 403; return; }
    if (request.Path.StartsWithSegments("/api/downloader"))
    {
        context.Response.Headers.CacheControl = "no-store";
        var origin = request.Headers.Origin.ToString();
        if ((!string.IsNullOrEmpty(origin) && origin != $"{request.Scheme}://{request.Host}")
            || (request.Method is "POST" or "DELETE" && request.Headers["X-GistHub-Local"] != "1"))
        { context.Response.StatusCode = 403; return; }
    }
    try { await next(context); }
    catch (ArgumentException ex) { await Results.Problem(ex.Message, statusCode: 400).ExecuteAsync(context); }
    catch (InvalidOperationException ex) { await Results.Problem(ex.Message, statusCode: 409).ExecuteAsync(context); }
    catch (TimeoutException ex) { await Results.Problem(ex.Message, statusCode: 504).ExecuteAsync(context); }
    catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested) { }
});
var api = app.MapGroup("/api/downloader");
api.MapGet("/health", (DownloaderService service, CancellationToken token) => service.HealthAsync(token));
api.MapPost("/inspect", (InspectVideoRequest request, DownloaderService service, CancellationToken token) => service.InspectAsync(request.Url, token));
api.MapPost("/downloads", (StartDownloadRequest request, DownloaderService service) => service.Start(request));
api.MapGet("/downloads/{id}", (string id, DownloaderService service) => service.GetStatus(id) is { } status ? Results.Ok(status) : Results.NotFound());
api.MapDelete("/downloads/{id}", (string id, DownloaderService service) => service.Cancel(id) ? Results.NoContent() : Results.NotFound());
api.MapGet("/downloads/{id}/file", (string id, DownloaderService service) =>
{
    var file = service.GetFile(id);
    return file is null ? Results.NotFound() : Results.File(file.Value.Path, "application/octet-stream", file.Value.Filename, enableRangeProcessing: true);
});
var types = new FileExtensionContentTypeProvider();
types.Mappings[".wasm"] = "application/wasm";
types.Mappings[".dat"] = "application/octet-stream";
types.Mappings[".blat"] = "application/octet-stream";
types.Mappings[".dll"] = "application/octet-stream";
types.Mappings[".webcil"] = "application/octet-stream";
app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions { ContentTypeProvider = types });
app.MapFallback("/api/{**path}", () => Results.NotFound());
app.MapFallbackToFile("index.html");
app.Run();
