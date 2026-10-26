import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gist_hub_flutter/src/app_state.dart';
import 'package:gist_hub_flutter/src/models.dart';
import 'widget_test.dart' show FakeGithub, FakeStorage;

const profileA = GistProfile(id: 'a', name: 'A', githubUsername: 'a');
const profileB = GistProfile(id: 'b', name: 'B', githubUsername: 'b');
const bookmarked = LocalGist(
  id: '1',
  isBookmarked: true,
  bookmarkOrder: 1,
  files: {'readme.md': GistFile(filename: 'readme.md', content: 'cached')},
);

Future<ProviderContainer> setup(FakeStorage storage, FakeGithub api) async {
  final container = ProviderContainer(
    overrides: [
      storageProvider.overrideWithValue(storage),
      githubClientProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionControllerProvider.notifier).restore();
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  container.listen(gistControllerProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'local drafts survive sync, persist across reload, and never fetch from GitHub',
    () async {
      final storage = FakeStorage.seeded(gists: [bookmarked]);
      final c = await setup(storage, SyncGithub());
      final controller = c.read(gistControllerProvider.notifier);
      final draft = await controller.saveDraft(
        description: 'Draft #dart',
        isPublic: false,
        files: {
          'local.dart': const GistFile(
            filename: 'local.dart',
            content: 'local work',
          ),
        },
      );
      expect(LocalGist.fromJson(draft.toJson()).isDraft, isTrue);
      await controller.toggleBookmark(draft.id);
      await controller.sync();
      expect(controller.findById(draft.id)!.firstFile!.content, 'local work');
      expect(controller.findById(draft.id)!.isBookmarked, isTrue);
      expect((await controller.ensureFull(draft.id))!.isDraft, isTrue);
      final reloaded = await setup(storage, FakeGithub());
      expect(
        reloaded
            .read(gistControllerProvider)
            .gists
            .any((g) => g.id == draft.id && g.isDraft),
        isTrue,
      );
    },
  );
  test(
    'publish replaces draft ID and preserves bookmark and old collection data',
    () async {
      final storage = FakeStorage.seeded();
      final c = await setup(storage, FakeGithub());
      final controller = c.read(gistControllerProvider.notifier);
      final draft = await controller.saveDraft(
        description: 'Draft',
        isPublic: false,
        files: {
          'a.txt': const GistFile(filename: 'a.txt', content: 'one'),
          'b.txt': const GistFile(filename: 'b.txt', content: 'two'),
        },
      );
      await controller.toggleBookmark(draft.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'gist_hub_playlists_slh',
        jsonEncode({
          'Existing': [draft.id, 'old-id'],
        }),
      );
      final saved = await controller.publishDraft(draft.id);
      expect(saved!.isDraft, isFalse);
      expect(saved.files.length, 2);
      expect(saved.isBookmarked, isTrue);
      expect(controller.findById(draft.id), isNull);
      expect(jsonDecode(prefs.getString('gist_hub_playlists_slh')!), {
        'Existing': ['created', 'old-id'],
      });
      expect(await controller.publishDraft(draft.id), isNull);
    },
  );
  test(
    'failed publish retains draft and local delete never calls API',
    () async {
      final storage = FakeStorage.seeded();
      final api = DraftFailureGithub();
      final c = await setup(storage, api);
      final controller = c.read(gistControllerProvider.notifier);
      final draft = await controller.saveDraft(
        description: 'keep',
        isPublic: false,
        files: {'a.txt': const GistFile(filename: 'a.txt', content: 'keep me')},
      );
      expect(await controller.publishDraft(draft.id), isNull);
      expect(storage.gists['slh']!.single.firstFile!.content, 'keep me');
      expect(await controller.deleteGist(draft.id), isTrue);
      expect(api.deleted, isFalse);
      expect(storage.gists['slh'], isEmpty);
    },
  );

  test(
    'search matches every term across fields and ranks descriptions first',
    () async {
      final container = await setup(
        FakeStorage.seeded(
          gists: [
            const LocalGist(
              id: 'content',
              description: 'helper',
              files: {
                'file.dart': GistFile(filename: 'file.dart', content: 'needle'),
              },
            ),
            const LocalGist(id: 'description', description: 'needle helper'),
            const LocalGist(id: 'excluded', description: 'needle'),
          ],
        ),
        FakeGithub(),
      );
      final results = container
          .read(gistControllerProvider.notifier)
          .search('needle helper');
      expect(results.map((g) => g.id), ['description', 'content']);
    },
  );
  test(
    'bookmark ordering and restore persist without dropping existing bookmarks',
    () async {
      final storage = FakeStorage.seeded(
        gists: [
          bookmarked,
          const LocalGist(id: '2', isBookmarked: true, bookmarkOrder: 2),
          const LocalGist(id: '3'),
        ],
      );
      final container = await setup(storage, FakeGithub());
      final controller = container.read(gistControllerProvider.notifier);
      await controller.reorderBookmarks(['2', '1']);
      expect(controller.bookmarks.map((g) => g.id), ['2', '1']);
      await controller.restoreBookmarks(
        jsonEncode({
          'format': 'gisthub-bookmarks',
          'version': 1,
          'githubUsername': 'slh',
          'bookmarks': [
            {'gistId': '3', 'order': 1},
          ],
        }),
      );
      expect(controller.bookmarks.map((g) => g.id), ['2', '1', '3']);
      expect(
        storage.gists['slh']!.singleWhere((g) => g.id == '3').bookmarkOrder,
        3,
      );
      await expectLater(
        controller.reorderBookmarks(['1']),
        throwsFormatException,
      );
    },
  );
  test('sync keeps local bookmark order and updated content', () async {
    final storage = FakeStorage.seeded(gists: [bookmarked]);
    final container = await setup(storage, SyncGithub());
    await container.read(gistControllerProvider.notifier).sync();
    final gist = container.read(gistControllerProvider).gists.single;
    expect(gist.isBookmarked, isTrue);
    expect(gist.bookmarkOrder, 1);
    expect(gist.firstFile!.content, 'remote');
  });
  test(
    'a create finishing after profile switch writes only to its original account',
    () async {
      final storage = FakeStorage(
        profiles: [profileA, profileB],
        activeProfileId: 'a',
        tokens: {'a': 'token-a', 'b': 'token-b'},
        gists: {
          'a': [],
          'b': [const LocalGist(id: 'b-gist')],
        },
      );
      final api = DelayedGithub();
      final container = await setup(storage, api);
      final pending = container
          .read(gistControllerProvider.notifier)
          .createGist(
            description: 'A only',
            isPublic: false,
            filename: 'file.txt',
            content: 'A data',
          );
      await container
          .read(sessionControllerProvider.notifier)
          .selectProfile(profileB);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      api.created.complete(const LocalGist(id: 'a-created'));
      await pending;
      expect(storage.gists['a']!.single.id, 'a-created');
      expect(storage.gists['b']!.single.id, 'b-gist');
      expect(container.read(gistControllerProvider).gists.single.id, 'b-gist');
    },
  );
}

class SyncGithub extends FakeGithub {
  @override
  Future<List<LocalGist>> getUserGists(String token) async => [bookmarked];
  @override
  Future<LocalGist?> getGistById(String id, String token) async =>
      const LocalGist(
        id: '1',
        files: {
          'readme.md': GistFile(filename: 'readme.md', content: 'remote'),
        },
      );
}

class DelayedGithub extends FakeGithub {
  final created = Completer<LocalGist?>();
  @override
  Future<LocalGist?> createGist({
    required String description,
    required bool isPublic,
    required Map<String, GistFile> files,
    required String token,
  }) => created.future;
}

class DraftFailureGithub extends FakeGithub {
  bool deleted = false;
  @override
  Future<LocalGist?> createGist({
    required String description,
    required bool isPublic,
    required Map<String, GistFile> files,
    required String token,
  }) async => null;
  @override
  Future<bool> deleteGist(String id, String token) async {
    deleted = true;
    return false;
  }
}
