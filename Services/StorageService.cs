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
    Task SaveGroupAsync(GistGroup group);
    Task<List<GistGroup>> GetGroupsAsync();
    Task DeleteGroupAsync(string id);
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
        NormalizeGistCollections(gist);
        await _module!.InvokeVoidAsync("saveItem", "gists", gist);
    }

    public async Task<List<LocalGist>> GetLocalGistsAsync()
    {
        await EnsureModule();
        var gists = await _module!.InvokeAsync<List<LocalGist>>("getAllItems", "gists");
        foreach (var gist in gists)
        {
            if (NormalizeGistCollections(gist))
            {
                await _module!.InvokeVoidAsync("saveItem", "gists", gist);
            }
        }
        return gists;
    }

    public async Task DeleteGistAsync(string id)
    {
        await EnsureModule();
        await _module!.InvokeVoidAsync("deleteItem", "gists", id);
    }

    public async Task SaveGroupAsync(GistGroup group)
    {
        await EnsureModule();
        group.Name = NormalizeGroupName(group.Name);
        group.UpdatedAt = DateTime.UtcNow;
        await _module!.InvokeVoidAsync("saveItem", "groups", group);
    }

    public async Task<List<GistGroup>> GetGroupsAsync()
    {
        await EnsureModule();
        var groups = await _module!.InvokeAsync<List<GistGroup>>("getAllItems", "groups");
        return groups
            .Where(g => !string.IsNullOrWhiteSpace(g.Name))
            .Select(g =>
            {
                g.Name = NormalizeGroupName(g.Name);
                return g;
            })
            .OrderBy(g => g.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public async Task DeleteGroupAsync(string id)
    {
        await EnsureModule();
        await _module!.InvokeVoidAsync("deleteItem", "groups", id);
    }

    private async Task EnsureModule()
    {
        if (_module == null)
        {
            await InitAsync();
        }
    }

    private static bool NormalizeGistCollections(LocalGist gist)
    {
        var changed = false;
        gist.CollectionNames ??= new List<string>();

        if (!string.IsNullOrWhiteSpace(gist.CollectionName))
        {
            var legacyName = NormalizeGroupName(gist.CollectionName);
            if (!ContainsGroupName(gist.CollectionNames, legacyName))
            {
                gist.CollectionNames.Add(legacyName);
                changed = true;
            }
        }

        var cleaned = gist.CollectionNames
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .Select(NormalizeGroupName)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (gist.CollectionNames.Count != cleaned.Count ||
            !gist.CollectionNames.SequenceEqual(cleaned, StringComparer.OrdinalIgnoreCase))
        {
            gist.CollectionNames = cleaned;
            changed = true;
        }

        // Keep legacy field as mirror of first item to avoid breaking old UI code paths.
        var first = gist.CollectionNames.FirstOrDefault();
        if (!string.Equals(gist.CollectionName, first, StringComparison.Ordinal))
        {
            gist.CollectionName = first;
            changed = true;
        }

        return changed;
    }

    private static bool ContainsGroupName(IEnumerable<string> names, string targetName)
        => names.Any(name => string.Equals(name?.Trim(), targetName, StringComparison.OrdinalIgnoreCase));

    private static string NormalizeGroupName(string? name)
        => (name ?? string.Empty).Trim();
}
