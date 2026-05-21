import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/tracking/tracking_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/spots/spots_screen.dart';
import 'presentation/screens/academy/academy_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación bloqueada para sesiones de agua
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar transparente sobre fondo oscuro
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const SupReadyApp());
}

class SupReadyApp extends StatelessWidget {
  const SupReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SUPReady',
      debugShowCheckedModeBanner: false,
      theme: SupTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

// ============================================================
// Router (go_router)
// ============================================================
final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/spots',   builder: (_, __) => const SpotsScreen()),
        GoRoute(path: '/track',   builder: (_, __) => const TrackingScreen()),
        GoRoute(path: '/academy', builder: (_, __) => const AcademyScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
  ],
);

// ============================================================
// Shell con Bottom Navigation Bar
// ============================================================
class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  static const _tabs = [
    ('/home',    Icons.home_outlined,       Icons.home,           'Inicio'),
    ('/spots',   Icons.location_on_outlined, Icons.location_on,   'Spots'),
    ('/track',   Icons.surfing,             Icons.surfing,         'Remada'),
    ('/academy', Icons.school_outlined,     Icons.school,         'Academia'),
    ('/profile', Icons.person_outline,      Icons.person,         'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => t.$1 == location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: SupColors.surface,
        indicatorColor: SupColors.cyanNeonDim,
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.$2, color: SupColors.textSecondary),
          selectedIcon: Icon(t.$3, color: SupColors.cyanNeon),
          label: t.$4,
        )).toList(),
      ),
    );
  }
}
