using GistHub.Models;
using Microsoft.JSInterop;

namespace GistHub.Services;

public interface IStorageService
{
    Task InitAsync();
    Task SaveProfileAsync(GistProfile profile);
    Task<List<GistProfile>> GetProfilesAsync();
    Task DeleteProfileAsync(string id);
    
    Task SaveGistAsync(LocalGist gist);
    Task<List<LocalGist>> GetLocalGistsAsync();
    Task DeleteGistAsync(string id);
}

public class IndexedDbService : IStorageService
{
    private readonly IJSRuntime _js;
    private IJSObjectReference? _module;

    public IndexedDbService(IJSRuntime js)
    {
        _js = js;
    }

    public async Task InitAsync()
    {
        _module = await _js.InvokeAsync<IJSObjectReference>("import", "./js/indexedDb.js");
        await _module.InvokeVoidAsync("initDb");
    }

    public async Task SaveProfileAsync(GistProfile profile)
    {
        await EnsureModule();
        await _module!.InvokeVoidAsync("saveItem", "profiles", profile);
    }

    public async Task<List<GistProfile>> GetProfilesAsync()
    {
        await EnsureModule();
        return await _module!.InvokeAsync<List<GistProfile>>("getAllItems", "profiles");
    }

    public async Task DeleteProfileAsync(string id)
    {
        await EnsureModule();
        await _module!.InvokeVoidAsync("deleteItem", "profiles", id);
    }

    public async Task SaveGistAsync(LocalGist gist)
    {
        await EnsureModule();
        await _module!.InvokeVoidAsync("saveItem", "gists", gist);
    }

    public async Task<List<LocalGist>> GetLocalGistsAsync()
    {
        await EnsureModule();
        return await _module!.InvokeAsync<List<LocalGist>>("getAllItems", "gists");
    }

    public async Task DeleteGistAsync(string id)
    {
        await EnsureModule();
        await _module!.InvokeVoidAsync("deleteItem", "gists", id);
    }

    private async Task EnsureModule()
    {
        if (_module == null)
        {
            await InitAsync();
        }
    }
}
