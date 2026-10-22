# PRD: GistHub Diagram Editor

Date: 2026-10-22 (Asia/Rangoon)

Status: Proposed for discussion; implementation has not started

Target: Existing Blazor WebAssembly app

Entry point: Tools → Diagram Editor → `/tools/diagram-editor`

## 1. Problem and recommendation

GistHub stores code and documentation but has no visual diagram authoring workflow. Users should be able to create a workflow, architecture diagram, or ER diagram, resume it locally, export it, and optionally keep its editable source in a GitHub Gist.

Recommendation: integrate the hosted draw.io editor and build GistHub-owned storage, export presets, and Gist actions around it. Avoid maintaining an editor fork. Prioritize reliable drafts and exports before adding data conversion or template libraries.

This PRD is based on screening the 33 open issue entries visible across the two issue-list pages on the review date, then reading the most relevant issue bodies and selected comments. It is not a review of every closed issue or a reproduction of reported bugs. Issues express requests and reports, not guaranteed capabilities. Status and labels can change.

## 2. Existing app context

- `GistHub/Layout/MainLayout.razor` owns the Tools menu.
- `GistHub/Services/StorageService.cs` provides IndexedDB storage with account-scoped gists.
- `GistHub/Services/GithubService.cs` already creates, retrieves, and updates Gists.
- JSON to Table and Mermaid previews provide useful adjacent workflows.
- The app is a static Blazor PWA. Hosted editor availability must be treated separately from local draft availability.
- Flutter exists as untracked workspace work. This proposal targets Blazor; Flutter parity is a separate scope decision.

## 3. Issue research and product decisions

These recommendations are GistHub product judgments, not statements that draw.io plans to implement them.

