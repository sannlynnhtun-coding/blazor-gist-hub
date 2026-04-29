export function initDb() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open("GistHubDB", 2);

        request.onupgradeneeded = (event) => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains("profiles")) {
                db.createObjectStore("profiles", { keyPath: "id" });
            }
            if (!db.objectStoreNames.contains("gists")) {
                db.createObjectStore("gists", { keyPath: "id" });
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
        const request = indexedDB.open("GistHubDB", 2);
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
        const request = indexedDB.open("GistHubDB", 2);
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
        const request = indexedDB.open("GistHubDB", 2);
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
