# SUPReady — Módulo de Salidas Grupales
## Especificación Funcional v1.0

---

## Visión

Permitir que palistas de la misma zona se organicen para remar juntos: crear salidas con fecha/hora/spot, invitar amigos o abrirlas a la comunidad, y remar en grupo con tracking compartido en tiempo real.

---

## Casos de uso principales

### CU-G1: Crear una salida
El organizador elige spot, fecha, hora, nivel requerido (principiante/intermedio/avanzado) y cupos máximos. Puede ser **pública** (visible a todos los usuarios del área) o **privada** (solo con link/código de invitación).

### CU-G2: Unirse a una salida
Cualquier usuario logueado puede explorar salidas cercanas en un mapa o lista. Filtra por nivel, distancia y fecha. Con un tap se anota — el organizador recibe notificación.

### CU-G3: Tracking grupal en vivo
Durante la salida, todos los participantes ven sus posiciones en tiempo real en el mismo mapa. El organizador puede ver quién va rezagado o se desvió.

### CU-G4: Chat de la salida
Canal de mensajes asociado a la salida: antes para coordinar, durante para avisos ("esperame en el muelle"), después para compartir fotos y estadísticas.

### CU-G5: Resumen grupal post-remada
Al finalizar, se genera una tarjeta compartible con el mapa de todos los tracks superpuestos, estadísticas del grupo (distancia media, velocidad media, quién fue más rápido) y foto grupal.

---

## Arquitectura técnica

### Backend requerido (nuevo — la app actual es 100% offline)

```
Firebase Firestore (o Supabase)
├── /salidas/{salidaId}
│   ├── organizadorId, spotId, fecha, horaInicio
│   ├── nivel, cuposMax, esPublica, estado (abierta/en_curso/finalizada)
│   ├── participantes: [{usuarioId, nombre, avatar, estado}]
│   └── chat: subcollection de mensajes
│
├── /posiciones_live/{salidaId}/{usuarioId}
│   └── lat, lon, velocidad, timestamp  ← actualizado cada 5s durante la salida
│
└── /usuarios/{usuarioId}
    └── salidas: [salidaId, ...]  ← historial de participación
```

### Firebase Realtime Database (para posiciones en vivo)
Las posiciones se escriben con `set()` cada 5s y se leen con `onValue` stream — latencia < 500ms.

### Notificaciones Push (Firebase Cloud Messaging)
- Cuando alguien se anota a tu salida
- Recordatorio 1h antes de la salida
- Cuando el organizador inicia la salida (GPS empieza)
- Alerta si un participante no tiene movimiento (SOS grupal)

---

## Pantallas nuevas

| Pantalla | Descripción |
|---|---|
| `/salidas` | Nueva tab en nav. Lista + mapa de salidas cercanas |
| `/salidas/crear` | Form: spot (dropdown), fecha/hora, nivel, cupos, descripción |
| `/salidas/{id}` | Detalle: participantes, clima del spot, chat, botón unirse |
| `/salidas/{id}/live` | Mapa en tiempo real con todos los tracks durante la salida |
| `/salidas/{id}/resumen` | Mapa grupal + stats + foto grupal post-remada |

---

## Modelo de datos Flutter

```dart
class SalidaGrupal {
  final String salidaId;
  final String organizadorId;
  final int spotId;
  final DateTime fechaHora;
  final NivelExperiencia nivelMinimo;
  final int cuposMax;
  final bool esPublica;
  final EstadoSalida estado; // abierta, en_curso, finalizada, cancelada
  final List<ParticipanteSalida> participantes;
  final String? descripcion;
}

class ParticipanteSalida {
  final String usuarioId;
  final String nombre;
  final String? avatarUrl;
  final EstadoParticipante estado; // confirmado, en_espera, remando, finalizado
  final LatLng? posicionLive; // null si no está remando
}
```

---

## Flujo de usuario típico

```
Ale abre la app el viernes por la noche
  → ve en /salidas que hay una salida el sábado 8am en Playa Grande
  → el clima del spot muestra VERDE para ese horario (previsión 48h)
  → se anota con un tap
  → recibe notificación: "Mañana remás con 4 palistas en Playa Grande 🏄"

Sábado 7:50am — el organizador inicia la salida
  → todos los anotados reciben notificación "¡La salida comenzó!"
  → cada uno ve en /salidas/{id}/live un mapa con los 5 tracks en tiempo real
  → si alguien se queda atrás, el organizador lo ve y puede esperarlo

Al terminar → resumen grupal con tracks superpuestos y stats comparativas
```

---

## Estimación de desarrollo

| Módulo | Complejidad | Tiempo estimado |
|---|---|---|
| Backend Firebase setup | Media | 1 semana |
| Crear/unirse a salidas | Media | 1 semana |
| Tracking grupal en tiempo real | Alta | 2 semanas |
| Chat de salida | Baja | 3 días |
| Resumen grupal + mapa | Media | 1 semana |
| Notificaciones push | Media | 3 días |
| **Total estimado** | | **~6 semanas** |

---

## Dependencias Flutter a agregar

```yaml
# Firebase (realtime para posiciones)
firebase_database: ^10.x
firebase_messaging: ^14.x  # push notifications
cloud_firestore: ^4.x       # salidas, chat, usuarios

# UI
flutter_chat_ui: ^1.x       # chat listo para usar
```

---

## Consideraciones de privacidad

- La posición en vivo solo es visible a los participantes confirmados de esa salida
- Las salidas privadas no aparecen en el mapa público
- El usuario puede desactivar el sharing de posición en cualquier momento (modo "fantasma")
- Los datos de posición live se borran automáticamente 2h después de finalizada la salida

---

*Documento generado: SUPReady v3.3 — Mayo 2026*
