import 'package:flutter/material.dart';
import 'package:supready/core/theme/app_theme.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFF1E293B), // surface
              Color(0xFF0b1326), // background
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top section (Logo and titles)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                          shape: BoxShape.circle,
                        ),
                        child: Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBx4PRrietUuW_pIQs3IiuAsjHNSuuK55fy-v59qBatj-BchxDtIwAUWb5L1Gkx3d0sAQzIaddU0kNroCCT2tAKRUkY6-PD44VVBdUwli07qBldNOD-HqH-pbzsqsblp8j0cFQVTGyal6o3aFCKtLp2PqBAFWp18gnXV6ISPlM4aDZ01bdP2gEpt8q754Plkc_wnApgmBEcul3JeJo9ITrrsik_hPvV3MKM3h5c95yNGHNCQGEEjSbJX4eyJ6EqV-4jD_XY-I8QvmE',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.surfing, size: 100, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'SUP READY',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 280,
                        child: Text(
                          'EQUIPAMIENTO TÉCNICO Y MONITOREO PROFESIONAL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom section (Actions)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const DashboardScreen()),
                        );
                      },
                      icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.black),
                      label: const Text(
                        'Continuar con Google',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF222a3d), // surface-container-high
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CREAR CUENTA CON EMAIL',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes cuenta? ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Inicia Sesión',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                        children: [
                          TextSpan(text: 'Al continuar, aceptas nuestros\n'),
                          TextSpan(text: 'Términos de Servicio', style: TextStyle(color: AppTheme.primary)),
                          TextSpan(text: ' y nuestra '),
                          TextSpan(text: 'Política de Privacidad', style: TextStyle(color: AppTheme.primary)),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
