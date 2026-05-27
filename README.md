# SUPReady App — Flutter

> Plataforma de Navegación, Clima y Seguridad para Stand Up Paddle  
> ERS v2.0 | Flutter | Android + iOS

---

## Estructura del Proyecto

```
supready/
├── lib/
│   ├── main.dart                          # Entry point + Router + Shell
│   ├── core/
│   │   └── theme/app_theme.dart           # Paleta, tipografías, ThemeData
│   ├── data/
│   │   ├── models/models.dart             # Entidades (Usuario, Spot, Ruta, Coord)
│   │   ├── datasources/
│   │   │   ├── local/
│   │   │   │   ├── sup_database.dart      # SQLite — persistencia offline GPS
│   │   │   │   └── tracking_service.dart  # GPS background + SOS timer
│   │   │   └── remote/
│   │   │       └── auth_service.dart      # Google OAuth 2.0
│   │   └── repositories/
│   │       └── sync_service.dart          # Sync automático al reconectar
│   └── presentation/
│       ├── screens/
│       │   ├── home/home_screen.dart
│       │   ├── spots/spots_screen.dart    # Lista de spots + SpotCard
│       │   ├── tracking/tracking_screen.dart  # UI anti-agua 72pt + LongPress
│       │   ├── academy/academy_screen.dart    # Contenido offline biomecánica
│       │   └── profile/profile_screen.dart
│       └── widgets/
│           └── spot_card/spot_card.dart   # Semáforo SUP Ready Index
├── android/
│   └── AndroidManifest.xml               # Permisos GPS, SMS, background
└── pubspec.yaml                           # Dependencias completas
```

---

## Módulos Implementados (ERS §3)

| Módulo | Estado | Archivo |
|--------|--------|---------|
| M1: Ingesta Clima API | 🟡 Estructura lista | `models.dart` → `CondicionesClimaticasModel` |
| M2: SUP Ready Index | ✅ Algoritmo completo | `SpotModel.indiceViabilidad` |
| M3: Trackeo GPS Offline | ✅ Completo | `tracking_service.dart` + `sup_database.dart` |
| M4: Auth Google OAuth | ✅ Completo | `auth_service.dart` |
| M5: Academia SUP | 🟡 Estructura lista | `academy_screen.dart` |

---

## Pasos para Ejecutar

### 1. Requisitos
- Flutter SDK ≥ 3.2.0
- Android Studio / VS Code con extensión Flutter
- Java 17+

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Configurar Google Sign-In
- Crear proyecto en [Firebase Console](https://console.firebase.google.com)
- Habilitar Authentication → Google
- Descargar `google-services.json` → colocar en `android/app/`

### 4. Configurar API de Clima
Agregar en `.env` o `lib/core/constants/api_keys.dart`:
```dart
const kStormglassApiKey = 'TU_KEY_AQUI'; // stormglass.io
```

### 5. Ejecutar
```bash
flutter run
```

---

## Decisiones de Arquitectura

### Anti-Agua UX (ERS §6)
- **Long Press 3000ms** para finalizar tracking (evita toques accidentales con agua)
- **Tipografía 72pt** para métricas (distancia, velocidad) — legible a >1m de distancia
- **Offline First** — SQLite local, sin spinners, datos siempre disponibles

### SUP Ready Index (ERS RF2.1)
```
VERDE  → Viento < 8kts AND Ráfagas < 10kts AND Olas < 0.5m AND no-offshore
AMARILLO → Viento 9-14kts OR Cross-shore OR Olas 0.5-1m  
ROJO  → Viento > 15kts OR Ráfagas > 18kts OR Offshore OR Olas > 1m
```

### SOS Automático (ERS RF3.4)
- Timer en background: si no hay variación GPS en **15 minutos** → alerta + SMS

### Sincronización (ERS RF3.3)
- `connectivity_plus` detecta restauración de señal
- Upload automático de rutas pendientes vía JSON al backend
- Las rutas siempre se guardan localmente primero

---

## Próximos Pasos Sugeridos

1. **Integrar API Stormglass** en `datasources/remote/clima_api.dart`
2. **flutter_map** en `SpotsScreen` para vista de mapa interactivo
3. **video_player** en `AcademyScreen` para loops de biomecánica (RF5.2)
4. **flutter_bloc** para gestión de estado en Spots y Tracking
5. **Push Notifications** para alertas de Prefectura (RF1.3 geocercas)
6. **Subir a Play Store** (track de producción)

## Configuración Firebase (proyecto: supready)

**Datos del proyecto:**
- Nombre: SupReady
- ID: supready  
- Número: 82783760497
- Package Android: com.supready.app

**Para activar Google Sign-In:**

1. Ir a [Firebase Console](https://console.firebase.google.com/project/supready)
2. Authentication → Sign-in method → Google → Habilitar
3. Obtener SHA-1 del keystore:
```bash
keytool -list -v \
  -keystore android/app/supready-debug.jks \
  -alias supready \
  -storepass supready2024 \
  -keypass supready2024
```
4. En Firebase Console → Configuración del proyecto → Agregar huella digital SHA-1
5. Descargar `google-services.json` actualizado → reemplazar `android/app/google-services.json`
6. Subir al repo: `git add android/app/google-services.json && git commit && git push`

> El `google-services.json` actual es un placeholder. Google Sign-In funcionará
> cuando se complete el paso 4 y 5 con el SHA-1 real del keystore.
