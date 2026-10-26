import 'dart:convert';
import 'export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_state.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'preview.dart';
import 'screens.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionControllerProvider).isAuthenticated) {
      return const GistsScreen();
    }
    final palette = context.palette;
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 24),
          Text(
            'YOUR SNIPPET WORKSPACE',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your code. Within reach.',
            style: TextStyle(
              fontSize: 38,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Collect the useful bits. Find them when it matters.',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: palette.mutedText,
            ),
          ),
          const SizedBox(height: 32),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.code_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bring your GitHub gists together',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Search your code, save favorites and organize your library into collections.',
                  style: TextStyle(height: 1.6, color: palette.mutedText),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.link),
                      label: const Text('Connect GitHub'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/discovery'),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Discover public snippets'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'A few good places to start',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final item in const [
            (
              '/slh-collection',
              'SLH Collection',
              'Browse a curated collection of useful code.',
              Icons.collections_bookmark_outlined,
            ),
            (
              '/tools',
              'Open developer tools',
              'JSON, Base64 and code-to-image tools, in one place.',
              Icons.handyman_outlined,
            ),
            (
              '/appearance',
              'Make it yours',
              'Choose the palette, typography and surfaces you enjoy.',
              Icons.palette_outlined,
            ),
          ])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              leading: Icon(
                item.$4,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                item.$2,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.$3,
                style: TextStyle(color: palette.mutedText),
              ),
              trailing: const Icon(Icons.arrow_forward, size: 20),
              onTap: () => context.go(item.$1),
            ),
        ],
      ),
    );
  }
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.slh = false});
  final bool slh;
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final query = TextEditingController();
  final username = TextEditingController();
  List<LocalGist> gists = [];
  final selected = <String>{};
  bool busy = false;
  String? error;
  String language = '';
  int page = 1;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    query.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await GithubService(ref.read(httpClientProvider))
          .publicFeed(
            token: ref.read(sessionControllerProvider).token ?? '',
            username: widget.slh
                ? 'sannlynnhtun-coding'
                : username.text.trim().isEmpty
                ? null
                : username.text.trim(),
            page: more ? page + 1 : 1,
          );
      if (!mounted) return;
      setState(() {
        page = more ? page + 1 : 1;
        if (!more &&
            language.isNotEmpty &&
            !result.any(
              (g) => g.files.values.any((f) => f.language == language),
            )) {
          language = '';
        }
        gists = more ? [...gists, ...result] : result;
        if (!more) selected.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Could not load snippets. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clone() async {
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) {
      context.go('/login');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      for (final id in selected.toList()) {
        final api = ref.read(githubClientProvider);
        final full = await api.getGistById(id, session.token!);
        if (full == null) {
          throw StateError(api.lastError?.message ?? 'Could not load snippet');
        }
        final message = await ref
            .read(gistControllerProvider.notifier)
            .importJson(jsonEncode(full.toJson()));
        if (message != null) throw StateError(message);
        selected.remove(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cloned into My Gists')));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Could not load snippets. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages =
        gists
            .expand((g) => g.files.values)
            .map((f) => f.language)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final needle = query.text.toLowerCase();
    final filtered = gists.where(
      (g) =>
          '${g.description} ${g.owner?.login} ${g.files.keys.join(' ')}'
              .toLowerCase()
              .contains(needle) &&
          (language.isEmpty ||
              g.files.values.any((f) => f.language == language)),
    );
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.slh ? 'SLH Collection' : 'Discovery',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.slh
                ? 'A collection of useful snippets.'
                : 'Find a useful idea. Make it your own.',
            style: TextStyle(color: context.palette.mutedText),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search snippets',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(query.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(language),
                  initialValue: language,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All languages'),
                    ),
                    for (final l in languages)
                      DropdownMenuItem(value: l, child: Text(l)),
                  ],
                  onChanged: (value) => setState(() => language = value ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh snippets',
                onPressed: busy ? null : load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (!widget.slh)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                username.text.isEmpty
                    ? 'Browse a GitHub profile'
                    : '@${username.text}',
                style: const TextStyle(fontSize: 13),
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'GitHub username (optional)',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        onSubmitted: (_) => load(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Find profile snippets',
                      onPressed: busy ? null : load,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${filtered.length} snippets${selected.isEmpty ? '' : ' · ${selected.length} selected'}',
              style: TextStyle(fontSize: 12, color: context.palette.mutedText),
            ),
          ),
          if (error != null) ...[
            ErrorBanner(message: error!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (selected.isNotEmpty)
            FilledButton(
              onPressed: busy ? null : clone,
              child: Text('Clone ${selected.length} selected snippets'),
            ),
          for (final gist in filtered)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Checkbox(
                  semanticLabel:
                      'Select ${gist.firstFile?.filename ?? 'snippet'}',
                  value: selected.contains(gist.id),
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          v == true
                              ? selected.add(gist.id)
                              : selected.remove(gist.id);
                        }),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                title: Text(
                  gist.description.isEmpty
                      ? gist.firstFile?.filename ?? 'Untitled'
                      : gist.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${gist.firstFile?.filename ?? 'snippet'}\n${gist.owner?.login ?? 'GitHub'} · ${gist.files.length} ${gist.files.length == 1 ? 'file' : 'files'}',
                ),
                onTap: () => context.push('/view/${gist.id}'),
              ),
            ),
          if (!busy && filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No snippets found.'),
            ),
          OutlinedButton(
            onPressed: busy ? null : () => load(more: true),
            child: const Text('Load more'),
          ),
        ],
      ),
    );
  }
}

