import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'parsers.dart';
import 'services.dart';
import 'tool_utils.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final githubClientProvider = Provider<GithubClient>(
  (ref) => GithubService(ref.watch(httpClientProvider)),
);

final storageProvider = Provider<GistStorage>(
  (ref) => SharedPreferencesGistStorage(),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final gistControllerProvider = NotifierProvider<GistController, GistState>(
  GistController.new,
);

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

final collectionsRevisionProvider = NotifierProvider<CollectionsRevision, int>(
  CollectionsRevision.new,
);

class CollectionsRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

class ThemeModeController extends Notifier<ThemeMode> {
  static const _themeModeKey = 'gist_hub_theme_mode_v1';

  @override
  ThemeMode build() {
    Future.microtask(_restore);
    return ThemeMode.dark;
  }

  Future<void> toggle() async {
    await setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, state.name);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModeKey);
    if (ref.mounted) {
      state = saved == ThemeMode.light.name ? ThemeMode.light : ThemeMode.dark;
    }
  }
}

class SessionState {
  const SessionState({
    required this.isRestoring,
    required this.isLoading,
    required this.profiles,
    this.profile,
    this.token,
    this.error,
  });

  const SessionState.initial()
    : isRestoring = true,
      isLoading = false,
      profiles = const [],
      profile = null,
      token = null,
      error = null;

  final bool isRestoring;
  final bool isLoading;
  final List<GistProfile> profiles;
  final GistProfile? profile;
  final String? token;
  final String? error;

  bool get isAuthenticated => profile != null && token != null;

  SessionState copyWith({
    bool? isRestoring,
    bool? isLoading,
    List<GistProfile>? profiles,
    GistProfile? profile,
    String? token,
    String? error,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return SessionState(
      isRestoring: isRestoring ?? this.isRestoring,
      isLoading: isLoading ?? this.isLoading,
      profiles: profiles ?? this.profiles,
      profile: clearProfile ? null : profile ?? this.profile,
      token: clearProfile ? null : token ?? this.token,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState.initial();
  }

  Future<void> restore() async {
    try {
      final storage = ref.read(storageProvider);
      final profiles = await storage.getProfiles();
      final stored = await storage.restoreSession();

      if (stored == null) {
        state = state.copyWith(
          isRestoring: false,
          profiles: profiles,
          clearProfile: true,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        isRestoring: false,
        profiles: stored.profiles,
        profile: stored.profile,
        token: stored.token,
        clearError: true,
      );
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          isRestoring: false,
          isLoading: false,
          error: 'Could not restore profiles: $e',
        );
      }
    }
  }

  Future<bool> login(String profileName, String token) async {
    final name = profileName.trim();
    final trimmedToken = token.trim();
    if (name.isEmpty || trimmedToken.isEmpty) {
      state = state.copyWith(
        isRestoring: false,
        isLoading: false,
        error: 'Please fill in all fields.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final github = ref.read(githubClientProvider);
      final user = await github.getUserInfo(trimmedToken);

      if (user == null || user.login.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: github.lastError?.message ?? 'Invalid token or network error.',
        );
        return false;
      }

      final profile = GistProfile(
        id: user.login.toLowerCase(),
        name: name,
        githubUsername: user.login,
        avatarUrl: user.avatarUrl,
        bio: user.bio ?? '',
      );

      await ref.read(storageProvider).saveProfile(profile, trimmedToken);
      final profiles = await ref.read(storageProvider).getProfiles();
      state = state.copyWith(
        isRestoring: false,
        isLoading: false,
        profiles: profiles,
        profile: profile,
        token: trimmedToken,
        clearError: true,
      );
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not connect: $e',
        );
      }
      return false;
    }
  }

  Future<void> selectProfile(GistProfile profile) async {
    try {
      final storage = ref.read(storageProvider);
      final token = await storage.getToken(profile.id);
      if (token == null || token.isEmpty) {
        state = state.copyWith(error: 'Saved profile is missing its token.');
        return;
      }

      await storage.setActiveProfile(profile.id);
      state = state.copyWith(profile: profile, token: token, clearError: true);
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(error: 'Could not select profile: $e');
      }
    }
  }

  Future<void> deleteProfile(GistProfile profile) async {
    final storage = ref.read(storageProvider);
    await storage.deleteProfile(profile.id);
    final profiles = await storage.getProfiles();
    final isActive = state.profile?.id == profile.id;
    state = state.copyWith(
      profiles: profiles,
      clearProfile: isActive,
      clearError: true,
    );
  }

  Future<void> logout() async {
    await ref.read(storageProvider).clearActiveProfile();
    state = state.copyWith(clearProfile: true, clearError: true);
  }
}

