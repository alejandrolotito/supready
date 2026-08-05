# PRD — SUPReady v2.0
## Product Requirements Document — Stand Up Paddle Platform

**Versión:** 2.0  
**Fecha:** Julio 2026  
**Stack:** Flutter + Firebase + SQLite  
**Proyecto Firebase:** supready (#82783760497)  

---

## 1. Resumen Ejecutivo y Stack Tecnológico

### 1.1 Visión del Producto

SUPReady es la plataforma de referencia para la comunidad de Stand Up Paddle en Argentina y Latinoamérica. Resuelve tres pilares fundamentales: **navegación segura** (GPS, clima, alertas), **comunidad** (spots, salidas grupales, chat) y **seguridad activa** (SOS, alertas offshore, previsión 48h).

### 1.2 Stack Tecnológico

| Capa | Tecnología | Justificación |
|------|-----------|---------------|
| Frontend | Flutter 3.22.3 (Dart) | Un codebase → Android + iOS. Rendimiento nativo en mapas y GPS |
| Estado global | Riverpod ^2.5.1 | StreamProvider reactivo, sin boilerplate, testeable |
| Base local | SQLite (sqflite) | Offline-first: rutas GPS, favoritos, sesiones sin conexión |
| Base cloud | Firebase Firestore | Tiempo real: spots, salidas grupales, chat, participantes |
| Auth | Firebase Auth + Google Sign-In | SHA-1: EC:76:CA:0D:CD:90:B9:75:ED:A9:6D:26:5A:D3:E8:C9:5B:93:34:6D |
| Clima | Open-Meteo Marine API | Gratuito, sin key, viento en nudos, olas, mareas, tormenta |
| Mapas | flutter_map + OpenStreetMap | Sin límites de requests, funciona offline con tiles cacheados |
| GPS background | flutter_foreground_task ^8.10.0 | ForegroundService Android para GPS con pantalla apagada |
| WakeLock | wakelock_plus ^1.1.4 | Mantiene CPU activa aunque pantalla se apague |

### 1.3 Principios de Arquitectura

```
┌─────────────────────────────────────────────┐
│              PRESENTACIÓN (Flutter)          │
│  Riverpod StreamProviders → ConsumerWidgets  │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│           DOMINIO / REPOSITORIOS            │
│   StatsRepository, FirestoreService,        │
│   ClimaService, TrackingService             │
└──────────┬──────────────┬───────────────────┘
           │              │
┌──────────▼────┐  ┌──────▼──────────────────┐
│  SQLite LOCAL │  │  Firebase (Cloud)        │
│  - Rutas GPS  │  │  - /users/{uid}          │
│  - Coordenadas│  │  - /spots                │
│  - Favoritos  │  │  - /group_trips          │
│  - Usuarios   │  │  - /users/{uid}/sessions │
└───────────────┘  └─────────────────────────┘
```

---

## 2. Arquitectura de Datos

### 2.1 SQLite Local (Offline-First)

```sql
-- Usuarios locales
CREATE TABLE usuarios (
  usuario_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre       TEXT NOT NULL,
  apellido     TEXT NOT NULL,
  email        TEXT NOT NULL UNIQUE,
  google_id    TEXT UNIQUE,
  avatar_url   TEXT,
  nivel_experiencia TEXT DEFAULT 'principiante'
);

-- Spots favoritos locales
CREATE TABLE spots (
  spot_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre      TEXT NOT NULL,
  latitud     REAL NOT NULL,
  longitud    REAL NOT NULL,
  descripcion TEXT DEFAULT '',
  es_favorito INTEGER DEFAULT 0
);

-- Sesiones de remada
CREATE TABLE rutas_trazadas (
  ruta_id          INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id       INTEGER NOT NULL,
  spot_id          INTEGER NOT NULL,
  distancia_total_km REAL DEFAULT 0,
  duracion_minutos   INTEGER DEFAULT 0,
  velocidad_media    REAL DEFAULT 0,
  velocidad_maxima   REAL DEFAULT 0,
  iniciada_en      TEXT NOT NULL,
  finalizada_en    TEXT,
  sincronizado     INTEGER DEFAULT 0
);

-- Coordenadas GPS (guardado inmediato en cada punto)
CREATE TABLE coordenadas_ruta (
  coordenada_id INTEGER PRIMARY KEY AUTOINCREMENT,
  ruta_id       INTEGER NOT NULL,
  latitud       REAL NOT NULL,
  longitud      REAL NOT NULL,
  secuencia     INTEGER NOT NULL,
  velocidad_kmh REAL DEFAULT 0,
  timestamp     TEXT NOT NULL
);
CREATE INDEX idx_coords ON coordenadas_ruta(ruta_id, secuencia);

-- Salidas grupales (cache local)
CREATE TABLE salidas_grupales (
  salida_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  firestore_id   TEXT,
  organizador_id INTEGER NOT NULL,
  spot_nombre    TEXT NOT NULL,
  fecha_hora     TEXT NOT NULL,
  nivel_minimo   TEXT DEFAULT 'todos',
  cupos_max      INTEGER DEFAULT 10,
  es_publica     INTEGER DEFAULT 1,
  estado         TEXT DEFAULT 'abierta',
  descripcion    TEXT DEFAULT '',
  sincronizado   INTEGER DEFAULT 0
);
```

### 2.2 Firestore Schema (Colecciones Cloud)

```json
// /users/{uid}
{
  "name":          "String — nombre del usuario",
  "email":         "String — email Google",
  "photoUrl":      "String | null — URL avatar",
  "favoriteSpotId":"String | null — ID de /spots",
  "nivel":         "String — principiante|intermedio|avanzado",
  "createdAt":     "Timestamp",
  "updatedAt":     "Timestamp"
}

// /users/{uid}/sessions/{sessionId}
{
  "startTime":     "Timestamp",
  "endTime":       "Timestamp | null",
  "status":        "String — active|completed",
  "spotId":        "Integer",
  "distanciaKm":   "Double",
  "duracionMin":   "Integer",
  "velocidadMedia":"Double"
}

// /users/{uid}/sessions/{sessionId}/points/{pointId}
{
  "latitude":  "Double",
  "longitude": "Double",
  "speed":     "Double — m/s",
  "velKmh":    "Double",
  "sequence":  "Integer",
  "timestamp": "Timestamp"
}

// /spots/{spotId}
{
  "name":      "String",
  "location":  "GeoPoint — {lat, lng}",
  "isPublic":  "Boolean",
  "createdBy": "String — uid",
  "currentConditions": {
    "windSpeedKnots":   "Double",
    "windDirectionStr": "String — N|NE|E|SE|S|SO|O|NO",
    "tideHeight":       "Double — metros",
    "tideTrend":        "String — SUBIENDO|BAJANDO|ESTABLE",
    "waveHeight":       "Double — metros",
    "temperature":      "Double — °C agua",
    "thunderstormRisk": "Boolean",
    "lastUpdated":      "Timestamp"
  }
}

// /group_trips/{tripId}
{
  "title":           "String — nombre de la salida",
  "description":     "String",
  "organizerId":     "String — uid",
  "organizerName":   "String",
  "date":            "Timestamp",
  "maxParticipants": "Integer",
  "status":          "String — open|active|completed|cancelled",
  "attendees":       "Array<String> — uids de participantes",
  "nivelMinimo":     "String — todos|principiante|intermedio|avanzado",
  "spotId":          "Integer",
  "spotNombre":      "String",
  "isPublic":        "Boolean",
  "createdAt":       "Timestamp"
}

// /group_trips/{tripId}/messages/{messageId}
{
  "senderId":   "String — uid",
  "senderName": "String",
  "avatarUrl":  "String | null",
  "text":       "String",
  "timestamp":  "Timestamp"
}
```

### 2.3 Reglas de Seguridad Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuth() { return request.auth != null; }
    function isOwner(uid) { return request.auth.uid == uid; }

    // Usuarios: solo el dueño puede escribir
    match /users/{userId} {
      allow read: if isAuth();
      allow write: if isAuth() && isOwner(userId);

      match /sessions/{sessionId} {
        allow read, write: if isAuth() && isOwner(userId);
        match /points/{pointId} {
          allow read, write: if isAuth() && isOwner(userId);
        }
      }
    }

    // Spots: cualquier usuario autenticado puede crear/leer
    // Solo el creador o sistema puede actualizar condiciones
    match /spots/{spotId} {
      allow read: if isAuth();
      allow create: if isAuth();
      allow update: if isAuth() && (
        resource.data.createdBy == request.auth.uid ||
        request.resource.data.diff(resource.data)
          .affectedKeys().hasOnly(['currentConditions'])
      );
    }

    // Salidas grupales: chat solo para attendees
    match /group_trips/{tripId} {
      allow read: if isAuth();
      allow create: if isAuth();
      allow update: if isAuth() && (
        resource.data.organizerId == request.auth.uid ||
        request.resource.data.diff(resource.data)
          .affectedKeys().hasOnly(['attendees'])
      );
      allow delete: if isAuth()
          && resource.data.organizerId == request.auth.uid;

      match /messages/{messageId} {
        allow read, create: if isAuth()
            && request.auth.uid in get(
              /databases/$(database)/documents/group_trips/$(tripId)
            ).data.attendees
            && get(
              /databases/$(database)/documents/group_trips/$(tripId)
            ).data.status != 'completed';
        allow update, delete: if false;
      }
    }
  }
}
```

---

## 3. Especificación Funcional de Módulos Core

### 3.1 Módulo de Navegación y Rutas

**Configuración GPS óptima para SUP:**

```dart
// distanceFilter: 3m → suficientes puntos para ruta fiel
// intervalDuration: 5s → balance batería/precisión
AndroidSettings(
  accuracy:         LocationAccuracy.high,
  distanceFilter:   3,                        // metros
  intervalDuration: Duration(seconds: 5),
)
```

**Estrategia de persistencia (pantalla apagada):**

1. `WakelockPlus.enable()` → CPU activa aunque pantalla se apague
2. `ForegroundService` → notificación persistente, Android no mata el proceso
3. **SQLite: guardado INMEDIATO** en cada punto GPS recibido
4. **Firebase: WriteBatch** flush cada 5 puntos (~25s)
5. **Timer backup** cada 30s: guarda heartbeat aunque no haya movimiento

**Estados del semáforo SUPReady:**

| Condición | Estado | Color |
|-----------|--------|-------|
| Viento < 9 kts + olas < 0.5m + sin tormenta | ÓPTIMAS | 🟢 Verde |
| Viento 9-15 kts o olas 0.5-1m o lluvia >60% | PRECAUCIÓN | 🟡 Amarillo |
| Viento > 15 kts o olas > 1m o tormenta eléctrica | PELIGRO | 🔴 Rojo |

### 3.2 Módulo de Spots

**Campos de un Spot:**
- Nombre, coordenadas (GeoPoint), tipo de agua (río/lago/mar/estuario)
- Nivel mínimo recomendado
- `currentConditions`: actualizadas desde Open-Meteo Marine API
- `isPublic`: spots de la comunidad vs privados
- `createdBy`: uid del creador

**Alerta offshore crítica:**  
Si `windDirectionStr` indica viento de tierra (S, SO, O en costa argentina) Y `windSpeedKnots > 12`, mostrar alerta bloqueante:
> ⚠️ VIENTO DE TIERRA — Condición de alto riesgo para SUP. El viento puede alejarte de la costa sin posibilidad de regreso.

### 3.3 Módulo Comunitario (Salidas Grupales)

**Flujo de una salida:**

```
Organizador crea salida → Firestore /group_trips
  ↓
