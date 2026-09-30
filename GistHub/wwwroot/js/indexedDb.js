const databaseName = "GistHubDB";
const databaseVersion = 4;

function openDb() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open(databaseName, databaseVersion);
        let upgradeWasBlocked = false;

        request.onupgradeneeded = (event) => {
            const db = event.target.result;
            const transaction = event.target.transaction;

            if (!db.objectStoreNames.contains("profiles")) {
                db.createObjectStore("profiles", { keyPath: "id" });
            }

            if (event.oldVersion < 3 && db.objectStoreNames.contains("gists")) {
                // Version 2 used the gist ID alone as its key. Rebuild the store
                // with an account-qualified key while retaining all existing data.
                const legacyGists = transaction.objectStore("gists");
                const getLegacyGists = legacyGists.getAll();
                getLegacyGists.onsuccess = () => {
                    const records = getLegacyGists.result;
                    db.deleteObjectStore("gists");
                    const scopedGists = db.createObjectStore("gists", { keyPath: "storageKey" });

                    for (const gist of records) {
                        const username = (gist.cacheOwnerUsername || gist.owner?.login || "").trim().toLowerCase();
                        gist.cacheOwnerUsername = username;
                        gist.storageKey = `${username}:${gist.id}`;
                        scopedGists.put(gist);
                    }
                };
            } else if (!db.objectStoreNames.contains("gists")) {
                db.createObjectStore("gists", { keyPath: "storageKey" });
            }

            if (!db.objectStoreNames.contains("groups")) {
                db.createObjectStore("groups", { keyPath: "id" });
            }
        };

        request.onsuccess = () => {
            const db = request.result;
            if (upgradeWasBlocked) {
                db.close();
                return;
            }
            db.onversionchange = () => db.close();
            resolve(db);
        };
        request.onerror = () => reject(request.error);
        request.onblocked = () => {
            upgradeWasBlocked = true;
            reject(new Error("The local database upgrade is blocked by another open GistHub tab."));
        };
    });
}

function runTransaction(storeName, mode, operation) {
    return openDb().then((db) => new Promise((resolve, reject) => {
        let transaction;
        let request;

        try {
            transaction = db.transaction(storeName, mode);
            request = operation(transaction.objectStore(storeName));
        } catch (error) {
            db.close();
            reject(error);
            return;
        }

        transaction.oncomplete = () => {
            const result = request.result;
            db.close();
            resolve(result);
        };
        transaction.onabort = () => {
            const error = transaction.error || request.error || new Error("IndexedDB transaction was aborted.");
            db.close();
            reject(error);
        };
        transaction.onerror = () => {
            // The abort handler reports the underlying request/transaction error.
        };
    }));
}

export async function initDb() {
    const db = await openDb();
    db.close();
    return true;
}

export async function saveItem(storeName, item) {
    await runTransaction(storeName, "readwrite", (store) => store.put(item));
    return true;
}

export function getAllItems(storeName) {
    return runTransaction(storeName, "readonly", (store) => store.getAll());
}

export async function deleteItem(storeName, id) {
    await runTransaction(storeName, "readwrite", (store) => store.delete(id));
    return true;
}