class PublicDetailScreen extends ConsumerStatefulWidget {
  const PublicDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PublicDetailScreen> createState() => _PublicDetailScreenState();
}

class _PublicDetailScreenState extends ConsumerState<PublicDetailScreen> {
  LocalGist? gist;
  String? error;
  String? filename;
  bool raw = false;
  bool cloning = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final api = ref.read(githubClientProvider);
        final result = await api.getGistById(
          widget.id,
          ref.read(sessionControllerProvider).token ?? '',
        );
        if (mounted) {
          setState(() {
            gist = result;
            error = result == null
                ? api.lastError?.message ?? 'Snippet unavailable'
                : null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(
            () => error = e is StateError
                ? e.message
                : 'Could not load snippets. Check your connection and try again.',
          );
        }
      }
    });
  }

  Future<void> cloneGist() async {
    if (!ref.read(sessionControllerProvider).isAuthenticated) {
      context.go('/login');
      return;
    }
    setState(() => cloning = true);
    try {
      final message = await ref
          .read(gistControllerProvider.notifier)
          .importJson(jsonEncode(gist!.toJson()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Cloned into My Gists')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => cloning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = gist?.files[filename] ?? gist?.firstFile;
    return AppShell(
      child: gist == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Text(error!),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  gist!.description,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in gist!.files.values)
                      ChoiceChip(
                        label: Text(f.filename),
                        selected: f.filename == file?.filename,
                        onSelected: (_) =>
                            setState(() => filename = f.filename),
                      ),
                  ],
                ),
                Wrap(
                  children: [
                    FilledButton(
                      onPressed: cloning ? null : cloneGist,
                      child: Text(cloning ? 'Cloning…' : 'Clone to My Gists'),
                    ),
                    TextButton(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: file?.content ?? ''),
                      ),
                      child: const Text('Copy raw'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: gist!.htmlUrl)),
                      child: const Text('Copy link'),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(gist!.htmlUrl)),
                      child: const Text('GitHub'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => raw = !raw),
                      child: Text(raw ? 'Preview' : 'Raw'),
                    ),
                  ],
                ),
                if (!raw)
                  SnippetPreview(
                    content: file?.content ?? '',
                    filename: file?.filename ?? 'snippet.txt',
                  )
                else
                  SelectableText(
                    file?.content ?? '',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
              ],
            ),
    );
  }
}

