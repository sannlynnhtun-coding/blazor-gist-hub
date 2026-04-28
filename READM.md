# GistHub

## Project Overview
GistHub is a Blazor WebAssembly app for discovering, managing, and cloning GitHub Gists.  
It combines cloud sync through the GitHub API with local caching in IndexedDB, so users can keep working with their gist library quickly from the browser.

The app supports:
- Public gist discovery feed
- Personal gist management (create, edit, delete, bookmark)
- Profile-based login using GitHub Personal Access Tokens
- Local storage for profiles and gist cache
- Curated SLH collection browsing and one-click cloning
- Collection-style grouping and tag/search filtering
- Light/dark theme toggle with persisted preference

## Tech Stack
- .NET `10.0` (Blazor WebAssembly)
- C# services for state, storage, and GitHub API calls
- Tailwind CSS (`tailwindcss`, `@tailwindcss/forms`, `@tailwindcss/typography`)
- JavaScript interop for IndexedDB (`wwwroot/js/indexedDb.js`)

## Main Routes
- `/` - Discovery feed (public gists)
- `/login` - Token-based profile login
- `/my-gists` - User gist dashboard and sync
- `/editor` and `/editor/{GistId}` - Create/edit gist
- `/view/{GistId}` - View user gist details
- `/collections` - Grouped local collections
- `/slh-collection` and `/slh-collection/{GistId}` - SLH curated collection
- `/trending` - Placeholder for trending logic

## Project Structure
- `Pages/` - Route-based screens
- `Components/` - Reusable UI (including `GistCard` and theme toggle)
- `Layout/` - App shell and navigation
- `Services/` - `GithubService`, `IndexedDbService`, and shared app state
- `Models/` - Gist and profile models
- `wwwroot/` - Static assets, JS helpers, and compiled CSS output

## Local Development
### Prerequisites
- .NET SDK `10.x`
- Node.js `18+` and npm

### Install
```bash
npm install
```

### Run
```bash
dotnet run
```

Notes:
- The project runs a Tailwind build automatically before .NET build (`npm run release:css` via `GistHub.csproj`).
- For iterative CSS work, you can run:
```bash
npm run build:css
```

## Authentication Notes
- Login is done with a GitHub Personal Access Token.
- For gist operations, token permissions must allow gist read/write access.
- Tokens and cached gist data are stored locally in browser IndexedDB.

