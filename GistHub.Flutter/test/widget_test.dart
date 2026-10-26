import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gist_hub_flutter/main.dart';
import 'package:gist_hub_flutter/src/app_state.dart';
import 'package:gist_hub_flutter/src/models.dart';
import 'package:gist_hub_flutter/src/services.dart';

void main() {
  testWidgets('Flutter navigation excludes the removed downloader', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      storage: FakeStorage.seeded(),
      initialLocation: '/account',
    );
    expect(find.text('YouTube Downloader'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('YouTube Downloader'), findsNothing);
    expect(find.text('My library'), findsWidgets);
  });
  testWidgets('removed downloader URL resolves to page not found', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      storage: FakeStorage(),
      initialLocation: '/tools/youtube-downloader',
    );
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets(
    'discovery language selector stays valid when switching profiles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode(
            calls == 1
                ? [
                    {
                      'id': 'feed-one',
                      'description': 'A useful snippet',
                      'files': {
                        'a.dart': {'filename': 'a.dart', 'language': 'Dart'},
                      },
                    },
                  ]
                : [],
          ),
          200,
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageProvider.overrideWithValue(FakeStorage()),
            httpClientProvider.overrideWithValue(client),
          ],
          child: const GistHubApp(initialLocation: '/discovery'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A useful snippet'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dart').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse a GitHub profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'another-user');
      await tester.tap(find.byTooltip('Find profile snippets'));
      await tester.pumpAndSettle();
      expect(find.text('No snippets found.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile library shows snippets early and keeps optional filters usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpApp(
        tester,
        storage: FakeStorage.seeded(
          gists: [
            _gist('1', 'Dart helper #dart', 'main.dart', 'void main() {}'),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.text('Dart helper #dart')).dy,
        lessThan(440),
      );
      expect(find.text('Local drafts'), findsNothing);
      await tester.tap(find.byKey(const Key('library-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local drafts'));
      await tester.pumpAndSettle();
      expect(find.text('No matching snippets'), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-filters')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Dart helper #dart'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prototype mobile navigation keeps existing collections and saved data',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'gist_hub_playlists_slh': '{"Existing collection":["1","missing"]}',
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = FakeStorage.seeded(
        gists: [_gist('1', 'Legacy snippet', 'old.txt', 'kept')],
      );
      await _pumpApp(tester, storage: storage, initialLocation: '/collections');
      expect(find.text('Existing collection'), findsOneWidget);
      expect(find.text('Existing collection (1)'), findsOneWidget);
      await tester.tap(find.text('Existing collection'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy snippet'), findsOneWidget);
      await tester.tap(find.text('Legacy snippet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Existing collection'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('Legacy snippet'), findsNothing);
      expect(storage.gists['slh']!.single.id, '1');
      await tester.tap(find.text('Saved').last);
      await tester.pumpAndSettle();
      expect(find.text('Legacy snippet'), findsNothing);
      expect(find.text('No snippets in this collection.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('local draft UI saves then publishes without losing content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = FakeStorage.seeded();
    await _pumpApp(tester, storage: storage, initialLocation: '/gists/new');
    await tester.enterText(find.byType(TextField).first, 'Local notes #dart');
    await tester.enterText(find.byType(TextField).last, 'draft content');
    await tester.tap(find.text('Save local draft'));
    await tester.pumpAndSettle();
    expect(storage.gists['slh']!.single.isDraft, isTrue);
    expect(find.text('Local draft - not published to GitHub'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit / publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit / publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-editor-button')));
    await tester.pumpAndSettle();
    expect(storage.gists['slh']!.single.isDraft, isFalse);
    expect(storage.gists['slh']!.single.firstFile!.content, 'draft content');
    expect(tester.takeException(), isNull);
  });
  testWidgets('editor navigation asks before discarding unsaved work', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      storage: FakeStorage.seeded(),
      initialLocation: '/gists/new',
    );
    await tester.enterText(find.byType(TextField).first, 'Unsaved work');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved work'), findsOneWidget);
  });

  testWidgets('signed-in users can manage saved profiles', (tester) async {
    await _pumpApp(
      tester,
      storage: FakeStorage.seeded(),
      initialLocation: '/login',
    );
    expect(find.text('Saved Profiles'), findsOneWidget);
  });
  testWidgets('global search opens with Ctrl K', (tester) async {
    await _pumpApp(tester, storage: FakeStorage.seeded());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Search gists'), findsOneWidget);
  });
  testWidgets('tools format escaped JSON and show nested table fields', (
    tester,
  ) async {
    await _pumpApp(tester, storage: FakeStorage(), initialLocation: '/tools');
    await tester.enterText(
      find.byType(TextField).first,
      r'{\"name\":\"test\"}',
    );
    await tester.tap(find.text('Format JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"name": "test"'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      '[{"name":"test","nested":{"x":1}}]',
    );
    await tester.tap(find.text('JSON table'));
    await tester.pumpAndSettle();
    expect(find.text('Choose object / array fields'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Export CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone layout and code-image controls render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(
      tester,
      storage: FakeStorage(),
      initialLocation: '/tools/code-image',
    );
    expect(find.text('Code to image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('guest can open home and developer tools', (tester) async {
    await _pumpApp(tester, storage: FakeStorage(), initialLocation: '/');
    expect(find.text('Your code. Within reach.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open developer tools'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open developer tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open developer tools'));
    await tester.pumpAndSettle();
    expect(find.text('Developer tools'), findsOneWidget);
    expect(find.text('Format JSON'), findsOneWidget);
  });

  testWidgets('auth guard redirects protected routes to login', (tester) async {
    await _pumpApp(tester, storage: FakeStorage());

    expect(find.text('GistHub'), findsOneWidget);
    expect(find.text('Verify and Connect'), findsOneWidget);
  });

  testWidgets('login validation shows required field error', (tester) async {
    await _pumpApp(tester, storage: FakeStorage());

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Please fill in all fields.'), findsOneWidget);
  });

  testWidgets('gist search filters cards and bookmark toggles local cache', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final storage = FakeStorage.seeded(
      gists: [
        _gist('1', 'Dart helper #dart', 'main.dart', 'void main() {}'),
        _gist('2', 'Python notes #python', 'tool.py', 'print("hi")'),
      ],
    );

    await _pumpApp(tester, storage: storage);

    expect(find.text('Dart helper #dart'), findsOneWidget);
    expect(find.text('Python notes #python'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('gist-search-field')),
      'python',
    );
    await tester.pumpAndSettle();

    expect(find.text('Dart helper #dart'), findsNothing);
    expect(find.text('Python notes #python'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Bookmark').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark').first);
    await tester.pumpAndSettle();

    expect(
      storage.gists['slh']!.singleWhere((gist) => gist.id == '2').isBookmarked,
      isTrue,
    );

    await tester.tap(find.byTooltip('Share').first);
    await tester.pump();

    expect(copiedText, 'https://gist.github.com/2');
  });

  testWidgets('theme defaults to dark mode and toggles to light mode', (
    tester,
  ) async {
    await _pumpApp(tester, storage: FakeStorage.seeded());

    expect(find.byTooltip('Light mode'), findsOneWidget);

    await tester.tap(find.byTooltip('Light mode'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Dark mode'), findsOneWidget);
  });

  testWidgets('editor validates required content', (tester) async {
    await _pumpApp(
      tester,
      storage: FakeStorage.seeded(),
      initialLocation: '/gists/new',
    );

    await tester.tap(find.byKey(const Key('save-editor-button')));
    await tester.pumpAndSettle();

    expect(find.text('Filename and content are required.'), findsOneWidget);
  });

  testWidgets('new snippet defaults filename to README.md', (tester) async {
    await _pumpApp(
      tester,
      storage: FakeStorage.seeded(),
      initialLocation: '/gists/new',
    );

    expect(find.text('README.md'), findsOneWidget);
  });

  testWidgets('import dialog validates empty JSON', (tester) async {
    await _pumpApp(tester, storage: FakeStorage.seeded());

    await tester.tap(find.byTooltip('Paste JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Paste JSON content first.'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeStorage storage,
  String initialLocation = '/gists',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        githubClientProvider.overrideWithValue(FakeGithub()),
      ],
      child: GistHubApp(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

LocalGist _gist(
  String id,
  String description,
  String filename,
  String content,
) {
  return LocalGist(
    id: id,
    description: description,
    isPublic: true,
    updatedAt: DateTime.utc(2026, 1, int.parse(id)),
    tags: description
        .split(' ')
        .where((word) => word.startsWith('#'))
        .map((word) => word.substring(1))
        .toList(),
    files: {filename: GistFile(filename: filename, content: content)},
  );
}

class FakeGithub implements GithubClient {
  @override
  GithubApiError? lastError;

  @override
  Future<LocalGist?> createGist({
    required String description,
    required bool isPublic,
    required Map<String, GistFile> files,
    required String token,
  }) async {
    return LocalGist(
      id: 'created',
      description: description,
      isPublic: isPublic,
      files: files,
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<bool> deleteGist(String id, String token) async => true;

  @override
  Future<LocalGist?> getGistById(String id, String token) async {
    return _gist(id, 'Fetched gist #dart', 'main.dart', 'void main() {}');
  }

  @override
  Future<GithubUser?> getUserInfo(String token) async {
    return const GithubUser(
      login: 'slh',
      name: 'Sann Lynn Htun',
      avatarUrl: '',
    );
  }

  @override
  Future<List<LocalGist>> getUserGists(String token) async => const [];

  @override
  Future<LocalGist?> updateGist({
    required String id,
    required String description,
    required String originalFilename,
    required GistFile file,
    required String token,
  }) async {
    return LocalGist(
      id: id,
      description: description,
      isPublic: true,
      files: {file.filename: file},
      updatedAt: DateTime.utc(2026),
    );
  }
}

class FakeStorage implements GistStorage {
  FakeStorage({
    List<GistProfile> profiles = const [],
    this.activeProfileId,
    Map<String, String>? tokens,
    Map<String, List<LocalGist>>? gists,
  }) : profiles = [...profiles],
       tokens = {...?tokens},
       gists = {
         for (final entry
             in (gists ?? const <String, List<LocalGist>>{}).entries)
           entry.key: [...entry.value],
       };

  factory FakeStorage.seeded({List<LocalGist> gists = const []}) {
    const profile = GistProfile(
      id: 'slh',
      name: 'Personal Snippets',
      githubUsername: 'slh',
    );
    return FakeStorage(
      profiles: const [profile],
      activeProfileId: 'slh',
      tokens: const {'slh': 'token'},
      gists: {'slh': gists},
    );
  }

  final List<GistProfile> profiles;
  String? activeProfileId;
  final Map<String, String> tokens;
  final Map<String, List<LocalGist>> gists;

  @override
  Future<void> clearActiveProfile() async {
    activeProfileId = null;
  }

  @override
  Future<void> deleteGist(String profileId, String gistId) async {
    gists[profileId] = [
      for (final gist in gists[profileId] ?? const <LocalGist>[])
        if (gist.id != gistId) gist,
    ];
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    profiles.removeWhere((profile) => profile.id == profileId);
    tokens.remove(profileId);
    gists.remove(profileId);
    if (activeProfileId == profileId) activeProfileId = null;
  }

  @override
  Future<List<LocalGist>> getGists(String profileId) async {
    return [...gists[profileId] ?? const <LocalGist>[]];
  }

  @override
  Future<List<GistProfile>> getProfiles() async => [...profiles];

  @override
  Future<String?> getToken(String profileId) async => tokens[profileId];

  @override
  Future<StoredSession?> restoreSession() async {
    final id = activeProfileId;
    if (id == null) return null;
    final profileMatches = profiles.where((profile) => profile.id == id);
    final token = tokens[id];
    if (profileMatches.isEmpty || token == null) return null;
    return StoredSession(
      profile: profileMatches.first,
      token: token,
      profiles: [...profiles],
    );
  }

  @override
  Future<void> saveGist(String profileId, LocalGist gist) async {
    final current = await getGists(profileId);
    gists[profileId] = [
      for (final item in current)
        if (item.id != gist.id) item,
      gist,
    ];
  }

  @override
  Future<void> saveGists(String profileId, List<LocalGist> next) async {
    gists[profileId] = [...next];
  }

  @override
  Future<void> saveProfile(GistProfile profile, String token) async {
    profiles.removeWhere((item) => item.id == profile.id);
    profiles.add(profile);
    tokens[profile.id] = token;
    activeProfileId = profile.id;
  }

  @override
  Future<void> setActiveProfile(String profileId) async {
    activeProfileId = profileId;
  }
}
