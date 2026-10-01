import { spawn } from "node:child_process";
import { appendFile, cp, mkdtemp, readFile, rm, stat } from "node:fs/promises";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const publishedPath = process.argv[2];
if (!publishedPath) {
  console.error("Usage: node scripts/test-browser-regressions.mjs <published-wwwroot>");
  process.exit(2);
}

const contentTypes = {
  ".css": "text/css",
  ".html": "text/html",
  ".js": "text/javascript",
  ".json": "application/json",
  ".wasm": "application/wasm",
};

const tempRoot = await mkdtemp(path.join(os.tmpdir(), "gist-hub-sri-repro-"));
const siteRoot = path.join(tempRoot, "wwwroot");
await cp(path.resolve(publishedPath), siteRoot, { recursive: true });

// Simulate a non-atomic deployment: the shell changed after the asset manifest was generated.
await appendFile(path.join(siteRoot, "index.html"), "\n<!-- stale-manifest-repro -->\n");

const server = http.createServer(async (request, response) => {
  try {
    const requestPath = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    let filePath = path.resolve(siteRoot, `.${requestPath}`);
    const resolvedSiteRoot = path.resolve(siteRoot);
    if (filePath !== resolvedSiteRoot && !filePath.startsWith(`${resolvedSiteRoot}${path.sep}`)) {
      response.writeHead(403).end();
      return;
    }

    try {
      if ((await stat(filePath)).isDirectory()) filePath = path.join(filePath, "index.html");
    } catch {
      filePath = path.join(siteRoot, "index.html");
    }

    const body = await readFile(filePath);
    response.writeHead(200, {
      "content-type": contentTypes[path.extname(filePath)] ?? "application/octet-stream",
      "cache-control": "no-store",
    });
    response.end(body);
  } catch (error) {
    response.writeHead(500, { "content-type": "text/plain" });
    response.end(error.message);
  }
});

await new Promise((resolve, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", resolve);
});

const { port } = server.address();
const scriptPath = path.join(path.dirname(fileURLToPath(import.meta.url)), "check-browser-errors.mjs");
const check = spawn(process.execPath, [scriptPath, `http://127.0.0.1:${port}/login`], {
  env: {
    ...process.env,
    BROWSER_CHECK_PRESEED_IDB: process.env.BROWSER_CHECK_PRESEED_IDB ?? "1",
    BROWSER_CHECK_UI: process.env.BROWSER_CHECK_UI ?? "1",
    BROWSER_CHECK_WAIT_MS: process.env.BROWSER_CHECK_WAIT_MS ?? "30000",
  },
  stdio: "inherit",
  windowsHide: true,
});

const exitCode = await new Promise((resolve) => check.once("exit", resolve));
await new Promise((resolve) => server.close(resolve));
await rm(tempRoot, { recursive: true, force: true });
process.exitCode = exitCode ?? 1;