Aparece en streamSalidasPublicas() → otros usuarios la ven
  ↓
Usuario se anota → attendees: FieldValue.arrayUnion([uid])
  ↓
Chat disponible para attendees (Firestore rules)
  ↓
Salida se inicia → status: 'active'
  ↓
Finalizó → status: 'completed', chat se cierra (rules)
```

**Niveles de salida:**
- 🌊 Todos los niveles
- 🟢 Principiante+ (aguas tranquilas, viento < 9 kts)
- 🟡 Intermedio+ (corrientes moderadas, viento < 15 kts)
- 🔴 Solo avanzados (cualquier condición)

### 3.4 Módulo de Seguridad y Clima

**Fuentes de datos:**

| Dato | API | Endpoint |
|------|-----|----------|
| Viento, ráfagas, lluvia, tormenta | Open-Meteo | `/v1/forecast?hourly=windspeed_10m,windgusts_10m,precipitation_probability,thunderstorm_probability` |
| Olas, temperatura agua | Open-Meteo Marine | `/v1/marine?hourly=wave_height,sea_surface_temperature` |
| Amanecer/anochecer | Open-Meteo | `&daily=sunrise,sunset` |

**SOS automático:**
- Timer de 15 minutos sin movimiento → alerta en pantalla
- Timer se pausa cuando app va a background (evita falso positivo al usar cámara)
- Opción: "Estoy bien" (reinicia timer) o "Enviar SOS" (Share con ubicación GPS)

**Previsión 48h — tabla horaria:**
- Viento en nudos (min/máx ráfagas)
- Altura de olas en metros
- Probabilidad de lluvia %
- Detección de tormenta eléctrica con rango horario
- Amanecer/anochecer marcados en la tabla

---

## 4. Diseño UX/UI para Entornos Hostiles

### 4.1 Principios Anti-Water UX

| Principio | Implementación |
|-----------|---------------|
| Alto contraste | Fondo `#0B192C` (azul profundo), texto `#F1F5F9`, acento `#06B6D4` (cyan neón) |
| Botones grandes | Mínimo 64px altura, zona táctil >= 48dp |
| Tipografía legible | SpaceGrotesk (títulos), JetBrainsMono (métricas numéricas) |
| Pantalla húmeda | Sin gestos deslizantes complejos en modo tracking, solo tap |
| Sol directo | Semáforo con colores saturados + ícono + texto (triple redundancia) |

