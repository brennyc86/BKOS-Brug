import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'services/bkos_service.dart';
import 'screens/connect_screen.dart';
import 'screens/io_screen.dart';
import 'screens/netwerk_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BkosService(),
      child: const BkosApp(),
    ),
  );
}

class BkosApp extends StatelessWidget {
  const BkosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BKOS',
      theme: _bkosTheme(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/connect',
  routes: [
    GoRoute(path: '/connect', builder: (_, __) => const ConnectScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/io', builder: (_, __) => const IoScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/netwerk', builder: (_, __) => const NetwerkScreen()),
        ]),
      ],
    ),
  ],
  redirect: (context, state) {
    final svc = context.read<BkosService>();
    final verbonden = svc.verbonden;
    final opConnect = state.matchedLocation == '/connect';
    if (!verbonden && !opConnect) return '/connect';
    if (verbonden && opConnect) return '/io';
    return null;
  },
);

class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.toggle_on), label: 'IO Paneel'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'Netwerk'),
        ],
      ),
    );
  }
}

ThemeData _bkosTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A3A5C), // marine blauw
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D1B2A),
    cardColor: const Color(0xFF1A2E42),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D1B2A),
      foregroundColor: Color(0xFFB8D4EA),
    ),
  );
}
