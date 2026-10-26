// Local UI review fixture. Never used by the production entry point.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gist_hub_flutter/main.dart';
import 'package:gist_hub_flutter/src/app_state.dart';
import 'package:gist_hub_flutter/src/models.dart';
import 'widget_test.dart' show FakeStorage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('gist_hub_playlists_demo')) {
    await prefs.setString(
      'gist_hub_playlists_demo',
      '{"Existing collection":["one"]}',
    );
  }
  const profile = GistProfile(
    id: 'demo',
    name: 'Demo workspace',
    githubUsername: 'workspace-demo',
  );
  final state = Uri.base.queryParameters['state'];
  const gists = [
    LocalGist(
      id: 'one',
      description: 'A safer way to validate form input #dart',
      isPublic: true,
      isBookmarked: true,
      bookmarkOrder: 1,
      files: {
        'validator.dart': GistFile(
          filename: 'validator.dart',
          language: 'Dart',
          content:
              'String? validateEmail(String value) {\n  if (!value.contains("@")) return "Check your email";\n  return null;\n}',
        ),
      },
    ),
    LocalGist(
      id: 'two',
      description: 'Small scripts that save a little time #python',
      isPublic: false,
      files: {
        'organize.py': GistFile(
          filename: 'organize.py',
          language: 'Python',
          content:
              'from pathlib import Path\n\nfor file in Path("notes").glob("*.md"):\n    print(file.name)',
        ),
      },
    ),
    LocalGist(
      id: 'three',
      description: 'Find the latest event for every account #sql',
      isPublic: true,
      files: {
        'latest.sql': GistFile(
          filename: 'latest.sql',
          language: 'SQL',
          content:
              'SELECT account_id, MAX(created_at) AS latest\nFROM events\nGROUP BY account_id;',
        ),
      },
    ),
  ];
  assert(gists.map((g) => g.id).toSet().length == gists.length);
  final storage = FakeStorage(
    profiles: state == 'guest' ? [] : [profile],
    activeProfileId: state == 'guest' ? null : 'demo',
    tokens: {'demo': 'fixture-token'},
    gists: {'demo': state == 'empty' ? [] : gists},
  );
  final client = MockClient((request) async {
    assert(request.url.host == 'api.github.com');
    if (request.url.path == '/user') {
      return http.Response('{"login":"workspace-demo"}', 200);
    }
    if (state == 'error') {
      throw http.ClientException('simulated connection reset');
    }
    if (request.url.path == '/gists' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map;
      return http.Response(
        jsonEncode({
          ...body,
          'id': 'published-demo',
          'html_url': 'https://gist.github.com/published-demo',
        }),
        201,
      );
    }
    if (request.url.path == '/gists' ||
        request.url.path == '/gists/public' ||
        request.url.path.startsWith('/users/')) {
      await Future<void>.delayed(const Duration(seconds: 4));
      return http.Response(
        jsonEncode(gists.map((g) => g.toJson()).toList()),
        200,
      );
    }
    final gist = gists.where((g) => request.url.path == '/gists/${g.id}');
    if (gist.isNotEmpty) {
      return http.Response(jsonEncode(gist.first.toJson()), 200);
    }
    return http.Response('{"message":"Unsupported fixture request"}', 404);
  });
  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        httpClientProvider.overrideWithValue(client),
      ],
      child: const GistHubApp(initialLocation: '/gists'),
    ),
  );
}
