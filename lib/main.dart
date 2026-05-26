import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/tracking/tracking_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/spots/spots_screen.dart';
import 'presentation/screens/academy/academy_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/historial/historial_screen.dart';
import 'presentation/screens/prevision/prevision_screen.dart';
import 'presentation/screens/salidas/salidas_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Check if onboarding was completed
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(SupReadyApp(initialRoute: onboardingDone ? '/home' : '/onboarding'));
}

class SupReadyApp extends StatelessWidget {
  final String initialRoute;
  const SupReadyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'SUPReady', debugShowCheckedModeBanner: false,
    theme: SupTheme.darkTheme,
    routerConfig: _buildRouter(initialRoute),
  );
}

GoRouter _buildRouter(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    // Onboarding (sin bottom nav)
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

    // Shell con bottom nav
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/home',      builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/spots',     builder: (_, __) => const SpotsScreen()),
        GoRoute(path: '/track',     builder: (_, __) => const TrackingScreen()),
        GoRoute(path: '/prevision', builder: (_, __) => const PrevisionScreen()),
        GoRoute(path: '/salidas',   builder: (_, __) => const SalidasScreen()),
      ],
    ),

    // Pantallas full screen (sin bottom nav)
    GoRoute(path: '/historial', builder: (_, __) => const HistorialScreen()),
    GoRoute(path: '/profile',   builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/academy',   builder: (_, __) => const AcademyScreen()),
    GoRoute(path: '/chat',      builder: (context, state) => const SalidasScreen()),
  ],
);

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final tabs = [
      (path: '/home',      icon: Icons.home_outlined,        selIcon: Icons.home,         label: 'Inicio'),
      (path: '/spots',     icon: Icons.location_on_outlined, selIcon: Icons.location_on,  label: 'Spots'),
      (path: '/track',     icon: Icons.surfing,              selIcon: Icons.surfing,       label: 'Remar'),
      (path: '/prevision', icon: Icons.wb_cloudy_outlined,   selIcon: Icons.wb_cloudy,     label: 'Tiempo'),
      (path: '/salidas',   icon: Icons.group_outlined,       selIcon: Icons.group,         label: 'Salidas'),
    ];
    final idx = tabs.indexWhere((t) => t.path == location).clamp(0, tabs.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: SupColors.surface,
        indicatorColor: SupColors.cyanNeonDim,
        selectedIndex: idx,
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
