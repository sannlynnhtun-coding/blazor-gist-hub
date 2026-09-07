export function initDb() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open("GistHubDB", 3);

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

        request.onsuccess = () => resolve(true);
        request.onerror = () => reject(request.error);
    });
}

export function saveItem(storeName, item) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open("GistHubDB", 3);
        request.onsuccess = (event) => {
            const db = event.target.result;
            const transaction = db.transaction(storeName, "readwrite");
            const store = transaction.objectStore(storeName);
            store.put(item);
            transaction.oncomplete = () => resolve(true);
            transaction.onerror = () => reject(transaction.error);
        };
    });
}

export function getAllItems(storeName) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open("GistHubDB", 3);
        request.onsuccess = (event) => {
            const db = event.target.result;
            const transaction = db.transaction(storeName, "readonly");
            const store = transaction.objectStore(storeName);
            const getRequest = store.getAll();
            getRequest.onsuccess = () => resolve(getRequest.result);
            getRequest.onerror = () => reject(getRequest.error);
        };
    });
}

export function deleteItem(storeName, id) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open("GistHubDB", 3);
        request.onsuccess = (event) => {
            const db = event.target.result;
            const transaction = db.transaction(storeName, "readwrite");
            const store = transaction.objectStore(storeName);
            store.delete(id);
            transaction.oncomplete = () => resolve(true);
            transaction.onerror = () => reject(transaction.error);
        };
    });
}
