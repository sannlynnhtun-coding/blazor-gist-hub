import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'parsers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'theme.dart';
import 'preview.dart';
import 'export.dart';
import 'dart:convert';
import 'dart:ui' as ui;

String _gistLink(LocalGist gist) {
  return gist.htmlUrl.isNotEmpty
      ? gist.htmlUrl
      : 'https://gist.github.com/${gist.id}';
}

Future<void> _copyGistLink(BuildContext context, LocalGist gist) async {
  if (gist.isDraft) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Publish this local draft before sharing a link.'),
      ),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: _gistLink(gist)));
  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Gist link copied')));
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _showToken = false;
  bool _connecting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final ok = await ref
        .read(sessionControllerProvider.notifier)
        .login(_nameController.text, _tokenController.text);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!ok) return;
    final gists = ref.read(gistControllerProvider.notifier);
    context.go('/gists');
    await gists.sync();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GistHubLogoMark(size: 64, iconSize: 38),
                  const SizedBox(height: 18),
                  const Text(
                    'GistHub',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Connect your GitHub workspace.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 32),
                  Panel(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('profile-name-field'),
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Profile Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('token-field'),
                          controller: _tokenController,
                          obscureText: !_showToken,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Personal Access Token',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              tooltip: _showToken ? 'Hide token' : 'Show token',
                              onPressed: () =>
                                  setState(() => _showToken = !_showToken),
                              icon: Icon(
                                _showToken
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Use a GitHub personal access token with gist access. Your token stays on this device and is sent only to GitHub.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://github.com/settings/tokens/new?scopes=gist&description=GistHub',
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Create a GitHub token'),
                          ),
                        ),
                        if (session.error != null) ...[
                          const SizedBox(height: 16),
                          ErrorBanner(message: session.error!),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          key: const Key('login-button'),
                          onPressed: session.isLoading ? null : _login,
                          icon: session.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(
                            session.isLoading
                                ? 'Verifying...'
                                : 'Verify and Connect',
                          ),
                        ),
                        if (session.profiles.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 18),
                          const Text(
                            'Saved Profiles',
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final profile in session.profiles)
                            _SavedProfileTile(profile: profile),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => context.go('/discovery'),
                    child: const Text('Browse public gists without signing in'),
                  ),
                  Text(
                    'Your token is stored locally on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedProfileTile extends ConsumerWidget {
  const _SavedProfileTile({required this.profile});

  final GistProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await ref
              .read(sessionControllerProvider.notifier)
              .selectProfile(profile);
          if (!context.mounted) return;
          context.go('/gists');
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Avatar(profile: profile, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '@${profile.githubUsername}',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Profile',
                  onPressed: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('Remove ${profile.name}?'),
                        content: const Text(
                          'This removes its saved token, local cache, bookmarks, drafts and collections on this device. Your GitHub gists are kept.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (yes != true || !context.mounted) return;
                    try {
                      await ref
                          .read(sessionControllerProvider.notifier)
                          .deleteProfile(profile);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GistsScreen extends ConsumerStatefulWidget {
  const GistsScreen({super.key});

  @override
  ConsumerState<GistsScreen> createState() => _GistsScreenState();
}

class _GistsScreenState extends ConsumerState<GistsScreen> {
  String _query = '';
  String _visibility = 'All';
  bool _bookmarksOnly = false;
  bool _draftsOnly = false;
  String? _tag;
  String _sort = 'Recent';
  bool _showFilters = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gistState = ref.watch(gistControllerProvider);
    final filtered = ref
        .read(gistControllerProvider.notifier)
        .search(_query)
        .where(
          (g) =>
              (!_bookmarksOnly || g.isBookmarked) &&
              (!_draftsOnly || g.isDraft) &&
              (_tag == null || g.tags.contains(_tag)) &&
              (_visibility == 'All' ||
                  (_visibility == 'Public' ? g.isPublic : !g.isPublic)),
        )
        .toList();
    filtered.sort(
      (a, b) => _sort == 'A-Z'
          ? (a.firstFile?.filename ?? '').toLowerCase().compareTo(
              (b.firstFile?.filename ?? '').toLowerCase(),
            )
          : (b.updatedAt ?? DateTime(1970)).compareTo(
              a.updatedAt ?? DateTime(1970),
            ),
    );
    final tags = gistState.gists.expand((g) => g.tags).toSet().toList()..sort();
    return AppShell(
      actions: [
        IconButton(
          tooltip: 'Sync Cloud',
          onPressed: gistState.isLoading
              ? null
              : () => ref.read(gistControllerProvider.notifier).sync(),
          icon: gistState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
        ),
        IconButton(
          tooltip: 'Paste JSON',
          onPressed: () => _showImportDialog(context),
          icon: const Icon(Icons.content_paste),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
        ),
      ],
      child: ListView(
        key: const PageStorageKey('library-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My library',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gistState.gists.length} snippets · ${gistState.gists.where((g) => g.isDraft).length} local drafts',
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'New snippet',
                onPressed: () => context.push('/gists/new'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                gistState.error != null
                    ? Icons.cloud_off_outlined
                    : gistState.isLoading
                    ? Icons.sync
                    : Icons.cloud_done_outlined,
                size: 16,
                color: gistState.error != null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gistState.isLoading
                      ? (gistState.total == 0
                            ? 'Connecting to GitHub…'
                            : 'Syncing ${gistState.loaded} of ${gistState.total}…')
                      : gistState.error != null
                      ? 'Showing your saved library'
                      : gistState.lastSynced == null
                      ? 'Saved on this device'
                      : 'Up to date with GitHub',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.mutedText,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: gistState.isLoading
                    ? null
                    : () => ref.read(gistControllerProvider.notifier).sync(),
                icon: const Icon(Icons.sync, size: 16),
                label: Text(
                  gistState.error != null ? 'Retry sync' : 'Sync now',
                ),
              ),
            ],
          ),
          if (gistState.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: gistState.total > 0
                    ? gistState.loaded / gistState.total
                    : null,
                semanticsLabel: 'Sync progress',
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            key: const Key('gist-search-field'),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search title, code, or tags...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Showing ${filtered.length} of ${gistState.gists.length} snippets',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('library-filters'),
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(
                  'Filters${(_visibility != 'All' || _draftsOnly || _bookmarksOnly || _tag != null) ? ' •' : ''}',
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sort snippets',
                initialValue: _sort,
                icon: const Icon(Icons.sort, size: 20),
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (_) => [
                  for (final name in ['Recent', 'A-Z'])
                    CheckedPopupMenuItem(
                      value: name,
                      checked: _sort == name,
                      child: Text(name),
                    ),
                ],
              ),
            ],
          ),
          if (_showFilters) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All tags'),
                    selected: _tag == null,
                    onSelected: (_) => setState(() => _tag = null),
                  ),
                  for (final tag in tags)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('#$tag'),
                        selected: _tag == tag,
                        onSelected: (_) => setState(() => _tag = tag),
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final value in ['All', 'Public', 'Secret'])
                  ChoiceChip(
                    label: Text(value),
                    selected: _visibility == value,
                    onSelected: (_) => setState(() => _visibility = value),
                  ),
                FilterChip(
                  label: const Text('Local drafts'),
                  selected: _draftsOnly,
                  onSelected: (v) => setState(() => _draftsOnly = v),
                ),
                FilterChip(
                  label: const Text('Bookmarks'),
                  selected: _bookmarksOnly,
                  onSelected: (v) => setState(() => _bookmarksOnly = v),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _visibility = 'All';
                  _draftsOnly = false;
                  _bookmarksOnly = false;
                  _tag = null;
                }),
                child: const Text('Reset filters'),
              ),
            ),
          ],
          if (gistState.error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: gistState.error!),
          ],
          const SizedBox(height: 24),
          if (gistState.isLoading && gistState.gists.isEmpty)
            const _CenteredMessage(message: 'Pulling your gists from GitHub...')
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    _query.isNotEmpty ||
                            _bookmarksOnly ||
                            _draftsOnly ||
                            _tag != null ||
                            _visibility != 'All'
                        ? Icons.search_off
                        : Icons.code,
                    size: 48,
                    color: context.palette.mutedText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _query.isNotEmpty ||
                            _bookmarksOnly ||
                            _draftsOnly ||
                            _tag != null ||
                            _visibility != 'All'
                        ? 'No matching snippets'
                        : 'Make room for your first idea',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _query.isNotEmpty ||
                            _bookmarksOnly ||
                            _draftsOnly ||
                            _tag != null ||
                            _visibility != 'All'
                        ? 'Try another search or clear the filters.'
                        : 'Sync your GitHub gists or create a new snippet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.palette.mutedText),
                  ),
                  if (_query.isNotEmpty ||
                      _bookmarksOnly ||
                      _draftsOnly ||
                      _tag != null ||
                      _visibility != 'All')
                    TextButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                        _bookmarksOnly = false;
                        _visibility = 'All';
                        _draftsOnly = false;
                        _tag = null;
                      }),
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (final gist in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GistCard(gist: gist),
                        ),
                    ],
                  );
                }

                const gap = 18.0;
                final cardWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final gist in filtered)
                      SizedBox(
                        width: cardWidth,
                        child: GistCard(gist: gist),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final palette = context.palette;
    var validation = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: palette.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Paste Gist JSON'),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('import-json-field'),
                  controller: controller,
                  minLines: 10,
                  maxLines: 14,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText:
                        '{"description":"...","public":false,"files":{"file.md":{"content":"..."}}}',
                    alignLabelWithHint: true,
                  ),
                ),
                if (validation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: validation),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final file = await pickFile();
                  if (file != null && dialogContext.mounted) {
                    controller.text = utf8.decode(file.bytes);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    setDialogState(() => validation = '$e');
                  }
                }
              },
              child: const Text('Upload JSON'),
            ),

            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('save-import-button'),
              onPressed: () async {
                try {
                  final error = await ref
                      .read(gistControllerProvider.notifier)
                      .importJson(controller.text);
                  if (error != null) {
                    setDialogState(() => validation = error);
                    return;
                  }
                } on FormatException catch (error) {
                  setDialogState(() => validation = error.message);
                  return;
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Save to Gist'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }
}

class GistCard extends ConsumerWidget {
  const GistCard({super.key, required this.gist});

  final LocalGist gist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstFile = gist.firstFile;
    final palette = context.palette;
    final filename = firstFile?.filename ?? 'No file cached';
    final preview = firstFile?.content.trim().isNotEmpty == true
        ? firstFile!.content.trim()
        : 'No content cached.';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/gists/${gist.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_outlined, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gist.isDraft
                              ? 'Local draft'
                              : gist.updatedAt == null
                              ? 'Local cache'
                              : _formatShortDate(gist.updatedAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: gist.isPublic ? 'Public' : 'Secret',
                    background: gist.isPublic ? paleGreen : paleYellow,
                    foreground: gist.isPublic ? greenText : yellowText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                gist.description.isEmpty
                    ? 'Untitled Snippet'
                    : gist.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                minTileHeight: 40,
                title: Text(
                  'Code preview',
                  style: TextStyle(fontSize: 12, color: palette.mutedText),
                ),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: ref.watch(blurControllerProvider) ? 5 : 0,
                          sigmaY: ref.watch(blurControllerProvider) ? 5 : 0,
                        ),
                        child: Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: palette.text,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: gist.tags.isEmpty
                          ? const [
                              Text(
                                'Snippet',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ]
                          : [
                              for (final tag in gist.tags.take(3))
                                StatusPill(label: '#$tag'),
                            ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bookmark',
                    onPressed: () => ref
                        .read(gistControllerProvider.notifier)
                        .toggleBookmark(gist.id),
                    icon: Icon(
                      gist.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: gist.isBookmarked ? yellowText : palette.text,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () => _copyGistLink(context, gist),
                    icon: const Icon(Icons.ios_share_outlined),
                  ),
                  IconButton(
                    tooltip: 'Copy Raw',
                    onPressed: firstFile == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: firstFile.content),
                          ),
                    icon: const Icon(Icons.copy),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    onSelected: (value) {
                      if (value == 'open') context.go('/gists/${gist.id}');
                      if (value == 'edit') {
                        context.push('/gists/${gist.id}/edit');
                      }
                      if (value == 'delete') _confirmDelete(context, ref);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'open', child: Text('Open Details')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatShortDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete this gist?'),
        content: Text(gist.description.isEmpty ? gist.id : gist.description),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(gistControllerProvider.notifier).deleteGist(gist.id);
    }
  }
}

final editorDirtyProvider = Provider<ValueNotifier<bool>>((ref) {
  final dirty = ValueNotifier(false);
  ref.onDispose(dirty.dispose);
  return dirty;
});

Future<bool> confirmEditorExit(BuildContext context, WidgetRef ref) async {
  final dirty = ref.read(editorDirtyProvider);
  if (!dirty.value) return true;
  final discard = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Discard unsaved changes?'),
      content: const Text(
        'Save a local draft to keep your work before leaving.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Keep editing'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  if (discard == true) dirty.value = false;
  return discard == true;
}

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.gistId});

  final String? gistId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _descriptionController = TextEditingController();
  final _filenameController = TextEditingController(text: 'README.md');
  final _contentController = TextEditingController();

  bool _isPublic = true;
  bool _loading = false;
  bool _saving = false;
  String _originalFilename = 'README.md';
  Map<String, GistFile> _files = {};
  bool _preview = false;
  bool _isDraft = false;
  String _error = '';

  bool get _isEditing => widget.gistId != null;

  @override
  void initState() {
    super.initState();
    ref.read(editorDirtyProvider).value = false;
    for (final controller in [
      _descriptionController,
      _filenameController,
      _contentController,
    ]) {
      controller.addListener(() => ref.read(editorDirtyProvider).value = true);
    }
    if (_isEditing) {
      _loading = true;
      Future.microtask(_loadGist);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _filenameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadGist() async {
    final gist = await ref
        .read(gistControllerProvider.notifier)
        .ensureFull(widget.gistId!);
    if (!mounted) return;

    if (gist == null) {
      setState(() {
        _loading = false;
        _error = 'Snippet unavailable.';
      });
      return;
    }

    final firstFile = gist.firstFile;
    setState(() {
      _files = gist.files;
      _isDraft = gist.isDraft;
      _descriptionController.text = gist.description;
      _originalFilename = firstFile?.filename ?? 'snippet.txt';
      _filenameController.text = _originalFilename;
      _contentController.text = firstFile?.content ?? '';
      _isPublic = gist.isPublic;
      ref.read(editorDirtyProvider).value = false;
      _loading = false;
    });
  }

  Future<void> _save({bool localOnly = false}) async {
    final filename = _filenameController.text.trim();
    final content = _contentController.text;
    if (filename.isEmpty || content.trim().isEmpty) {
      setState(() => _error = 'Filename and content are required.');
      return;
    }

    if (_isEditing &&
        filename != _originalFilename &&
        _files.containsKey(filename)) {
      setState(() => _error = 'A file with this name already exists.');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final controller = ref.read(gistControllerProvider.notifier);
      LocalGist? saved;
      if (localOnly || _isDraft) {
        final files = {..._files}..remove(_originalFilename);
        files[filename] = GistFile(filename: filename, content: content);
        saved = await controller.saveDraft(
          id: _isDraft ? widget.gistId : null,
          description: _descriptionController.text.trim(),
          isPublic: _isPublic,
          files: files,
        );
        if (!localOnly) saved = await controller.publishDraft(saved.id);
      } else {
        saved = _isEditing
            ? await controller.updateGist(
                id: widget.gistId!,
                description: _descriptionController.text.trim(),
                originalFilename: _originalFilename,
                filename: filename,
                content: content,
              )
            : await controller.createGist(
                description: _descriptionController.text.trim(),
                isPublic: _isPublic,
                filename: filename,
                content: content,
              );
      }

      if (!mounted) return;

      setState(() => _saving = false);
      if (saved == null) {
        setState(() {
          _error =
              ref.read(gistControllerProvider).error ?? 'Could not save gist.';
        });
        return;
      }

      ref.read(editorDirtyProvider).value = false;
      context.replace('/gists/${saved.id}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save gist: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppShell(
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: _saving
                ? null
                : () => context.canPop() ? context.pop() : context.go('/gists'),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(localOnly: true),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _isEditing && !_isDraft
                  ? 'Save copy as draft'
                  : 'Save local draft',
            ),
          ),
          ElevatedButton.icon(
            key: const Key('save-editor-button'),
            onPressed: _saving ? null : () => _save(),
            icon: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.inverseText,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _isEditing && !_isDraft ? 'Save Changes' : 'Publish to GitHub',
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/gists'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
      ],
      child: _loading
          ? const _CenteredMessage(message: 'Loading snippet...')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Snippet' : 'Create Snippet',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Edit a file while preserving the other files in the gist.',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(message: _error),
                ],
                const SizedBox(height: 24),
                if (_files.length > 1)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _originalFilename,
                    decoration: const InputDecoration(
                      labelText: 'File to edit (save before switching)',
                    ),
                    items: [
                      for (final f in _files.values)
                        DropdownMenuItem(
                          value: f.filename,
                          child: Text(f.filename),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (name) async {
                            if (name == null || name == _originalFilename) {
                              return;
                            }
                            final original = _files[_originalFilename];
                            if (_filenameController.text != _originalFilename ||
                                _contentController.text != original?.content) {
                              final discard = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text(
                                    'Discard unsaved file changes?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep editing'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Discard'),
                                    ),
                                  ],
                                ),
                              );
                              if (discard != true || !mounted) return;
                            }
                            setState(() {
                              _originalFilename = name;
                              _filenameController.text = name;
                              _contentController.text = _files[name]!.content;
                            });
                          },
                  ),
                SwitchListTile(
                  title: const Text('Preview'),
                  value: _preview,
                  onChanged: (v) => setState(() => _preview = v),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final settings = _EditorSettings(
                      descriptionController: _descriptionController,
                      filenameController: _filenameController,
                      isPublic: _isPublic,
                      isEditing: _isEditing && !_isDraft,
                      onPrivacyChanged: (value) {
                        ref.read(editorDirtyProvider).value = true;
                        setState(() => _isPublic = value);
                      },
                    );
                    final editor = _preview
                        ? SnippetPreview(
                            content: _contentController.text,
                            filename: _filenameController.text,
                          )
                        : _CodeEditor(controller: _contentController);

                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 310, child: settings),
                              const SizedBox(width: 20),
                              Expanded(child: editor),
                            ],
                          )
                        : Column(
                            children: [
                              settings,
                              const SizedBox(height: 20),
                              editor,
                            ],
                          );
                  },
                ),
              ],
            ),
    );
  }
}