### 4.2 Paleta de Colores

```dart
// Fondos
backgroundDeep:  Color(0xFF0B192C)  // Azul profundo
surface:         Color(0xFF1E293B)  // Slate 800
surfaceElevated: Color(0xFF243447)  // Cards elevadas

// Acentos
cyanNeon:        Color(0xFF06B6D4)  // Navegación y tracks
cyanNeonDim:     Color(0xFF0E2A3A)  // Fondos de chip

// Semáforo
semaforoVerde:   Color(0xFF10B981)  // Condiciones óptimas
semaforoAmarillo:Color(0xFFF59E0B)  // Precaución
semaforoRojo:    Color(0xFFEF4444)  // Peligro / No salir
sosRed:          Color(0xFFDC2626)  // SOS

// Texto
textPrimary:     Color(0xFFF1F5F9)
textSecondary:   Color(0xFF94A3B8)
```

### 4.3 Pantalla de Tracking (modo agua)

```
┌─────────────────────────────────┐
│ 🔴 GRABANDO          [142 pts]  │  ← Header mínimo
├─────────────────────────────────┤
│                                 │
│         MAPA (70% pantalla)     │  ← Ruta cyan sobre OSM
│      con polyline de velocidad  │
│      (verde→amarillo→rojo)      │
│                                 │
│  DIST         VEL        TIEMPO │
│  3.42 km   8.3 km/h      28m   │  ← Overlay sobre mapa
├─────────────────────────────────┤
│  [MANTENER 3s PARA FINALIZAR]   │  ← Long press + progress
└─────────────────────────────────┘
```

