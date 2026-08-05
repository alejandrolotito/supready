import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/score_card_widget.dart'; // Importamos nuestro nuevo widget!


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ----------------------------------------------------
    // SIMULACIÓN DE DATOS: Aquí es donde en el futuro se leerán de los Providers.
    // POR AHORA, USAMOS UN ESTADO FIJO PARA PROBAR LA UI.
    // ----------------------------------------------------
    
    final String tituloDashboard = "SUPREADY - Dashboard Operativo";
    const SafetyScore scoreEjemplo = SafetyScore.ROJO; // Forzamos Rojo para la prueba inicial

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("supReady"),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0, // Eliminamos la sombra para look más moderno
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // EL SCORE CARD (¡El resultado de todo!)
            ScoreCardWidget(
              score: scoreEjemplo, 
              mensajesRiesgo: [
                "🚨 ¡ALERTA MÁXIMA! No navegar por riesgo de rayos.", 
                "Debe suspenderse la actividad debido a Rayos."
              ],
              titulo: 'SCORE GENERAL DE SEGURIDAD',
            ),

            // Aquí irían los otros módulos que se conectarán después (Viento, Marea...)
            const SizedBox(height: 40),
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text("🗺️ Mapa y Rutas (Próxima Fase)", style: TextStyle(color: Colors.grey[400], fontSize: 18)),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: () {}, child: Text("Abrir Mapa de Navegación")),
                    ],
                )
            ),

          ],
        ),
      ),
    );
  }
}
