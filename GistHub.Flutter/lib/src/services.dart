import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'parsers.dart';

abstract class GithubClient {
  GithubApiError? get lastError;

  Future<GithubUser?> getUserInfo(String token);
  Future<List<LocalGist>> getUserGists(String token);
  Future<LocalGist?> getGistById(String id, String token);
  Future<LocalGist?> createGist({
    required String description,
    required bool isPublic,
    required Map<String, GistFile> files,
    required String token,
  });
  Future<LocalGist?> updateGist({
    required String id,
    required String description,
    required String originalFilename,
    required GistFile file,
    required String token,
  });
  Future<bool> deleteGist(String id, String token);
}

class GithubService implements GithubClient {
  GithubService(this._http)
    : _reads = RetryClient.withDelays(
        _http,
        const [Duration(milliseconds: 300), Duration(milliseconds: 900)],
        when: (response) => const [502, 503, 504].contains(response.statusCode),
        whenError: (error, _) =>
            error is http.ClientException || error is TimeoutException,
      );

  static const _baseUrl = 'https://api.github.com';
  final http.Client _http;
  final http.Client _reads;

  @override
  GithubApiError? lastError;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/vnd.github+json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  @override
  Future<GithubUser?> getUserInfo(String token) async {
    final json = await _sendJson('GET', '/user', token);
    return json is Map<String, Object?> ? GithubUser.fromJson(json) : null;
  }

  @override
  Future<List<LocalGist>> getUserGists(String token) async {
    final result = <LocalGist>[];
    for (var page = 1; ; page++) {
      final json = await _sendJson(
        'GET',
        '/gists?per_page=100&page=$page',
        token,
      );
      if (json is! List) {
        throw StateError(lastError?.message ?? 'Could not load gists.');
      }
      result.addAll(
        json.whereType<Map>().map(
          (item) => _gistFromApi(Map<String, Object?>.from(item)),
        ),
      );
      if (json.length < 100) return result;
    }
  }

  Future<List<LocalGist>> publicFeed({
    String token = '',
    String? username,
    int page = 1,
  }) async {
    final path = username == null
        ? '/gists/public'
        : '/users/${Uri.encodeComponent(username)}/gists';
    final json = await _sendJson('GET', '$path?per_page=30&page=$page', token);
    if (json is! List) {
      throw StateError(lastError?.message ?? 'Could not load gists.');
    }
    return json
        .whereType<Map>()
        .map((e) => _gistFromApi(Map<String, Object?>.from(e)))
        .toList();
  }

  @override
  Future<LocalGist?> getGistById(String id, String token) async {
    final json = await _sendJson('GET', '/gists/$id', token);
    if (json is! Map) return null;
    final gist = _gistFromApi(Map<String, Object?>.from(json));
    final files = {...gist.files};
    for (final entry in files.entries.toList()) {
      final file = entry.value;
      if (!file.truncated) continue;
      final uri = Uri.tryParse(file.rawUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'gist.githubusercontent.com') {
        lastError = const GithubApiError(
          statusCode: null,
          message: 'Untrusted raw gist URL.',
        );
        return null;
      }
      try {
        final response = await _reads
            .get(uri)
            .timeout(const Duration(seconds: 45));
        if (response.statusCode != 200 ||
            response.bodyBytes.length > 20 * 1024 * 1024) {
          throw const FormatException(
            'Could not load full gist content (20 MB limit).',
          );
        }
        files[entry.key] = GistFile(
          filename: file.filename,
          content: utf8.decode(response.bodyBytes),
          language: file.language,
          type: file.type,
          rawUrl: file.rawUrl,
        );
      } catch (e) {
        lastError = GithubApiError(statusCode: null, message: '$e');
        return null;
      }
    }
    return gist.copyWith(files: files);
  }

  @override
  Future<LocalGist?> createGist({
    required String description,
    required bool isPublic,
    required Map<String, GistFile> files,
    required String token,
  }) async {
    final payload = {
      'description': description,
      'public': isPublic,
      'files': files.map(
        (name, file) => MapEntry(name, {'content': file.content}),
      ),
    };

    final json = await _sendJson('POST', '/gists', token, payload: payload);
    return json is Map<String, Object?>
        ? _gistFromApi(json)
        : json is Map
        ? _gistFromApi(Map<String, Object?>.from(json))
        : null;
  }