### 4.4 Navegación Principal (5 tabs)

```
[🏠 Inicio] [📍 Spots] [🏄 Remar] [🌤 Tiempo] [👥 Salidas]
```

- `IndexedStack` → todos los tabs vivos en memoria (GPS no se interrumpe)
- Punto rojo pulsante sobre "Remar" cuando hay remada activa

---

## 5. Estrategia de Sincronización Offline (Offline-First)

### 5.1 Prioridades de Datos

| Dato | Storage | Motivo |
|------|---------|--------|
| Coordenadas GPS | SQLite (primario) + Firebase (secundario) | Nunca perder la ruta |
| Spots favoritos | SQLite (primario) | Acceso instantáneo offline |
| Clima actual | Memoria + cache 30min | API gratuita, sin offline |
| Salidas grupales | Firebase (primario) + cache local | Requiere conexión para ser útiles |
| Chat | Firebase solo | Requiere conexión |

### 5.2 Comportamiento Sin Conexión

```
Usuario inicia remada → SQLite: crear sesión
GPS punto recibido   → SQLite: guardar INMEDIATAMENTE
                     → Firebase buffer: acumular 5 puntos
                       Si hay conexión → WriteBatch.commit()
                       Si no hay conexión → buffer crece
Usuario termina      → SQLite: marcar finalizada
                     → Firebase: flush buffer pendiente
                       (retry automático cuando vuelva conexión)
```

### 5.3 Sync Post-Conectividad

```dart
// Al restaurar conexión, subia rutas pendientes
final rutasPendientes = await SupDatabase.instance
    .getRutasSinSincronizar();

for (final ruta in rutasPendientes) {
  final coords = await SupDatabase.instance.getCoordenadas(ruta.rutaId!);
  // Upload en batches a Firebase
  await _uploadRutaToFirebase(ruta, coords);
  await SupDatabase.instance.marcarRutaSincronizada(ruta.rutaId!);
}
```

### 5.4 Cache de Tiles de Mapa

Los tiles de OpenStreetMap se cachean automáticamente por `flutter_map` en el dispositivo. El usuario debe precargar el área de su spot favorito con conexión para usarlo offline.

---

## 6. Roadmap de Implementación

### Fase 1 — MVP (✅ Completado build #84)
- [x] Auth Google + modo invitado
- [x] GPS tracking con pantalla apagada (WakeLock + ForegroundService)
- [x] SQLite: rutas, coordenadas, spots
- [x] Firestore: /users, /spots, /group_trips, /messages
- [x] Clima Open-Meteo: viento, olas, previsión 48h
- [x] Salidas grupales con chat en tiempo real
- [x] Semáforo SUPReady (verde/amarillo/rojo)
- [x] Riverpod: StreamProviders para spots, salidas, chat
- [x] SOS automático con pausa en background

### Fase 2 — Comunidad (Próximo)
- [ ] Tracking grupal en tiempo real (Firebase Realtime DB)
- [ ] Compartir ruta como imagen PNG
- [ ] Feed social: ver rutas públicas de otros en el mismo spot
- [ ] Ranking de spots por actividad
- [ ] Widget de clima en notificación diaria (WorkManager)

### Fase 3 — Plataforma
- [ ] iOS build + App Store
- [ ] Play Store publicación
- [ ] Web dashboard para organizadores
- [ ] API para integraciones externas

---

*Documento generado: SUPReady PRD v2.0 — Julio 2026*
