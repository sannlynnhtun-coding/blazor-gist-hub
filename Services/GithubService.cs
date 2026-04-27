using GistHub.Models;
using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace GistHub.Services;

public interface IGithubService
{
    Task<List<LocalGist>> GetPublicGistsAsync();
    Task<List<LocalGist>> GetUserGistsAsync(string token);
    Task<bool> DeleteGistAsync(string gistId, string token);
    Task<LocalGist?> CreateGistAsync(string description, bool isPublic, Dictionary<string, GistFile> files, string token);
    Task<LocalGist?> UpdateGistAsync(string id, string description, Dictionary<string, GistFile> files, string token);
    Task<LocalGist?> GetGistByIdAsync(string id, string? token = null);
    Task<GithubUser?> GetUserInfoAsync(string token);
}

public class GithubUser
{
    [JsonPropertyName("login")]
    public string Login { get; set; } = string.Empty;
    [JsonPropertyName("name")]
    public string? Name { get; set; }
    [JsonPropertyName("avatar_url")]
    public string AvatarUrl { get; set; } = string.Empty;
    [JsonPropertyName("bio")]
    public string? Bio { get; set; }
}

public class GithubService : IGithubService
{
    private readonly HttpClient _http;

    public GithubService(HttpClient http)
    {
        _http = http;
    }

    private void EnsureUserAgent()
    {
        if (!_http.DefaultRequestHeaders.Contains("User-Agent"))
        {
            _http.DefaultRequestHeaders.Add("User-Agent", "GistHub-Blazor");
        }
    }

    public async Task<List<LocalGist>> GetPublicGistsAsync()
    {
        EnsureUserAgent();
        try 
        {
             var response = await _http.GetFromJsonAsync<List<LocalGist>>("https://api.github.com/gists/public");
             return response ?? new List<LocalGist>();
        }
        catch (Exception)
        {
            return new List<LocalGist>();
        }
    }

    public async Task<List<LocalGist>> GetUserGistsAsync(string token)
    {
        EnsureUserAgent();
        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        
        try 
        {
            var response = await _http.GetFromJsonAsync<List<LocalGist>>("https://api.github.com/gists");
            return response ?? new List<LocalGist>();
        }
        catch (Exception)
        {
            return new List<LocalGist>();
        }
    }

    public async Task<bool> DeleteGistAsync(string gistId, string token)
    {
        EnsureUserAgent();
        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        var response = await _http.DeleteAsync($"https://api.github.com/gists/{gistId}");
        return response.IsSuccessStatusCode;
    }

    public async Task<LocalGist?> CreateGistAsync(string description, bool isPublic, Dictionary<string, GistFile> files, string token)
    {
        EnsureUserAgent();
        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        var payload = new
        {
            description = description,
            @public = isPublic,
            files = files.ToDictionary(f => f.Key, f => new { content = f.Value.Content })
        };

        var response = await _http.PostAsJsonAsync("https://api.github.com/gists", payload);
        if (response.IsSuccessStatusCode)
        {
            return await response.Content.ReadFromJsonAsync<LocalGist>();
        }
        return null;
    }

    public async Task<LocalGist?> GetGistByIdAsync(string id, string? token = null)
    {
        EnsureUserAgent();
        if (!string.IsNullOrEmpty(token))
        {
            _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        }
        else
        {
            _http.DefaultRequestHeaders.Authorization = null;
        }

        try 
        {
            return await _http.GetFromJsonAsync<LocalGist>($"https://api.github.com/gists/{id}");
        }
        catch 
        {
            return null;
        }
    }

    public async Task<LocalGist?> UpdateGistAsync(string id, string description, Dictionary<string, GistFile> files, string token)
    {
        EnsureUserAgent();
        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        
        var body = new
        {
            description = description,
            files = files
        };

        var response = await _http.PatchAsJsonAsync($"https://api.github.com/gists/{id}", body);
        if (response.IsSuccessStatusCode)
        {
            return await response.Content.ReadFromJsonAsync<LocalGist>();
        }
        return null;
    }

    public async Task<GithubUser?> GetUserInfoAsync(string token)
    {
        EnsureUserAgent();
        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        try 
        {
            return await _http.GetFromJsonAsync<GithubUser>("https://api.github.com/user");
        }
        catch 
        {
            return null;
        }
    }
}
