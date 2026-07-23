using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using GistHub;
using GistHub.Services;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

// Register Services
builder.Services.AddScoped(sp => new HttpClient { BaseAddress = new Uri(builder.HostEnvironment.BaseAddress) });
var githubApiBaseUrl = builder.HostEnvironment.IsDevelopment()
    ? "https://api.github.com"
    : new Uri(new Uri(builder.HostEnvironment.BaseAddress), "api/github").ToString();
builder.Services.AddScoped<IGithubService>(sp =>
    new GithubService(sp.GetRequiredService<HttpClient>(), githubApiBaseUrl));
builder.Services.AddScoped<IStorageService, IndexedDbService>();
builder.Services.AddScoped<AppState>();

await builder.Build().RunAsync();
