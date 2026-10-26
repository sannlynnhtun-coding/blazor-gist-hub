import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gist_hub_flutter/src/services.dart';

void main() {
  test('public feeds support guest browsing and encode usernames', () async {
    final service = GithubService(
      MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), false);
        expect(request.url.pathSegments, ['users', 'a name', 'gists']);
        expect(request.url.queryParameters['page'], '2');
        return http.Response(
          jsonEncode([
            {'id': 'a', 'description': 'hello #dart', 'files': {}},
          ]),
          200,
        );
      }),
    );
    final result = await service.publicFeed(username: 'a name', page: 2);
    expect(result.single.tags, ['dart']);
  });
  test('sync fetches every page of personal gists', () async {
    var requests = 0;
    final service = GithubService(
      MockClient((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer token');
        final count = requests == 1 ? 100 : 1;
        return http.Response(
          jsonEncode(
            List.generate(count, (i) => {'id': '${requests}_$i', 'files': {}}),
          ),
          200,
        );
      }),
    );
    expect((await service.getUserGists('token')).length, 101);
    expect(requests, 2);
  });
  test('failed sync is reported instead of returning an empty cache', () async {
    final service = GithubService(
      MockClient(
        (_) async => http.Response('{"message":"Bad credentials"}', 401),
      ),
    );
    await expectLater(service.getUserGists('bad'), throwsStateError);
  });
  test('truncated files fetch raw content without sending the token', () async {
    final service = GithubService(
      MockClient((request) async {
        if (request.url.host == 'gist.githubusercontent.com') {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('full source', 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'a',
            'files': {
              'file.txt': {
                'content': 'partial',
                'truncated': true,
                'raw_url':
                    'https://gist.githubusercontent.com/u/a/raw/file.txt',
              },
            },
          }),
          200,
        );
      }),
    );
    final gist = await service.getGistById('a', 'secret-token');
    expect(gist!.firstFile!.content, 'full source');
    expect(gist.firstFile!.truncated, isFalse);
  });
  test(
    'truncated files cannot redirect tokens or content requests to an untrusted host',
    () async {
      var requests = 0;
      final service = GithubService(
        MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'id': 'a',
              'files': {
                'file.txt': {
                  'truncated': true,
                  'raw_url': 'https://evil.example/source',
                },
              },
            }),
            200,
          );
        }),
      );
      expect(await service.getGistById('a', 'token'), isNull);
      expect(requests, 1);
      expect(service.lastError!.message, contains('Untrusted'));
    },
  );
  test('network errors are actionable and do not escape login', () async {
    final service = GithubService(
      MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(await service.getUserInfo('token'), isNull);
    expect(service.lastError!.message, contains('Cannot reach GitHub'));
    expect(await service.deleteGist('a', 'token'), isFalse);
  });
  test(
    'safe reads recover after connection reset and gateway errors',
    () async {
      var calls = 0;
      final service = GithubService(
        MockClient((request) async {
          calls++;
          if (calls == 1) throw http.ClientException('ERR_CONNECTION_RESET');
          if (calls == 2) return http.Response('gateway error', 502);
          return http.Response('{"login":"verified"}', 200);
        }),
      );
      expect((await service.getUserInfo('test-token'))!.login, 'verified');
      expect(calls, 3);
    },
  );
  test(
    'invalid credentials and writes are never automatically repeated',
    () async {
      var calls = 0;
      final service = GithubService(
        MockClient((_) async {
          calls++;
          return http.Response('{"message":"Bad credentials"}', 401);
        }),
      );
      expect(await service.getUserInfo('bad'), isNull);
      expect(calls, 1);
      final failingWrites = GithubService(
        MockClient((_) async {
          calls++;
          throw http.ClientException('reset');
        }),
      );
      expect(
        await failingWrites.createGist(
          description: 'test',
          isPublic: false,
          files: {},
          token: 'test',
        ),
        isNull,
      );
      expect(calls, 2);
    },
  );
}
