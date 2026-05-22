import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/tracking/tracking_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/spots/spots_screen.dart';
import 'presentation/screens/academy/academy_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/historial/historial_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'SUPReady', debugShowCheckedModeBanner: false,
    theme: SupTheme.darkTheme, routerConfig: _router,
  );
}

final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/home',     builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/spots',    builder: (_, __) => const SpotsScreen()),
        GoRoute(path: '/track',    builder: (_, __) => const TrackingScreen()),
        GoRoute(path: '/academy',  builder: (_, __) => const AcademyScreen()),
        GoRoute(path: '/profile',  builder: (_, __) => const ProfileScreen()),
      ],
    ),
    // Historial fuera del shell (pantalla completa)
    GoRoute(path: '/historial', builder: (_, __) => const HistorialScreen()),
  ],
);

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final tabs = [
      (path: '/home',    icon: Icons.home_outlined,          selIcon: Icons.home,         label: 'Inicio'),
      (path: '/spots',   icon: Icons.location_on_outlined,   selIcon: Icons.location_on,  label: 'Spots'),
      (path: '/track',   icon: Icons.surfing,                selIcon: Icons.surfing,       label: 'Remada'),
      (path: '/academy', icon: Icons.school_outlined,        selIcon: Icons.school,        label: 'Academia'),
      (path: '/profile', icon: Icons.person_outline,         selIcon: Icons.person,        label: 'Perfil'),
    ];
    final currentIndex = tabs.indexWhere((t) => t.path == location).clamp(0, tabs.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: SupColors.surface,
        indicatorColor: SupColors.cyanNeonDim,
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon, color: SupColors.textSecondary),
          selectedIcon: Icon(t.selIcon, color: SupColors.cyanNeon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}