class TrendingScreen extends StatelessWidget {
  const TrendingScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppShell(
    child: Center(
      child: Text(
        'Trending Gists\nComing Soon — the popularity algorithm is being refined.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, this.savedOnly = false});
  final bool savedOnly;
  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  Map<String, List<String>> groups = {};
  String? active;
  bool ready = false;
  String get storageKey =>
      'gist_hub_playlists_${ref.read(sessionControllerProvider).profile?.id}';
  @override
  void initState() {
    super.initState();
    Future.microtask(loadGroups);
  }

  Future<void> loadGroups() async {
    final key = storageKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString(key) ?? '{}') as Map;
      if (!mounted || key != storageKey) return;
      setState(() {
        groups = data.map((k, v) => MapEntry('$k', List<String>.from(v)));
        if (!groups.containsKey(active)) active = null;
        ready = true;
      });
    } catch (e) {
      if (mounted && key == storageKey) {
        setState(() => ready = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load collections: $e')),
        );
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(groups));
  }

  Future<String?> input(String title, {String initial = ''}) async {
    var entered = initial;
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          onChanged: (value) => entered = value,
          maxLines: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, entered),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    return mounted ? value : null;
  }

  Future<void> backup(bool restore) async {
    final gists = ref.read(gistControllerProvider.notifier).bookmarks;
    final username = ref
        .read(sessionControllerProvider)
        .profile!
        .githubUsername;
    if (!restore) {
      final json = const JsonEncoder.withIndent('  ').convert({
        'format': 'gisthub-bookmarks',
        'version': 1,
        'githubUsername': username,
        'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'bookmarks': [
          for (var i = 0; i < gists.length; i++)
            {'gistId': gists[i].id, 'order': i + 1},
        ],
      });
      try {
        await saveExport(
          'gisthub-bookmarks.json',
          'application/json',
          Uint8List.fromList(utf8.encode(json)),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bookmark backup saved')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Backup was not saved: $e')));
        }
      }
      return;
    }
    final value = await input('Paste bookmark backup JSON');
    if (value == null) return;
    try {
      await ref.read(gistControllerProvider.notifier).restoreBookmarks(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmarks restored for matching local gists'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider.select((s) => s.profile?.id), (_, _) {
      setState(() {
        ready = false;
        groups = {};
        active = null;
      });
      loadGroups();
    });
    ref.listen(collectionsRevisionProvider, (_, _) => loadGroups());
    final gists = ref.watch(gistControllerProvider).gists;
    final visible = active == null
        ? ref.read(gistControllerProvider.notifier).bookmarks
        : gists.where((g) => groups[active]?.contains(g.id) ?? false);
    return AppShell(
      child: !ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.savedOnly ? 'Saved' : 'Collections',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (!widget.savedOnly)
                      FilledButton(
                        onPressed: () async {
                          final name = (await input(
                            'New collection name',
                          ))?.trim();
                          if (name == null ||
                              name.isEmpty ||
                              groups.keys.any(
                                (k) => k.toLowerCase() == name.toLowerCase(),
                              )) {
                            return;
                          }
                          setState(() {
                            groups[name] = [];
                            active = name;
                          });
                          await save();
                        },
                        child: const Text('New collection'),
                      ),
                    if (widget.savedOnly)
                      OutlinedButton(
                        onPressed: () => backup(false),
                        child: const Text('Export bookmark backup'),
                      ),
                    if (widget.savedOnly)
                      OutlinedButton(
                        onPressed: () => backup(true),
                        child: const Text('Restore bookmarks'),
                      ),
                    if (widget.savedOnly)
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            final file = await pickFile();
                            if (file == null || !mounted) return;
                            await ref
                                .read(gistControllerProvider.notifier)
                                .restoreBookmarks(utf8.decode(file.bytes));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bookmarks restored'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                        child: const Text('Restore from file'),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(
                        widget.savedOnly ? 'Bookmarks' : 'All collections',
                      ),
                      selected: active == null,
                      onSelected: (_) => setState(() => active = null),
                    ),
                    if (!widget.savedOnly)
                      for (final name in groups.keys)
                        ChoiceChip(
                          label: Text(
                            '$name (${gists.where((g) => groups[name]!.contains(g.id)).length})',
                          ),
                          selected: active == name,
                          onSelected: (_) => setState(() => active = name),
                        ),
                  ],
                ),
                if (active != null)
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final name = active!;
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text('Delete collection "$name"?'),
                              content: const Text('Your gists will be kept.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true) {
                            setState(() {
                              groups.remove(name);
                              active = null;
                            });
                            await save();
                          }
                        },
                        child: const Text('Delete collection'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final old = active!;
                          final name = (await input(
                            'Rename collection',
                            initial: old,
                          ))?.trim();
                          if (name == null || name.isEmpty || name == old) {
                            return;
                          }
                          if (groups.keys.any(
                            (k) => k.toLowerCase() == name.toLowerCase(),
                          )) {
                            return;
                          }
                          setState(() {
                            groups[name] = groups.remove(old)!;
                            active = name;
                          });
                          await save();
                        },
                        child: const Text('Rename collection'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final name = active!;
                          await showDialog<void>(
                            context: context,
                            builder: (c) => StatefulBuilder(
                              builder: (c, update) => AlertDialog(
                                title: const Text('Choose snippets'),
                                content: SizedBox(
                                  width: 500,
                                  height: 400,
                                  child: ListView(
                                    children: [
                                      for (final g in gists)
                                        CheckboxListTile(
                                          title: Text(
                                            g.description.isEmpty
                                                ? g.firstFile?.filename ?? g.id
                                                : g.description,
                                          ),
                                          value: groups[name]!.contains(g.id),
                                          onChanged: (v) {
                                            update(() {
                                              v == true
                                                  ? groups[name]!.add(g.id)
                                                  : groups[name]!.remove(g.id);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Done'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          await save();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Manage snippets'),
                      ),
                    ],
                  ),
                if (!widget.savedOnly && active == null) ...[
                  const Text(
                    'Collections stay on this device and do not change GitHub files.',
                  ),
                  for (final name in groups.keys)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(name),
                        subtitle: Text(
                          '${gists.where((g) => groups[name]!.contains(g.id)).length} snippets',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() => active = name),
                      ),
                    ),
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Create your first collection, then choose snippets to add.',
                      ),
                    ),
                ],
                if ((widget.savedOnly || active != null) && visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No snippets in this collection.'),
                  ),
                if (widget.savedOnly || active != null)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: active == null,
                    onReorderItem: (oldIndex, newIndex) async {
                      if (active != null) return;
                      final ids = visible.map((g) => g.id).toList();
                      ids.insert(newIndex, ids.removeAt(oldIndex));
                      try {
                        await ref
                            .read(gistControllerProvider.notifier)
                            .reorderBookmarks(ids);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    children: [
                      for (final g in visible)
                        ListTile(
                          key: ValueKey(g.id),
                          title: Text(
                            g.description.isEmpty
                                ? g.firstFile?.filename ?? g.id
                                : g.description,
                          ),
                          onTap: () => context.push('/gists/${g.id}'),
                          trailing: Padding(
                            padding: EdgeInsets.only(
                              right: active == null ? 40 : 0,
                            ),
                            child: IconButton(
                              tooltip: 'Toggle bookmark',
                              icon: Icon(
                                g.isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_outline,
                              ),
                              onPressed: () => ref
                                  .read(gistControllerProvider.notifier)
                                  .toggleBookmark(g.id),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final library = ref.watch(gistControllerProvider);
    final profile = session.profile;
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Account & sync',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your workspace, on your terms.',
            style: TextStyle(color: context.palette.mutedText),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (profile != null)
                        Avatar(profile: profile, size: 48)
                      else
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.name ?? 'Connect GitHub',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              profile == null
                                  ? 'Bring your snippets with you.'
                                  : '@${profile.githubUsername}',
                              style: TextStyle(
                                color: context.palette.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          label:
                              '${library.gists.where((g) => !g.isDraft).length} GitHub gists',
                        ),
                        StatusPill(
                          label:
                              '${library.gists.where((g) => g.isDraft).length} local drafts',
                        ),
                        StatusPill(
                          label:
                              '${library.gists.where((g) => g.isBookmarked).length} saved',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      library.isLoading
                          ? 'Syncing…'
                          : library.error ??
                                (library.lastSynced == null
                                    ? 'Saved library on this device'
                                    : 'Up to date with GitHub'),
                      style: TextStyle(color: context.palette.mutedText),
                    ),
                    if (library.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: library.isLoading
                          ? null
                          : () => ref
                                .read(gistControllerProvider.notifier)
                                .sync(),
                      icon: const Icon(Icons.sync),
                      label: Text(
                        library.error == null ? 'Sync GitHub' : 'Retry sync',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Connect GitHub'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'WORKSPACE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: Text(
                    profile == null
                        ? 'Connect GitHub'
                        : 'Manage profiles / tokens',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/login'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Bookmark backup & restore'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/saved'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/appearance'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'EXPLORE & TOOLS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: const Text('Discover public gists'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/discovery'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.handyman_outlined),
                  title: const Text('Developer tools'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/tools'),
                ),
              ],
            ),
          ),
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Disconnect'),
                subtitle: const Text(
                  'Saved profile, drafts and collections stay on this device.',
                ),
                onTap: () =>
                    ref.read(sessionControllerProvider.notifier).logout(),
              ),
            ),
        ],
      ),
    );
  }
}
