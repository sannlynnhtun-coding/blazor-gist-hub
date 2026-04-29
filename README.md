# GistHub

## Project Overview
GistHub is a Blazor WebAssembly single-page app for browsing, saving, and managing GitHub Gists from a polished browser-based workspace.
It blends GitHub API integration with local IndexedDB caching so users can explore public snippets, work with their own gists, and revisit saved content with fast client-side navigation.

Core capabilities include:
- Public gist discovery from the home feed
- Personal gist workflows such as create, edit, delete, view, and clone
- GitHub Personal Access Token sign-in with profile-based local persistence
- Local caching of profiles, bookmarks, and gist data for faster repeat access
- Curated SLH collection browsing with dedicated detail pages
- Collection organization plus tag and search-driven filtering
- Persistent theming and a modern responsive UI built for code-heavy content

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