class _EditorSettings extends StatelessWidget {
  const _EditorSettings({
    required this.descriptionController,
    required this.filenameController,
    required this.isPublic,
    required this.isEditing,
    required this.onPrivacyChanged,
  });

  final TextEditingController descriptionController;
  final TextEditingController filenameController;
  final bool isPublic;
  final bool isEditing;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: descriptionController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What does this snippet do? #hashtags supported',
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: descriptionController,
            builder: (_, value, _) => Wrap(
              spacing: 6,
              children: [
                for (final tag in parseTags(value.text))
                  Chip(label: Text('#$tag')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: filenameController,
            decoration: const InputDecoration(
              labelText: 'Filename',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Privacy Level',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Public')),
              ButtonSegment(value: false, label: Text('Secret')),
            ],
            selected: {isPublic},
            onSelectionChanged: isEditing
                ? null
                : (values) => onPrivacyChanged(values.first),
          ),
          if (isEditing) ...[
            const SizedBox(height: 8),
            Text(
              "GitHub doesn't allow changing privacy after creation.",
              style: TextStyle(color: palette.mutedText, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeEditor extends StatelessWidget {
  const _CodeEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 620,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.codeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  const _WindowDot(),
                  const SizedBox(width: 6),
                  const _WindowDot(),
                  const SizedBox(width: 6),
                  const _WindowDot(),
                  const Spacer(),
                  Text(
                    'UTF-8',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  key: const Key('content-field'),
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    color: palette.codeText,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '// Start writing here...',
                    hintStyle: TextStyle(color: Color(0xFF8A8A8A)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.border,
        shape: BoxShape.circle,
      ),
      child: const SizedBox(width: 10, height: 10),
    );
  }
}

class GistDetailScreen extends ConsumerStatefulWidget {
  const GistDetailScreen({super.key, required this.gistId});

  final String gistId;

  @override
  ConsumerState<GistDetailScreen> createState() => _GistDetailScreenState();
}

class _GistDetailScreenState extends ConsumerState<GistDetailScreen> {
  bool _loaded = false;
  bool _raw = false;
  String? _selectedFile;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(gistControllerProvider.notifier).ensureFull(widget.gistId);
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final gist = ref
        .watch(gistControllerProvider)
        .gists
        .where((item) => item.id == widget.gistId);
    final item = gist.isEmpty ? null : gist.first;
    final file = item?.files[_selectedFile] ?? item?.firstFile;
    final content = file?.content ?? '';

    return AppShell(
      actions: [
        IconButton(
          tooltip: _raw ? 'Preview' : 'Raw',
          onPressed: () => setState(() => _raw = !_raw),
          icon: Icon(_raw ? Icons.preview : Icons.code),
        ),
        if (item != null)
          IconButton(
            tooltip: 'Bookmark',
            onPressed: () => ref
                .read(gistControllerProvider.notifier)
                .toggleBookmark(item.id),
            icon: Icon(
              item.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
        if (item != null)
          IconButton(
            tooltip: 'Export gist JSON',
            onPressed: () async {
              try {
                await saveExport(
                  'gist-${item.id}.json',
                  'application/json',
                  Uint8List.fromList(
                    utf8.encode(
                      const JsonEncoder.withIndent('  ').convert(item.toJson()),
                    ),
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            icon: const Icon(Icons.download),
          ),

        IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/gists'),
          icon: const Icon(Icons.arrow_back),
        ),
        if (item != null)
          IconButton(
            tooltip: 'Share',
            onPressed: () => _copyGistLink(context, item),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        if (item != null)
          IconButton(
            tooltip: 'Copy Raw',
            onPressed: () => Clipboard.setData(ClipboardData(text: content)),
            icon: const Icon(Icons.copy),
          ),
        if (item?.htmlUrl.isNotEmpty == true)
          IconButton(
            tooltip: 'Open on GitHub',
            onPressed: () => launchUrl(Uri.parse(item!.htmlUrl)),
            icon: const Icon(Icons.open_in_new),
          ),
        if (item != null)
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.push('/gists/${item.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      child: item == null
          ? _CenteredMessage(
              message: _loaded
                  ? 'Snippet unavailable.'
                  : 'Syncing your snippet...',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description.isEmpty
                                ? 'Untitled Snippet'
                                : item.description,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusPill(
                                label: item.isPublic ? 'Public' : 'Secret',
                                background: item.isPublic
                                    ? paleGreen
                                    : paleYellow,
                                foreground: item.isPublic
                                    ? greenText
                                    : yellowText,
                              ),
                              if (file != null)
                                StatusPill(label: file.filename),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.isDraft
                      ? 'Local draft - not published to GitHub'
                      : 'GitHub gist - cached on this device',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push('/gists/${item.id}/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(item.isDraft ? 'Edit / publish' : 'Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: content)),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy code'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => assignCollections(context, ref, item),
                      icon: const Icon(Icons.folder_outlined),
                      label: const Text('Collections'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await GistCard(gist: item)._confirmDelete(context, ref);
                        if (context.mounted &&
                            ref
                                    .read(gistControllerProvider.notifier)
                                    .findById(item.id) ==
                                null) {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/gists');
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in item.files.values)
                      ChoiceChip(
                        label: Text(f.filename),
                        selected: f.filename == file?.filename,
                        onSelected: (_) =>
                            setState(() => _selectedFile = f.filename),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.codeSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          border: Border(
                            bottom: BorderSide(color: palette.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            const _WindowDot(),
                            const SizedBox(width: 6),
                            const _WindowDot(),
                            const SizedBox(width: 6),
                            const _WindowDot(),
                            const Spacer(),
                            Text(
                              file?.filename ?? 'snippet.txt',
                              style: TextStyle(
                                color: palette.mutedText,
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: _raw
                            ? SelectableText(
                                content,
                                style: TextStyle(
                                  color: palette.codeText,
                                  fontFamily: 'monospace',
                                ),
                              )
                            : SnippetPreview(
                                content: content,
                                filename: file?.filename ?? 'snippet.txt',
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.profile, required this.size});

  final GistProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: profile.avatarUrl.isEmpty
              ? Center(
                  child: Text(
                    profile.githubUsername.isEmpty
                        ? 'G'
                        : profile.githubUsername[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                )
              : Image.network(
                  profile.avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      profile.githubUsername[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paleRed,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: redText, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 96),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Future<void> assignCollections(
  BuildContext context,
  WidgetRef ref,
  LocalGist gist,
) async {
  final profileId = ref.read(sessionControllerProvider).profile?.id;
  if (profileId == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'gist_hub_playlists_$profileId';
    final groups = (jsonDecode(prefs.getString(key) ?? '{}') as Map).map(
      (k, v) => MapEntry('$k', List<String>.from(v as List)),
    );
    if (!context.mounted) return;
    final selected = groups.entries
        .where((e) => e.value.contains(gist.id))
        .map((e) => e.key)
        .toSet();
    final save = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Add to collections'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (groups.isEmpty)
                    const Text(
                      'Create a collection from the Collections tab first.',
                    ),
                  for (final name in groups.keys)
                    CheckboxListTile(
                      title: Text(name),
                      value: selected.contains(name),
                      onChanged: (v) => update(() {
                        v == true ? selected.add(name) : selected.remove(name);
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    if (ref.read(sessionControllerProvider).profile?.id != profileId) return;
    for (final entry in groups.entries) {
      entry.value.remove(gist.id);
      if (selected.contains(entry.key)) entry.value.add(gist.id);
    }
    await prefs.setString(key, jsonEncode(groups));
    ref.read(collectionsRevisionProvider.notifier).changed();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collections could not be saved: $e')),
      );
    }
  }
}