class GistState {
  const GistState({
    this.isLoading = false,
    this.gists = const [],
    this.error,
    this.loaded = 0,
    this.total = 0,
    this.lastSynced,
  });

  final bool isLoading;
  final List<LocalGist> gists;
  final String? error;
  final int loaded, total;
  final DateTime? lastSynced;

  GistState copyWith({
    bool? isLoading,
    List<LocalGist>? gists,
    String? error,
    bool clearError = false,
    int? loaded,
    int? total,
    DateTime? lastSynced,
  }) {
    return GistState(
      isLoading: isLoading ?? this.isLoading,
      gists: gists ?? this.gists,
      error: clearError ? null : error ?? this.error,
      loaded: loaded ?? this.loaded,
      total: total ?? this.total,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}

class GistController extends Notifier<GistState> {
  final _publishingDrafts = <String>{};
  @override
  GistState build() {
    final profileId = ref.watch(
      sessionControllerProvider.select((session) => session.profile?.id),
    );
    if (profileId != null) Future.microtask(_loadLocal);
    return const GistState();
  }

  Future<void> _loadLocal() async {
    final session = ref.read(sessionControllerProvider);
    final profileId = session.profile?.id;
    if (profileId == null) return;

    try {
      final gists = await ref.read(storageProvider).getGists(profileId);
      if (!ref.mounted ||
          ref.read(sessionControllerProvider).profile?.id != profileId) {
        return;
      }
      state = state.copyWith(gists: gists, clearError: true);
    } catch (e) {
      if (ref.mounted &&
          ref.read(sessionControllerProvider).profile?.id == profileId) {
        state = state.copyWith(error: 'Could not load the local cache: $e');
      }
    }
  }

  List<LocalGist> search(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    if (terms.isEmpty) return state.gists;
    final matches = <({LocalGist gist, int score})>[];
    for (final gist in state.gists) {
      var score = 0;
      var matched = true;
      for (final term in terms) {
        final weight = gist.description.toLowerCase().contains(term)
            ? 140
            : gist.tags.any(
                (t) => t.toLowerCase().contains(
                  term.replaceFirst(RegExp('^#'), ''),
                ),
              )
            ? 100
            : gist.files.values.any(
                (f) => f.filename.toLowerCase().contains(term),
              )
            ? 60
            : gist.files.values.any(
                (f) => f.content.toLowerCase().contains(term),
              )
            ? 20
            : 0;
        if (weight == 0) {
          matched = false;
          break;
        }
        score += weight;
      }
      if (matched) matches.add((gist: gist, score: score));
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.map((match) => match.gist).toList();
  }

  LocalGist? findById(String id) {
    final matches = state.gists.where((gist) => gist.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> sync() async {
    if (state.isLoading) return;
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) return;

    state = state.copyWith(
      isLoading: true,
      loaded: 0,
      total: 0,
      clearError: true,
    );
    final github = ref.read(githubClientProvider);
    final startedIds = state.gists.map((g) => g.id).toSet();

    try {
      final summaries = await github.getUserGists(session.token!);
      if (!ref.mounted ||
          ref.read(sessionControllerProvider).profile?.id !=
              session.profile!.id) {
        return;
      }
      state = state.copyWith(total: summaries.length);
      final fullGists = <LocalGist?>[];
      for (final gist in summaries) {
        if (!ref.mounted ||
            ref.read(sessionControllerProvider).profile?.id !=
                session.profile!.id) {
          return;
        }
        final full = await github.getGistById(gist.id, session.token!);
        fullGists.add(full);
        if (ref.mounted &&
            ref.read(sessionControllerProvider).profile?.id ==
                session.profile!.id) {
          state = state.copyWith(
            loaded: fullGists.whereType<LocalGist>().length,
          );
        }
        if (full == null) break;
      }

      if (fullGists.any((g) => g == null)) {
        throw StateError(
          '${github.lastError?.message ?? 'Some gists could not be loaded.'} Your local cache was kept.',
        );
      }
      if (ref.read(sessionControllerProvider).profile?.id !=
          session.profile?.id) {
        return;
      }
      final existing = {for (final gist in state.gists) gist.id: gist};
      final merged = fullGists.whereType<LocalGist>().map((gist) {
        final old = existing[gist.id];
        return gist.copyWith(
          isBookmarked: old?.isBookmarked ?? false,
          bookmarkOrder: old?.bookmarkOrder ?? 0,
          tags: parseTags(gist.description),
        );
      }).toList();

      final syncedIds = merged.map((g) => g.id).toSet();
      merged.addAll(
        state.gists.where(
          (g) =>
              !syncedIds.contains(g.id) &&
              (g.isDraft || !startedIds.contains(g.id)),
        ),
      );
      await ref.read(storageProvider).saveGists(session.profile!.id, merged);
      if (!ref.mounted ||
          ref.read(sessionControllerProvider).profile?.id !=
              session.profile?.id) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        gists: merged,
        lastSynced: DateTime.now(),
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted ||
          ref.read(sessionControllerProvider).profile?.id !=
              session.profile?.id) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: error is StateError
            ? error.message
            : 'Sync could not finish. Your local library was kept. Try again.',
      );
    }
  }

  Future<LocalGist?> ensureFull(String id) async {
    final local = findById(id);
    if (local?.isDraft == true) return local;
    if (local != null &&
        local.files.values.isNotEmpty &&
        local.files.values.every(
          (file) => !file.truncated && file.content.isNotEmpty,
        )) {
      return local;
    }

    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) return local;

    final fresh = await ref
        .read(githubClientProvider)
        .getGistById(id, session.token!);
    if (fresh == null) {
      return local?.files.values.any((f) => f.truncated) == true ? null : local;
    }

    final merged = fresh.copyWith(
      isBookmarked: local?.isBookmarked ?? false,
      bookmarkOrder: local?.bookmarkOrder ?? 0,
      tags: parseTags(fresh.description),
    );
    await _upsertLocal(merged, session.profile!.id);
    return merged;
  }

  Future<LocalGist> saveDraft({
    String? id,
    required String description,
    required bool isPublic,
    required Map<String, GistFile> files,
  }) async {
    final profileId = ref.read(sessionControllerProvider).profile?.id;
    if (profileId == null) throw StateError('Select a profile before saving.');
    if (files.isEmpty ||
        files.values.any(
          (f) =>
              f.filename.trim().isEmpty ||
              f.content.trim().isEmpty ||
              f.truncated,
        )) {
      throw const FormatException(
        'Complete filenames and content are required.',
      );
    }
    final old = id == null ? null : findById(id);
    if (id != null && old?.isDraft != true) {
      throw StateError('Draft unavailable.');
    }
    final now = DateTime.now();
    final draft = LocalGist(
      id: id ?? 'draft-${now.microsecondsSinceEpoch}',
      description: description,
      isPublic: isPublic,
      files: files,
      isDraft: true,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      tags: parseTags(description),
      isBookmarked: old?.isBookmarked ?? false,
      bookmarkOrder: old?.bookmarkOrder ?? 0,
    );
    await _upsertLocal(draft, profileId);
    return draft;
  }

  Future<LocalGist?> publishDraft(String id) async {
    final session = ref.read(sessionControllerProvider);
    final draft = findById(id);
    if (!session.isAuthenticated || draft?.isDraft != true) return null;
    if (!_publishingDrafts.add(id)) return null;
    try {
      final github = ref.read(githubClientProvider);
      final result = await github.createGist(
        description: draft!.description,
        isPublic: draft.isPublic,
        files: draft.files,
        token: session.token!,
      );
      if (result == null) {
        if (ref.mounted &&
            ref.read(sessionControllerProvider).profile?.id ==
                session.profile!.id) {
          state = state.copyWith(
            error:
                github.lastError?.message ??
                'Publish could not be confirmed. Check GitHub before trying again.',
          );
        }
        return null;
      }
      final storage = ref.read(storageProvider);
      final profileId = session.profile!.id;
      final current = await storage.getGists(profileId);
      final latest = current.where((g) => g.id == id).firstOrNull ?? draft;
      final saved = result.copyWith(
        tags: parseTags(result.description),
        isBookmarked: latest.isBookmarked,
        bookmarkOrder: latest.bookmarkOrder,
      );
      await storage.saveGists(profileId, [
        for (final g in current)
          if (g.id != id && g.id != saved.id) g,
        saved,
      ]);
      if (ref.mounted &&
          ref.read(sessionControllerProvider).profile?.id == profileId) {
        state = state.copyWith(
          gists: [
            for (final g in state.gists)
              if (g.id != id && g.id != saved.id) g,
            saved,
          ],
          clearError: true,
        );
      }
      try {
        // Keep existing collection membership when the local ID becomes a GitHub ID.
        final prefs = await SharedPreferences.getInstance();
        final key = 'gist_hub_playlists_$profileId';
        final source = prefs.getString(key);
        if (source != null) {
          final groups = (jsonDecode(source) as Map).map(
            (k, v) => MapEntry('$k', [
              for (final value in v as List) value == id ? saved.id : value,
            ]),
          );
          await prefs.setString(key, jsonEncode(groups));
          if (ref.mounted) {
            ref.read(collectionsRevisionProvider.notifier).changed();
          }
        }
      } catch (_) {
        if (ref.mounted &&
            ref.read(sessionControllerProvider).profile?.id == profileId) {
          state = state.copyWith(
            error:
                'Published to GitHub. Collection membership could not be updated; add this gist to its collections again.',
          );
        }
      }
      return saved;
    } finally {
      _publishingDrafts.remove(id);
    }
  }

  Future<LocalGist?> createGist({
    required String description,
    required bool isPublic,
    required String filename,
    required String content,
  }) async {
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) return null;

    final gist = await ref
        .read(githubClientProvider)
        .createGist(
          description: description,
          isPublic: isPublic,
          files: {filename: GistFile(filename: filename, content: content)},
          token: session.token!,
        );
    if (gist == null) {
      state = state.copyWith(
        error:
            ref.read(githubClientProvider).lastError?.message ??
            'Could not create gist.',
      );
      return null;
    }

    final saved = gist.copyWith(tags: parseTags(gist.description));
    await _upsertLocal(saved, session.profile!.id);
    return saved;
  }

