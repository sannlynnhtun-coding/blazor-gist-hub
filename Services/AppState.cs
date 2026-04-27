using GistHub.Models;

namespace GistHub.Services;

public class AppState
{
    public GistProfile? CurrentProfile { get; private set; }
    public bool IsAuthenticated => CurrentProfile != null;

    public event Action? OnChange;

    public void SetProfile(GistProfile? profile)
    {
        CurrentProfile = profile;
        NotifyStateChanged();
    }

    private void NotifyStateChanged() => OnChange?.Invoke();
}
