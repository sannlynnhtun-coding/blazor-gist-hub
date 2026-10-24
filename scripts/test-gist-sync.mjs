import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source = readFileSync(new URL('../GistHub/wwwroot/js/indexedDb.js', import.meta.url), 'utf8');
const { mergeSyncedGist } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const cached = { id: 'a', storageKey: 'alice:a', cacheOwnerUsername: 'alice', isSynced: true, isBookmarked: true, bookmarkOrder: 7,
    collectionNames: ['Notes'], collectionName: 'Notes', updated_at: '2026-10-23T00:00:00Z',
    files: { 'note.txt': { content: 'Complete cached note' } } };
const remote = { ...cached, isBookmarked: false, bookmarkOrder: 0, collectionNames: [], collectionName: null,
    updated_at: '2026-10-24T00:00:00Z', files: { 'note.txt': { content: 'Updated remote note' } } };
const merged = mergeSyncedGist(remote, cached);
assert.equal(merged.isBookmarked, true);
assert.equal(merged.bookmarkOrder, 7);
assert.deepEqual(merged.collectionNames, ['Notes']);
assert.equal(merged.files['note.txt'].content, 'Updated remote note');
assert.equal(mergeSyncedGist(remote, { ...cached, isBookmarked: false }).isBookmarked, false, 'A recent unbookmark must also survive sync');
for (const files of [{}, { 'note.txt': { content: null } }, { 'note.txt': { content: 'partial', truncated: true } }]) {
    assert.equal(mergeSyncedGist({ ...remote, files }, cached), cached);
    assert.equal(mergeSyncedGist({ ...remote, files }, undefined), undefined);
}
const draft = { ...cached, isSynced: false };
assert.equal(mergeSyncedGist(remote, draft), draft);
assert.equal(mergeSyncedGist({ ...remote, updated_at: '2026-10-22T00:00:00Z' }, cached), cached);
assert.equal(mergeSyncedGist(remote, undefined), remote);
assert.equal(mergeSyncedGist({ ...remote, files: { 'note.txt': { content: '' } } }, cached).files['note.txt'].content, '', 'An intentional empty remote file is valid');
assert.equal(cached.files['note.txt'].content, 'Complete cached note');
console.log('PASS: sync preserves bookmarks, ordering, collections, drafts and complete notes; accepts valid updates without mutating the cached record.');
