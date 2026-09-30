# GistHub

GistHub is a Blazor WebAssembly progressive web app for discovering, creating, and organizing GitHub Gists. GitHub is the remote source for gist content, while IndexedDB provides an account-scoped local workspace for cached gists, bookmarks, ordering, and collection assignments.

## Overview

The app supports two complementary workflows:

- Explore public gists as a guest, filter them by language, inspect another user's public gists, and connect a GitHub account when an action requires authentication.
- Manage a personal gist library: create, edit, delete, import, clone, search, bookmark, reorder, and group gists into local collections.

Additional features include a curated SLH collection, Markdown and Mermaid rendering, syntax highlighting, a JSON parser, code-to-image export, light/dark themes, and an installable PWA shell. The Trending page is currently a placeholder.

## Application workflow

1. **Discover** - `/` loads GitHub's public gist feed. A saved token is used when available for authenticated API limits.
2. **Connect GitHub** - `/login` validates a Personal Access Token against GitHub's `/user` endpoint, then saves the named profile in browser IndexedDB.
3. **Build the local cache** - a new profile initially fetches full content for up to 30 gists. Later syncs from **My Gists** refresh the account's cached gists, re-parse tags from descriptions, and preserve local bookmarks, bookmark order, and collection assignments.
4. **Manage gists** - create, edit, delete, clone, or import JSON. These operations call the GitHub API and then update the local cache.
5. **Organize locally** - bookmarks and collections are stored in the browser. They are not written to GitHub or synchronized across browsers/devices.
6. **Resume** - on a later visit, the first saved profile is restored and its account-scoped cache is available immediately.

```text
Blazor pages and components
    |-- GithubService --> GitHub API
    |                     |-- development: https://api.github.com
    |                     `-- production: /api/github via Vercel rewrite
    |
    `-- IndexedDbService --> profiles, account-scoped gists, and groups
```

## Main features

- Public discovery feed and public-gist lookup by GitHub username
- Single and bulk cloning into the connected GitHub account
- Personal gist create, view, edit, delete, sync, and JSON import
- Search by description, file, content, or parsed `#tags`
- Local bookmarks with drag-and-drop ordering and account-scoped JSON backup/restore
- Local multi-collection assignment and collection filtering
- Curated `@sannlynnhtun-coding` public-gist collection
- Markdown, Mermaid, and syntax-highlighted code previews
- JSON formatting/parsing and code-image utilities
- Responsive UI, themes, sound controls, file blur, and PWA support

## Tech stack

- .NET 10 and Blazor WebAssembly
- C# services for GitHub access, state, and browser storage
- IndexedDB through JavaScript interop
- Tailwind CSS 3 with Forms and Typography plugins
- Marked, Mermaid, and highlight.js for rich gist previews
- Vercel for static hosting and the production GitHub API rewrite

## Getting started

### Prerequisites

- [.NET SDK 10.x](https://dotnet.microsoft.com/download)
- [Node.js 20](https://nodejs.org/) and npm
- A GitHub Personal Access Token with permission to read and write gists for authenticated features

### Install and run

From the repository root:

```bash
npm install --prefix GistHub
dotnet run --project GistHub/GistHub.csproj
```

Open the local URL printed by `dotnet run`. The MSBuild project runs the minified Tailwind build automatically before each .NET build.

For UI work, run the CSS watcher and the .NET watcher in separate terminals:

```bash
npm --prefix GistHub run build:css
```

```bash
dotnet watch --project GistHub/GistHub.csproj run
```

## Development workflow

1. Install JavaScript dependencies with `npm install --prefix GistHub`.
2. Run the Tailwind and .NET watchers while editing Razor, C#, or CSS files.
3. Exercise both guest and authenticated paths. GitHub calls go directly to `https://api.github.com` in development.
4. Before opening a pull request, restore and build the same solution used by CI:

   ```bash
   dotnet restore GistHub.slnx
   dotnet build GistHub.slnx --configuration Release --no-restore
   ```

The solution does not currently include an automated .NET test project, so the Release build and focused browser checks are the primary verification steps.

## Routes

| Route | Purpose |
| --- | --- |
| `/` | Public discovery feed and GitHub-user lookup |
| `/login` | Token validation and saved-profile selection |
| `/my-gists` | Cached personal library, sync, search, bookmarks, and import |
| `/editor` | Create a gist |
| `/editor/{GistId}` | Edit a gist |
| `/view/{GistId}` | View a gist from the local workspace |
| `/collections` | Create and manage local gist groups |
| `/slh-collection` | Browse the curated SLH collection |
| `/slh-collection/{GistId}` | View an SLH collection gist |
| `/trending` | Coming-soon placeholder |

## Repository structure

```text
.
|-- GistHub.slnx
|-- GistHub/
|   |-- Components/       Reusable gist cards and utility overlays
|   |-- Layout/           Desktop/mobile navigation and app shell
|   |-- Models/           GitHub and local-workspace data models
|   |-- Pages/            Route-level Razor components
|   |-- Services/         GitHub API, app state, and IndexedDB access
|   `-- wwwroot/          CSS, JavaScript helpers, PWA assets, and Vercel config
`-- .github/workflows/    Build and deployment workflow
```

## Authentication and local data

GistHub does not have its own backend or account system. The browser sends the saved token to GitHub through `GithubService`; in production, requests use the `/api/github` Vercel rewrite.

Profiles currently include the access token and are stored unencrypted in the browser's IndexedDB. Use the app only on a trusted device, grant the token only the permissions it needs, and revoke the token in GitHub if the device or browser profile is compromised. Signing out clears the in-memory session; deleting a saved profile removes that profile record, while previously cached account data may remain locally.

## CI and deployment

The GitHub Actions workflow in `.github/workflows/deploy.yml` runs for pull requests and pushes targeting `main` or `master`:

- Pull requests install dependencies, restore the solution, and run a Release build.
- Branch pushes also publish the Blazor app, copy the Vercel configuration into `publish_output/wwwroot`, and deploy that directory to production.

Deployment requires these repository secrets:

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`
