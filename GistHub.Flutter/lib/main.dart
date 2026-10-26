import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/app_state.dart';
import 'src/screens.dart';
import 'src/theme.dart';
import 'src/flows.dart';
import 'src/tools_screen.dart';
import 'src/code_image_screen.dart';
import 'src/appearance.dart';

void main() {
  runApp(const ProviderScope(child: GistHubApp()));
}

class GistHubApp extends ConsumerStatefulWidget {
  const GistHubApp({super.key, this.initialLocation = '/'});

  final String initialLocation;

  @override
  ConsumerState<GistHubApp> createState() => _GistHubAppState();
}

class _GistHubAppState extends ConsumerState<GistHubApp> {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    router = GoRouter(
      initialLocation: widget.initialLocation,
      redirect: (context, state) {
        final session = ref.read(sessionControllerProvider);
        if (session.isRestoring) return null;

        final path = state.uri.path;

        if (!session.isAuthenticated &&
            (path.startsWith('/gists') ||
                path == '/collections' ||
                path == '/saved')) {
          return '/login';
        }
        return null;
      },
      errorBuilder: (context, state) => AppShell(
        routePath: state.uri.path,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page not found'),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const StartScreen()),
        GoRoute(path: '/discovery', builder: (_, _) => const FeedScreen()),
        GoRoute(
          path: '/slh-collection',
          builder: (_, _) => const FeedScreen(slh: true),
        ),
        GoRoute(
          path: '/slh-collection/:id',
          builder: (_, s) => PublicDetailScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/view/:id',
          builder: (_, s) => PublicDetailScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/collections',
          builder: (_, _) => const CollectionsScreen(),
        ),
        GoRoute(
          path: '/tools/code-image',
          builder: (_, _) => const CodeImageScreen(),
        ),
        GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
        GoRoute(
          path: '/appearance',
          builder: (_, _) => const AppearanceScreen(),
        ),
        GoRoute(path: '/trending', builder: (_, _) => const TrendingScreen()),
        GoRoute(path: '/my-gists', redirect: (_, _) => '/gists'),
        GoRoute(path: '/editor', redirect: (_, _) => '/gists/new'),
        GoRoute(
          path: '/editor/:id',
          redirect: (_, s) => '/gists/${s.pathParameters['id']}/edit',
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/saved',
          builder: (_, _) => const CollectionsScreen(savedOnly: true),
        ),
        GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        GoRoute(path: '/gists', builder: (_, _) => const GistsScreen()),
        GoRoute(
          path: '/gists/new',
          onExit: (context, _) => confirmEditorExit(context, ref),
          builder: (_, _) => const EditorScreen(),
        ),
        GoRoute(
          path: '/gists/:id',
          builder: (_, state) =>
              GistDetailScreen(gistId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/gists/:id/edit',
          onExit: (context, _) => confirmEditorExit(context, ref),
          builder: (_, state) =>
              EditorScreen(gistId: state.pathParameters['id']),
        ),
      ],
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, (_, _) => router.refresh());
    final themeMode = ref.watch(themeModeControllerProvider);
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GistHub',
      theme: buildGistHubTheme(Brightness.light, appearance: appearance),
      darkTheme: buildGistHubTheme(Brightness.dark, appearance: appearance),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
