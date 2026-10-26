import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gist_hub_flutter/src/app_state.dart';
import 'package:gist_hub_flutter/src/models.dart';
import 'package:gist_hub_flutter/src/services.dart';
import 'widget_test.dart' show FakeStorage;

void main() {
  test(
    'login and full sync recover resets, persist data and restore the profile',
    () async {
      final storage = FakeStorage();
      var userCalls = 0, fileCalls = 0;
      final api = GithubService(
        MockClient((request) async {
          expect(request.url.host, 'api.github.com');
          expect(request.headers['Authorization'], 'Bearer verification-token');
          if (request.url.path == '/user') {
            if (++userCalls == 1) {
              throw http.ClientException('Connection reset');
            }
            return http.Response('{"login":"verified"}', 200);
          }
          if (request.url.path == '/gists') {
            return http.Response(
              '[{"id":"one","files":{}},{"id":"two","files":{}}]',
              200,
            );
          }
          if (request.url.path == '/gists/one' && ++fileCalls == 1) {
            throw http.ClientException('Connection reset');
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'id': request.url.pathSegments.last,
                'description': 'Verified #dart',
                'files': {
                  'main.dart': {
                    'content': 'မြန်မာ snippet',
                    'filename': 'main.dart',
                  },
                },
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final container = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(storage),
          githubClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.notifier).restore();
      container.listen(gistControllerProvider, (_, _) {});
      expect(
        await container
            .read(sessionControllerProvider.notifier)
            .login('Verified workspace', 'verification-token'),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      await container.read(gistControllerProvider.notifier).sync();
      final state = container.read(gistControllerProvider);
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
      expect(state.loaded, 2);
      expect(state.total, 2);
      expect(state.lastSynced, isNotNull);
      expect(
        state.gists.every((g) => g.firstFile!.content == 'မြန်မာ snippet'),
        isTrue,
      );
      expect(storage.gists['verified']!.length, 2);
      expect(userCalls, 2);
      expect(fileCalls, 2);
      await container.read(sessionControllerProvider.notifier).logout();
      await container
          .read(sessionControllerProvider.notifier)
          .selectProfile(storage.profiles.single);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionControllerProvider).isAuthenticated, isTrue);
      expect(container.read(gistControllerProvider).gists.length, 2);
    },
  );

  test(
    'exhausted sync retries preserve cached bookmarks and report a recoverable error',
    () async {
      var attempts = 0;
      final storage = FakeStorage.seeded(
        gists: [
          const LocalGist(id: 'cached', isBookmarked: true, bookmarkOrder: 3),
        ],
      );
      final api = GithubService(
        MockClient((_) async {
          attempts++;
          throw http.ClientException('Connection reset');
        }),
      );
      final container = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(storage),
          githubClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.notifier).restore();
      container.listen(gistControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await container.read(gistControllerProvider.notifier).sync();
      final state = container.read(gistControllerProvider);
      expect(attempts, 3);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('Cannot reach GitHub'));
      expect(state.gists.single.bookmarkOrder, 3);
      expect(storage.gists['slh']!.single.isBookmarked, isTrue);
    },
  );

  test('rejected login does not save a token or start a sync', () async {
    final storage = FakeStorage();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(storage),
        githubClientProvider.overrideWithValue(
          GithubService(
            MockClient((_) async {
              calls++;
              return http.Response('{"message":"Bad credentials"}', 401);
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(
      await container
          .read(sessionControllerProvider.notifier)
          .login('Test', 'bad'),
      isFalse,
    );
    expect(calls, 1);
    expect(storage.tokens, isEmpty);
    expect(container.read(sessionControllerProvider).isLoading, isFalse);
  });
}
