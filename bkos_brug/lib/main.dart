import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'services/bkos_service.dart';
import 'screens/connect_screen.dart';
import 'screens/io_screen.dart';
import 'screens/netwerk_screen.dart';
import 'theme.dart';

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
      title: 'BKOS Brug',
      theme: bkosTheme(),
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
    final svc = context.watch<BkosService>();
    final bootnaam = svc.info?.bootnaam ?? svc.info?.naam ?? '';

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bootnaam.isNotEmpty)
            Container(
              width: double.infinity,
              color: kNavBar,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Text(
                bootnaam,
                style: const TextStyle(
                  color: kBeigeZacht, fontSize: 11, letterSpacing: 0.5),
                textAlign: TextAlign.center,
              ),
            ),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.toggle_on), label: 'IO Paneel'),
              NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'Netwerk'),
            ],
          ),
        ],
      ),
    );
  }
}