| Source | User need | Decision for GistHub | Delivery boundary |
| --- | --- | --- | --- |
| [#5695](https://github.com/jgraph/drawio/issues/5695) | Reuse named export settings | P1: named PNG/SVG presets | Host controls only supported export parameters; no arbitrary DPI promise. The issue is open with a stale-bot `wontfix` label at review time. |
| [#3243](https://github.com/jgraph/drawio/issues/3243) | Retain a draft even before adding shapes | P0: create a local draft as soon as New succeeds | Inspired by a Confluence-specific report; implemented independently in our storage. |
| [#5782](https://github.com/jgraph/drawio/issues/5782) | Build and update graphs from table data | P2: JSON/CSV edge-list generation | Adapt the need to GistHub data; omit Confluence macros, scheduled polling, and automatic synchronization. |
| [#5774](https://github.com/jgraph/drawio/issues/5774) | Organize many pages into groups | P2: group separate diagram documents in the local library | This is an alternative, not equivalent page-tab grouping. Native grouped tabs remain deferred. |
| [#5579](https://github.com/jgraph/drawio/issues/5579) | Resize the editor's right properties panel | P1: collapsible host library panel and fullscreen | Host controls cannot resize a cross-origin editor's internal panel. Exact request remains upstream. |
| [#5245](https://github.com/jgraph/drawio/issues/5245) | More complete C4 container templates | P2: a small developer template pack | Validate template accuracy and asset permissions before shipping. |
| [#5813](https://github.com/jgraph/drawio/issues/5813) | Prevent clipped text during VSDX import | Defer VSDX import; record as compatibility risk | Report concerns a particular importer integration; do not assume every hosted editor reproduces it. |

### Remaining issue-list screening

The following entries were screened by their list summaries; they were not individually reproduced or investigated in depth.

| Issues | Decision |
| --- | --- |
| #5811, #5634, #5174, #604 | Presentation, connector, freehand, and grid behavior belong to the editor; defer host work. |
| #5622, #4977, #3118, #2658, #1525, #1256, #761 | Confluence, SharePoint, Jira, and Teams integrations are outside the app's initial scope. |
| #5503 | Defer Lucidchart conversion and browser-extension integration. |
| #5606, #5605, #5493, #5478, #5451, #5328, #5240, #4899, #1311 | Specialized shape packs are optional future demand; use available built-in libraries first. |
| #5694, #5279, #5261, #4559, #1355 | Specialized geometry, coordinates, units, and master-shape behavior do not justify an editor fork. |

Sources: [open issues, page 1](https://github.com/jgraph/drawio/issues), [page 2](https://github.com/jgraph/drawio/issues?page=2).

## 4. Users, goals, and exclusions

Primary users are developers documenting architecture, people planning workflows, and existing GistHub users keeping diagrams beside snippets.

Goals:

1. Create and recover an editable diagram without a GitHub login.
2. Export a portable source file and a usable image.
3. Save an explicit snapshot to a Gist using existing authentication.
4. Reduce repeated export setup with reusable presets.

Excluded from the proposed releases: real-time collaboration, AI generation, a diagram execution engine, Google Drive/Dropbox integrations, native editor page-tab groups, arbitrary editor plugins, custom geometry fixes, and guaranteed offline editing. A visual workflow does not execute its steps.

## 5. Core journeys

### Local diagram

Open Tools → Diagram Editor → New → name diagram → edit → see local save status → download `.drawio`, PNG, or SVG. Reopening the tool lists saved drafts, including empty drafts. Opening an existing file creates a new local draft rather than overwriting another document implicitly.

### Gist-backed diagram

Open a local draft → Save to Gist → connect GitHub if necessary → choose filename, description, and public/secret visibility for a new Gist → save → show the resulting Gist link. Later saves update the explicitly linked file. Opening someone else's diagram creates a local copy with Save as new Gist available.

### Repeat export

Open Export → choose format and supported options → save a named preset → export. On a later visit, selecting the preset restores those options. Presets do not alter diagram source or Gist visibility.

### Data to diagram, later

Send JSON table data or upload CSV → map source and target columns, with an optional label → validate rows → preview generated diagram → create a new draft. Regeneration creates another draft by default so manual edits survive.

## 6. Functional requirements and acceptance criteria

| ID | Priority | Requirement and acceptance |
| --- | --- | --- |
| D01 | P0 | Tools menu opens the full-page route. Loading, ready, timeout, retry, and unavailable states are distinct. A failed editor load preserves local drafts. |
| D02 | P0 | New, rename, duplicate, open, and delete local diagrams. Empty drafts survive refresh. Deletion requires a clear confirmation naming the document. |
| D03 | P0 | Autosave received edits locally after a proposed 1-second debounce. Display Saving, Saved locally with time, or Save failed; success appears only after persistence completes. Pending writes must not overwrite a newer revision. |
| D04 | P0 | Import `.drawio` and supported diagram XML. Reject malformed or oversized input with an actionable error and preserve the current document. Proposed initial limit: 5 MiB UTF-8 source. Preserve all pages on round trip. |
| D05 | P0 | Download current editable source and export PNG/SVG. Export captures current editor state, handles errors/timeouts, and never downloads an empty success file. Source round trip preserves labels, connectors, layout, and pages. |
| D06 | P0 | Guest and signed-in drafts are isolated. Switching profiles opens the correct library and flushes writes to the original owner. Guest drafts move to a profile only through an explicit copy action. |
| D07 | P0 | Warn on navigation when edits are not safely stored. Browser-close recovery is limited to the latest completed save; do not rely on unload events to finish async writes. Detect competing tabs and offer a copy instead of silently replacing newer content. |
| D08 | P1 | Create/open/update `.drawio` Gist files. Preserve unrelated files. Saving requires an explicit user action; local autosave never writes to GitHub. Failed or ambiguous remote writes retain the draft and permit checking the remote result before retrying creation. |
| D09 | P1 | Record the remote baseline and check it before updates. If remote content changed, offer reload or save a new copy. Do not claim atomic conflict protection until the GitHub API behavior is verified. Existing Gist visibility is displayed; no unsupported visibility change is offered. |
| D10 | P1 | Create, select, rename, and delete local export presets. PNG options: scale, border, transparent background, current page. SVG options: border and current page. Store only validated supported fields. No DPI control until output metadata and rendering are verified. |
| D11 | P1 | Fullscreen and collapsible host library panel keep the canvas usable. Host controls work with keyboard navigation and expose labels, focus states, and save announcements. Phone layouts prioritize opening, saving, and export; complex editing is best on desktop/tablet. |
| D12 | P2 | Import edge lists from CSV/JSON with source/target mapping. Validate missing fields and duplicate node identities. Support cycles and disconnected nodes. Proposed limits: 500 nodes and 1,000 edges, with explicit validation errors. |
| D13 | P2 | Search local diagrams by title; optional local document groups. Grouping metadata never claims to change draw.io's internal page tabs. |
| D14 | P2 | Starter templates: workflow, ER, and C4-style architecture. Templates load as independent drafts; validate shapes and retain required attribution. |

## 7. Proposed integration

Use the [official embed protocol](https://www.drawio.com/docs/reference/embed-mode/) at `https://embed.diagrams.net` with JSON messaging. The documented protocol supports loading source, autosave events, save events, and export actions. Implement a small JavaScript bridge with a Blazor service; use protocol messages rather than reaching into iframe DOM.

Proposed components: `DiagramEditor.razor`, `DiagramService.cs`, `DiagramStorageService.cs`, and `wwwroot/js/diagramEditor.js`. Extend the Tools menu and add separate IndexedDB stores with a versioned, non-destructive migration.

Proposed records:

- Diagram: schema version, local ID, owner scope, title, XML, revision, created/updated times, optional group ID, optional Gist ID/file/remote baseline, last remote save time.
- Export preset: schema version, ID, owner scope, name, format, validated options.
- Local group, if P2 ships: ID, owner scope, name, order.

Keep XML as the canonical editable source. Persist local and remote save states separately. In P1, retain the app's existing gist cache and collection behavior; do not automatically enroll every local diagram into gist collections.

## 8. Privacy, reliability, and constraints

- Explain that editing loads a third-party hosted editor and sends the chosen diagram to that frame. Local autosave describes storage location, not fully offline processing.
- Never send GitHub credentials or unrelated cached gists to the frame. Validate message origin, source window, schema, sizes, and operation identity; discard late responses for another document.
- Treat imported XML, labels, links, and export output as untrusted. Do not inject diagram SVG directly into the host DOM. Validate outgoing links and safely handle downloads.
- Use appropriate frame and content security policies, tested against actual save/export behavior. Remove listeners and references when the editor closes.
- Storage quota failures leave the current editor content intact and offer source download. Device/browser storage deletion can remove local drafts; expose export as the backup path.
- Hosted editor updates may change behavior. Run integration smoke checks before releases and avoid undocumented editor internals.
- Proposed release targets: local library opens within 1 second for 100 drafts on the agreed test device; a completed autosave appears within 2 seconds after the last event under normal storage conditions. Editor startup depends on network; show retry after a proposed 20-second timeout.

## 9. Delivery tasks and validation

Each row is a separate task and conventional commit, pushed after relevant checks pass. No implementation dates are committed by this PRD.

| Task | Deliverable | Suggested commit |
| --- | --- | --- |
| 1 | Embed compatibility spike; verify exports, errors, and hosting terms | `chore(diagrams): validate editor integration` |
| 2 | P0 route, bridge, local library, drafts, import/export | `feat(diagrams): add local diagram editor` |
| 3 | P1 Gist open/save and remote-change handling | `feat(diagrams): connect diagrams to GitHub Gists` |
| 4 | P1 named export presets and host layout controls | `feat(diagrams): add export presets and canvas controls` |
| 5 | Optional P2 JSON/CSV graph generation | `feat(diagrams): generate diagrams from table data` |
| 6 | Optional P2 groups and verified templates | `feat(diagrams): add document groups and templates` |

P0 release checks: solution Release build; focused bridge tests for wrong-origin messages, stale responses, timeouts, and disposal; browser checks for empty-draft refresh, account switching, quota failure, source round trip, multi-page preservation, PNG/SVG output, and navigation recovery.

P1 adds checks for unrelated Gist-file preservation, rejected token/rate-limit handling, remote change detection, ambiguous create outcomes, preset persistence, fullscreen, keyboard focus, and narrow layouts. P2 adds invalid-row/limit tests and confirms regeneration retains manual edits.

Success gates: all applicable acceptance criteria pass; no known data-loss case; no token appears in iframe messages. Track usability through a short manual trial covering create → recover → export and Gist open → edit → save. Production analytics are not required for the initial release.

## 10. Decisions to resolve during implementation

1. Confirm hosted service suitability and deployment terms before release. The [repository README](https://github.com/jgraph/drawio#running) currently describes the repository as a test distribution and directs production deployments toward a paid version. Source, stencil, and trademark terms are distinct; do not assume source licensing grants hosted-service or branding rights.
2. Validate the proposed import and graph-size limits on supported devices.
3. Verify current GitHub update/conflict semantics before promising conflict guarantees.
4. Confirm whether P2 data generation has enough user demand to precede templates or grouping.
5. Decide Flutter parity separately after the Blazor workflow is validated.

Recommended first release: P0 local diagram editing, recovery, and file export. Recommended follow-up: Gist integration and export presets. Keep native tab groups, internal sidebar changes, specialized libraries, and upstream importer fixes outside our implementation scope.
