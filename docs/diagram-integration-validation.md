# Diagram integration validation

Reviewed: 2026-10-23 (Asia/Rangoon).

The integration uses the documented hosted embed endpoint, not a bundled copy of the draw.io repository. No upstream assets or branding are redistributed. The official documentation explicitly describes embedding this endpoint in another application; this is technical integration evidence, not a contractual service guarantee.

References: [embed protocol](https://www.drawio.com/docs/reference/embed-mode/), [repository distribution and branding notes](https://github.com/jgraph/drawio#running).

Browser spike results:

- The hosted frame loads within the app with the configured sandbox.
- Configuration and initialization complete with the JSON protocol.
- XML snapshot exports return current editable source.
- PNG and SVG exports return image data URIs.
- Export responses echo the request object, including our correlation ID.

Deployment choice: hosted editing requires internet access and sends the selected diagram to a third-party frame. GistHub displays this fact before editing. Local storage and source downloads remain available when the editor cannot load. Offline editor distribution, third-party SLA guarantees, and paid self-hosted deployment are outside this release.

Do not describe local draft persistence as fully offline or private diagram processing. Do not pass access tokens to the editor. Recheck integration behavior when changing the editor endpoint or protocol options.
