import { spawn } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";

const url = process.argv[2];
const waitMs = Number.parseInt(process.env.BROWSER_CHECK_WAIT_MS ?? "15000", 10);
const browserPath = process.env.CHROME_PATH
  ?? (process.platform === "win32"
    ? "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
    : "google-chrome");

if (!url) {
  console.error("Usage: node scripts/check-browser-errors.mjs <url>");
  process.exit(2);
}

const errorPatterns = [
  /One of the specified object stores was not found/i,
  /SRI's integrity checks failed/i,
  /Password field is not contained in a form/i,
];

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function reservePort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  return port;
}

async function waitForDebugger(port) {
  const endpoint = `http://127.0.0.1:${port}/json/version`;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    try {
      const response = await fetch(endpoint);
      if (response.ok) return response.json();
    } catch {
      // Chrome has not opened its debugging endpoint yet.
    }
    await delay(100);
  }
  throw new Error("Chrome DevTools endpoint did not become ready");
}

const port = await reservePort();
const profilePath = await mkdtemp(path.join(os.tmpdir(), "gist-hub-browser-check-"));
const chrome = spawn(browserPath, [
  "--headless=new",
  "--disable-gpu",
  "--disable-background-networking",
  "--enable-logging=stderr",
  "--no-first-run",
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profilePath}`,
  "about:blank",
], { stdio: ["ignore", "pipe", "pipe"], windowsHide: true });

let socket;
try {
  const debuggerInfo = await waitForDebugger(port);
  socket = new WebSocket(debuggerInfo.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  let nextId = 0;
  const pending = new Map();
  const observedMessages = [];
  let resolvePageSession;
  const pageSession = new Promise((resolve) => { resolvePageSession = resolve; });
  let targetPageId;
  const attachedPageSessions = new Map();

  chrome.stdout.on("data", (chunk) => observedMessages.push(chunk.toString()));
  chrome.stderr.on("data", (chunk) => observedMessages.push(chunk.toString()));

  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });

  socket.addEventListener("message", ({ data }) => {
    const message = JSON.parse(data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
      return;
    }

    if (message.method === "Runtime.exceptionThrown") {
      const details = message.params.exceptionDetails;
      observedMessages.push(details.exception?.description ?? details.text ?? "");
    } else if (message.method === "Runtime.consoleAPICalled") {
      observedMessages.push(message.params.args.map((argument) => argument.value ?? argument.description ?? "").join(" "));
    } else if (message.method === "Log.entryAdded") {
      observedMessages.push(message.params.entry.text ?? "");
    } else if (message.method === "Network.responseReceived"
      && message.params.type === "Document") {
      observedMessages.push(`Document ${message.params.response.status} ${message.params.response.url}`);
    } else if (message.method === "Target.attachedToTarget") {
      const { sessionId, targetInfo } = message.params;
      void send("Runtime.enable", {}, sessionId).catch(() => {});
      void send("Log.enable", {}, sessionId).catch(() => {});
      if (targetInfo.type === "page") {
        attachedPageSessions.set(targetInfo.targetId, sessionId);
        void send("Page.enable", {}, sessionId).catch(() => {});
        if (targetInfo.targetId === targetPageId) resolvePageSession(sessionId);
      }
    }
  });

  await send("Target.setAutoAttach", {
    autoAttach: true,
    waitForDebuggerOnStart: false,
    flatten: true,
  });
  const createdPage = await send("Target.createTarget", { url: "about:blank" });
  targetPageId = createdPage.targetId;
  if (attachedPageSessions.has(targetPageId)) {
    resolvePageSession(attachedPageSessions.get(targetPageId));
  }
  const sessionId = await pageSession;
  await Promise.all([
    send("Runtime.enable", {}, sessionId),
    send("Log.enable", {}, sessionId),
    send("Page.enable", {}, sessionId),
    send("Network.enable", {}, sessionId),
  ]);

  if (process.env.BROWSER_CHECK_PRESEED_IDB === "1") {
    const metadataUrl = new URL("/manifest.webmanifest", url).href;
    await send("Page.navigate", { url: metadataUrl }, sessionId);
    await delay(500);
    await send("Runtime.evaluate", {
      expression: `(async () => {
        await new Promise((resolve, reject) => {
          const request = indexedDB.deleteDatabase("GistHubDB");
          request.onerror = () => reject(request.error);
          request.onsuccess = resolve;
        });
        await new Promise((resolve, reject) => {
          const request = indexedDB.open("GistHubDB", 3);
          request.onerror = () => reject(request.error);
          request.onsuccess = () => {
            request.result.close();
            resolve();
          };
        });
      })()`,
      awaitPromise: true,
    }, sessionId);
  }
  await send("Page.navigate", { url }, sessionId);
  await delay(waitMs);

  const verificationFailures = [];
  if (process.env.BROWSER_CHECK_PRESEED_IDB === "1") {
    const databaseSnapshot = await send("Runtime.evaluate", {
      expression: `(async () => {
        const databases = await indexedDB.databases();
        return Promise.all(databases.map((database) => new Promise((resolve, reject) => {
          const request = indexedDB.open(database.name);
          request.onerror = () => reject(request.error);
          request.onsuccess = () => {
            const stores = Array.from(request.result.objectStoreNames);
            request.result.close();
            resolve({ ...database, stores });
          };
        })));
      })()`,
      awaitPromise: true,
      returnByValue: true,
    }, sessionId);
    const databases = databaseSnapshot.result.value;
    const database = databases.find((candidate) => candidate.name === "GistHubDB");
    const expectedStores = ["gists", "groups", "profiles"];
    if (!database || database.version < 4
      || expectedStores.some((store) => !database.stores.includes(store))) {
      verificationFailures.push(`IndexedDB schema repair failed: ${JSON.stringify(database ?? null)}`);
    }
  }

  const failures = [...new Set([
    ...observedMessages.filter((message) => errorPatterns.some((pattern) => pattern.test(message))),
    ...verificationFailures,
  ])];

  if (failures.length > 0) {
    console.error(`Browser regression check failed for ${url}`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exitCode = 1;
  } else {
    console.log(`Browser regression check passed for ${url}`);
  }
} finally {
  if (socket?.readyState === WebSocket.OPEN) socket.close();
  chrome.kill();
  await delay(250);
  await rm(profilePath, { recursive: true, force: true });
}
