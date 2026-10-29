(() => {
    const changeKey = 'gisthub:backup-revision', downloadedKey = 'gisthub:backup-downloaded';
    let revision = '', downloaded = '';
    const read = (key, fallback) => { try { return localStorage.getItem(key) || fallback; } catch { return fallback; } };
    const notify = () => window.dispatchEvent?.(new Event('gisthub:backup-changed'));
    window.gistHubBackup = {
        revision: () => read(changeKey, revision),
        pending: () => read(changeKey, revision) !== read(downloadedKey, downloaded),
        changed() {
            revision = crypto.randomUUID();
            try { localStorage.setItem(changeKey, revision); } catch { /* Keep the reminder for this session. */ }
            notify();
        },
        setPreference(key, value) {
            if (localStorage.getItem(key) === value) return;
            localStorage.setItem(key, value);
            this.changed();
        },
        downloaded(value) {
            downloaded = value;
            try { localStorage.setItem(downloadedKey, value); } catch { /* Keep the reminder if persistence fails. */ }
            notify();
        }
    };
})();