  Future<LocalGist?> updateGist({
    required String id,
    required String description,
    required String originalFilename,
    required String filename,
    required String content,
  }) async {
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) return null;

    final local = findById(id);
    final gist = await ref
        .read(githubClientProvider)
        .updateGist(
          id: id,
          description: description,
          originalFilename: originalFilename,
          file: GistFile(filename: filename, content: content),
          token: session.token!,
        );
    if (gist == null) {
      state = state.copyWith(
        error:
            ref.read(githubClientProvider).lastError?.message ??
            'Could not save gist.',
      );
      return null;
    }

    final saved = gist.copyWith(
      tags: parseTags(gist.description),
      isBookmarked: local?.isBookmarked ?? false,
      bookmarkOrder: local?.bookmarkOrder ?? 0,
    );
    await _upsertLocal(saved, session.profile!.id);
    return saved;
  }

  Future<bool> deleteGist(String id) async {
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) return false;

    final local = findById(id);
    final ok =
        local?.isDraft == true ||
        await ref.read(githubClientProvider).deleteGist(id, session.token!);
    if (!ok) {
      state = state.copyWith(
        error:
            ref.read(githubClientProvider).lastError?.message ??
            'Could not delete gist.',
      );
      return false;
    }

    await ref.read(storageProvider).deleteGist(session.profile!.id, id);
    if (!ref.mounted ||
        ref.read(sessionControllerProvider).profile?.id !=
            session.profile!.id) {
      return true;
    }
    state = state.copyWith(
      gists: state.gists.where((gist) => gist.id != id).toList(),
      clearError: true,
    );
    return true;
  }

  Future<void> toggleBookmark(String id) async {
    final gist = findById(id);
    final session = ref.read(sessionControllerProvider);
    if (gist == null || session.profile == null) return;

    final maxOrder = state.gists.fold(
      0,
      (order, g) => g.bookmarkOrder > order ? g.bookmarkOrder : order,
    );
    final updated = gist.copyWith(
      isBookmarked: !gist.isBookmarked,
      bookmarkOrder: gist.isBookmarked ? 0 : maxOrder + 1,
    );
    await _upsertLocal(updated, session.profile!.id);
  }

  Future<String?> importJson(String jsonText) async {
    final input = parseImportedGistJson(jsonText);
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) return 'Connect to GitHub before importing.';

    final created = await ref
        .read(githubClientProvider)
        .createGist(
          description: input.description,
          isPublic: input.isPublic,
          files: input.files,
          token: session.token!,
        );
    if (created == null) {
      return ref.read(githubClientProvider).lastError?.message ??
          'GitHub API rejected this payload.';
    }

    await _upsertLocal(
      created.copyWith(tags: parseTags(created.description)),
      session.profile!.id,
    );
    return null;
  }

  List<LocalGist> get bookmarks =>
      state.gists.where((g) => g.isBookmarked).toList()..sort((a, b) {
        final left = a.bookmarkOrder > 0 ? a.bookmarkOrder : 0x7fffffff;
        final right = b.bookmarkOrder > 0 ? b.bookmarkOrder : 0x7fffffff;
        return left.compareTo(right);
      });

  Future<void> reorderBookmarks(List<String> ids) async {
    final profileId = ref.read(sessionControllerProvider).profile?.id;
    if (profileId == null) return;
    final current = bookmarks.map((g) => g.id).toSet();
    if (ids.length != current.length ||
        ids.toSet().length != ids.length ||
        !current.containsAll(ids)) {
      throw const FormatException(
        'Bookmark list changed. Try reordering again.',
      );
    }
    final orders = {for (var i = 0; i < ids.length; i++) ids[i]: i + 1};
    final next = [
      for (final g in state.gists)
        g.copyWith(bookmarkOrder: orders[g.id] ?? g.bookmarkOrder),
    ];
    await ref.read(storageProvider).saveGists(profileId, next);
    if (ref.mounted &&
        ref.read(sessionControllerProvider).profile?.id == profileId) {
      state = state.copyWith(gists: next);
    }
  }

  Future<void> restoreBookmarks(String source) async {
    final session = ref.read(sessionControllerProvider);
    if (session.profile == null) return;
    final ids = mergeBookmarkBackup(
      source,
      session.profile!.githubUsername,
      bookmarks.map((g) => g.id).toList(),
      state.gists.map((g) => g.id).toSet(),
    );
    final orders = {for (var i = 0; i < ids.length; i++) ids[i]: i + 1};
    final next = [
      for (final g in state.gists)
        g.copyWith(
          isBookmarked: orders.containsKey(g.id),
          bookmarkOrder: orders[g.id] ?? 0,
        ),
    ];
    await ref.read(storageProvider).saveGists(session.profile!.id, next);
    if (ref.mounted &&
        ref.read(sessionControllerProvider).profile?.id ==
            session.profile!.id) {
      state = state.copyWith(gists: next);
    }
  }

  Future<void> _upsertLocal(LocalGist gist, String profileId) async {
    final active = ref.read(sessionControllerProvider).profile?.id == profileId;
    final existing = active
        ? state.gists
        : await ref.read(storageProvider).getGists(profileId);
    final next =
        [
          for (final item in existing)
            if (item.id != gist.id) item,
          gist,
        ]..sort((a, b) {
          final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

    await ref.read(storageProvider).saveGists(profileId, next);
    if (ref.mounted &&
        ref.read(sessionControllerProvider).profile?.id == profileId) {
      state = state.copyWith(gists: next, clearError: true);
    }
  }
}

final soundControllerProvider = NotifierProvider<SoundController, bool>(
  SoundController.new,
);

class SoundController extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      if (ref.mounted) state = prefs.getBool('gist_hub_sound') ?? true;
    });
    return true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gist_hub_sound', state);
  }
}

final blurControllerProvider = NotifierProvider<BlurController, bool>(
  BlurController.new,
);

class BlurController extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      if (ref.mounted) state = prefs.getBool('gist_hub_blur') ?? false;
    });
    return false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gist_hub_blur', state);
  }
}