  @override
  Future<LocalGist?> updateGist({
    required String id,
    required String description,
    required String originalFilename,
    required GistFile file,
    required String token,
  }) async {
    final filePayload = <String, Object?>{'content': file.content};
    if (file.filename.trim() != originalFilename.trim()) {
      filePayload['filename'] = file.filename.trim();
    }

    final json = await _sendJson(
      'PATCH',
      '/gists/$id',
      token,
      payload: {
        'description': description,
        'files': {originalFilename: filePayload},
      },
    );

    return json is Map<String, Object?>
        ? _gistFromApi(json)
        : json is Map
        ? _gistFromApi(Map<String, Object?>.from(json))
        : null;
  }

  @override
  Future<bool> deleteGist(String id, String token) async {
    lastError = null;
    try {
      final response = await _http
          .delete(Uri.parse('$_baseUrl/gists/$id'), headers: _headers(token))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode >= 200 && response.statusCode < 300) return true;

      lastError = GithubApiError.fromResponse(response);
      return false;
    } catch (e) {
      lastError = GithubApiError(
        statusCode: null,
        message:
            'The request could not be confirmed. Check GitHub or sync before trying the change again.',
      );
      return false;
    }
  }

  Future<Object?> _sendJson(
    String method,
    String path,
    String token, {
    Map<String, Object?>? payload,
  }) async {
    lastError = null;
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        ..._headers(token),
        if (payload != null) 'Content-Type': 'application/json',
      };

      final response = switch (method) {
        'GET' =>
          await _reads
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 45)),
        'POST' =>
          await _http
              .post(uri, headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 45)),
        'PATCH' =>
          await _http
              .patch(uri, headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 45)),
        _ => throw ArgumentError('Unsupported method $method'),
      };

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastError = GithubApiError.fromResponse(response);
        return null;
      }

      return response.body.trim().isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      lastError = GithubApiError(
        statusCode: null,
        message: method == 'GET'
            ? 'Cannot reach GitHub. Check your connection and try again. Your local library is safe.'
            : 'The request could not be confirmed. Check GitHub or sync before trying the change again.',
      );
      return null;
    }
  }

  static LocalGist _gistFromApi(Map<String, Object?> json) {
    final gist = LocalGist.fromJson(json);
    return gist.copyWith(tags: parseTags(gist.description));
  }
}

class GithubApiError {
  const GithubApiError({
    required this.statusCode,
    required this.message,
    this.rateLimitReset,
  });

  final int? statusCode;
  final String message;
  final DateTime? rateLimitReset;

  bool get isRateLimited =>
      statusCode == 403 && message.toLowerCase().contains('rate limit') ||
      statusCode == 429;

  factory GithubApiError.fromResponse(http.Response response) {
    var message = response.reasonPhrase ?? 'GitHub API request failed.';
    if (response.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {
        message = response.statusCode >= 500
            ? 'GitHub is temporarily unavailable. Try again shortly.'
            : response.reasonPhrase ?? 'GitHub API request failed.';
      }
    }

    final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
    return GithubApiError(
      statusCode: response.statusCode,
      message: message,
      rateLimitReset: reset == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(reset * 1000),
    );
  }
}

class StoredSession {
  const StoredSession({
    required this.profile,
    required this.token,
    required this.profiles,
  });

  final GistProfile profile;
  final String token;
  final List<GistProfile> profiles;
}

abstract class GistStorage {
  Future<List<GistProfile>> getProfiles();
  Future<StoredSession?> restoreSession();
  Future<void> saveProfile(GistProfile profile, String token);
  Future<void> setActiveProfile(String profileId);
  Future<String?> getToken(String profileId);
  Future<void> deleteProfile(String profileId);
  Future<void> clearActiveProfile();
  Future<List<LocalGist>> getGists(String profileId);
  Future<void> saveGists(String profileId, List<LocalGist> gists);
  Future<void> saveGist(String profileId, LocalGist gist);
  Future<void> deleteGist(String profileId, String gistId);
}

