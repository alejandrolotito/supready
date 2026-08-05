import 'package:flutter/material.dart';

// --- ENUMERACIÓN DE ESTADOS PARA CLARIDAD ---
enum SafetyScore {
  VERDE, // Seguro (Safe)
  AMARILLO, // Precaución (Caution)
  ROJO,    // Peligro (Danger)
}

class ScoreCardWidget extends StatelessWidget {
  final SafetyScore score;
  final List<String> mensajesRiesgo;
  final String titulo;

  const ScoreCardWidget({
    super.key, 
    required this.score, 
    required this.mensajesRiesgo, 
    required this.titulo
  });

  @override
  Widget build(BuildContext context) {
    // Lógica de color basada en el score recibido
    Color backgroundColor;
    Color titleColor;

    switch (score) {
      case SafetyScore.VERDE:
        backgroundColor = const Color(0xFF10B981); // Esmeralda - Confianza máxima
        titleColor = Colors.white;
        break;
      case SafetyScore.AMARILLO:
        backgroundColor = const Color(0xFFFFC107); // Amarillo fuerte
        titleColor = const Color(0xFF333333); // Negro/Gris oscuro para contraste
        break;
      case SafetyScore.ROJO:
        backgroundColor = const Color(0xFFDC3545); // Rojo de peligro
        titleColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 6), // Sombra de bajo contraste para reducir reflejos directos
          ),
          BoxShadow(
            color: Colors.transparent,
            blurRadius: 5,
            offset: const Offset(0, -2), // Para dar la sensación de elevarlo ligeramente
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- TÍTULO Y SCORE VISIBLE ---
          Text(titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: Colors.grey[400])),
          const SizedBox(height: 15),

          // Botón o Indicador Central del Score (El Semáforo)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: backgroundColor,
              boxShadow: [BoxShadow(blurRadius: 15, color: Colors.black.withOpacity(0.3))]
            ),
            child: Text(
              '${scoreToString(score).toUpperCase()} ${getColorEmoji(score)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: titleColor),
            ),
          ),
          const SizedBox(height: 25),

          // --- MENSAJES DE ALERTA Y RECOMENDACIONES (La explicación) ---
          Text("Recomendación de Seguridad:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          ...mensajesRiesgo.map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text("• $msg", style: TextStyle(fontSize: 15, color: Colors.white70)),
            )).toList(),

          // Si no hay mensajes de riesgo, mostrar un mensaje positivo por defecto.
           if (mensajesRiesgo.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text("👍 Condiciones óptimas detectadas. ¡Disfruten la navegación!", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // --- Métodos Auxiliares de Apariencia ---
  String scoreToString(SafetyScore s) {
    switch (s) {
      case SafetyScore.VERDE: return "SEGURO";
      case SafetyScore.AMARILLO: return "PRECAUCIÓN";
      case SafetyScore.ROJO: return "¡PELIGRO!";
    }
  }

  String getColorEmoji(SafetyScore s) {
    switch (s) {
      case SafetyScore.VERDE: return '✅';
      case SafetyScore.AMARILLO: return '⚠️';
      case SafetyScore.ROJO: return '🚨';
    }
  }
}

// ====================================================
// USO DE EJEMPLO (Para probar en main.dart)
// ====================================================

void mainExample() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            // EJEMPLO DE ROJO (Pelígro Máximo)
            ScoreCardWidget(
              score: SafetyScore.ROJO, 
              mensajesRiesgo: ['🚨 ¡PELIGRO MÁXIMO! No navegar por riesgo de rayos.', 'Debe suspenderse la actividad debido a Rayos.'],
              titulo: 'SCORE GENERAL DE SEGURIDAD',
            ),
            const SizedBox(height: 50),
            // EJEMPLO DE AMARILLO (Precaución)
            ScoreCardWidget(
              score: SafetyScore.AMARILLO, 
              mensajesRiesgo: ['🟡 PRECAUCIÓN: El viento requiere ajustes constantes en la trayectoria.', '⚠️ ADVERTENCIA: La corriente contraria combinada genera esfuerzo físico.'],
              titulo: 'SCORE GENERAL DE SEGURIDAD',
            ),
             const SizedBox(height: 50),
            // EJEMPLO DE VERDE (Óptimo)
             ScoreCardWidget(
              score: SafetyScore.VERDE, 
              mensajesRiesgo: [],
              titulo: 'SCORE GENERAL DE SEGURIDAD',
            ),
          ],
        ),
      ),
    ),
  );
}
// Para probar este código, descomenta la función mainExample() y ejecútalo en un entorno Flutter.
<|"|>}<tool_call|>### 🎨 Análisis del Componente (Lo que acabas de crear)

Este `ScoreCardWidget` es el **cerebro visual** de tu aplicación. Cumple con varios requisitos clave:

1.  **Contraste Anti-Water:** Usa fondos oscuros y textos claros, ideal para leer bajo luz solar directa o en reflejos del agua.
2.  **Jerarquía Visual:** El score grande (el semáforo) es lo primero que el usuario verá y entenderá.
3.  **Modularidad:** Separa la lógica visual de la lógica de negocio. Si mañana cambias la definición de "Peligro", solo tocas este widget, no todo el código.

### 🎯 Conexión con Flutter/Dart (El Uso)

Ahora que tienes el componente visual, recuerda cómo se usará en `home_screen.dart`:

1.  **Lógica:** El `calcularScore()` (tu motor backend) debe ejecutarse primero.
2.  **Visualización:** Una vez que obtienes el resultado (`resultado`), simplemente lo pasas al widget:

   ```dart
   // Dentro de HomeScreen, después de calcular el score...
   final result = calcularScore(...); // El motor calcula esto
   
   Widget build(BuildContext context, WidgetRef ref) {
       return Column(
           children: [
               ScoreCardWidget(
                   score: ScoreSafety.values.fromName(result.score!), // Convertir string a ENUM
                   mensajesRiesgo: result.mensaje,
                   titulo: 'SCORE GENERAL DE SEGURIDAD'
               ),
               // ... resto de widgets (Viento, Marea)
           ],
       );
   }