class SharedPreferencesGistStorage implements GistStorage {
  SharedPreferencesGistStorage({
    this._secureStorage = const FlutterSecureStorage(),
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static const profilesKey = 'gist_hub_profiles_v1';
  static const activeProfileKey = 'gist_hub_active_profile_v1';

  static String tokenKey(String profileId) => 'gist_hub_token_$profileId';
  static String gistsKey(String profileId) => 'gist_hub_gists_$profileId';

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _prefsFactory;

  @override
  Future<List<GistProfile>> getProfiles() async {
    final prefs = await _prefsFactory();
    final raw = prefs.getString(profilesKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (profile) => GistProfile.fromJson(Map<String, Object?>.from(profile)),
        )
        .where((profile) => profile.id.isNotEmpty)
        .toList();
  }

  @override
  Future<StoredSession?> restoreSession() async {
    final prefs = await _prefsFactory();
    final profiles = await getProfiles();
    final activeId = prefs.getString(activeProfileKey);
    if (activeId == null) return null;

    final matches = profiles.where((profile) => profile.id == activeId);
    if (matches.isEmpty) return null;

    final token = await getToken(activeId);
    if (token == null || token.isEmpty) return null;

    return StoredSession(
      profile: matches.first,
      token: token,
      profiles: profiles,
    );
  }

  @override
  Future<void> saveProfile(GistProfile profile, String token) async {
    final profiles = await getProfiles();
    final next = [
      for (final item in profiles)
        if (item.id != profile.id) item,
      profile,
    ];
    await _saveProfiles(next);
    await _secureStorage.write(key: tokenKey(profile.id), value: token);
    await setActiveProfile(profile.id);
  }

  @override
  Future<void> setActiveProfile(String profileId) async {
    final prefs = await _prefsFactory();
    await prefs.setString(activeProfileKey, profileId);
  }

  @override
  Future<String?> getToken(String profileId) {
    return _secureStorage.read(key: tokenKey(profileId));
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final prefs = await _prefsFactory();
    final profiles = await getProfiles();
    await _saveProfiles(
      profiles.where((profile) => profile.id != profileId).toList(),
    );
    await _secureStorage.delete(key: tokenKey(profileId));
    await prefs.remove(gistsKey(profileId));
    await prefs.remove('gist_hub_playlists_$profileId');
    if (prefs.getString(activeProfileKey) == profileId) {
      await prefs.remove(activeProfileKey);
    }
  }

  @override
  Future<void> clearActiveProfile() async {
    final prefs = await _prefsFactory();
    await prefs.remove(activeProfileKey);
  }

  @override
  Future<List<LocalGist>> getGists(String profileId) async {
    final prefs = await _prefsFactory();
    final raw = prefs.getString(gistsKey(profileId));
    if (raw == null || raw.trim().isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((gist) => LocalGist.fromJson(Map<String, Object?>.from(gist)))
        .where((gist) => gist.id.isNotEmpty)
        .toList()
      ..sort(_updatedNewestFirst);
  }

  @override
  Future<void> saveGists(String profileId, List<LocalGist> gists) async {
    final prefs = await _prefsFactory();
    final normalized = [...gists]..sort(_updatedNewestFirst);
    await prefs.setString(
      gistsKey(profileId),
      jsonEncode(normalized.map((gist) => gist.toJson()).toList()),
    );
  }

  @override
  Future<void> saveGist(String profileId, LocalGist gist) async {
    final gists = await getGists(profileId);
    final next = [
      for (final item in gists)
        if (item.id != gist.id) item,
      gist,
    ];
    await saveGists(profileId, next);
  }

  @override
  Future<void> deleteGist(String profileId, String gistId) async {
    final gists = await getGists(profileId);
    await saveGists(
      profileId,
      gists.where((gist) => gist.id != gistId).toList(),
    );
  }

  Future<void> _saveProfiles(List<GistProfile> profiles) async {
    final prefs = await _prefsFactory();
    await prefs.setString(
      profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  static int _updatedNewestFirst(LocalGist a, LocalGist b) {
    final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  }
}
