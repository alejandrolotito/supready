import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supready/data/models/models.dart';

// ============================================================
// SUPReady - Base de Datos Local SQLite
// ERS §5 - Persistencia offline para GPS en agua (RF3.2)
// ============================================================

class SupDatabase {
  static final SupDatabase instance = SupDatabase._init();
  static Database? _database;

  SupDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('supready.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla USUARIOS
    await db.execute('''
      CREATE TABLE usuarios (
        usuario_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre        TEXT NOT NULL,
        apellido      TEXT NOT NULL,
        email         TEXT NOT NULL UNIQUE,
        google_id     TEXT UNIQUE,
        avatar_url    TEXT,
        nivel_experiencia TEXT NOT NULL CHECK(nivel_experiencia IN ('principiante','intermedio','avanzado'))
      )
    ''');

    // Tabla SPOTS
    await db.execute('''
      CREATE TABLE spots (
        spot_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre        TEXT NOT NULL,
        latitud       REAL NOT NULL,
        longitud      REAL NOT NULL,
        descripcion   TEXT DEFAULT '',
        viento_kts    REAL,
        rafagas_kts   REAL,
        olas_metros   REAL,
        dir_viento    REAL,
        es_offshore   INTEGER DEFAULT 0,
        es_crossshore INTEGER DEFAULT 0,
        actualizado_en TEXT
      )
    ''');

    // Tabla RUTAS_TRAZADAS
    await db.execute('''
      CREATE TABLE rutas_trazadas (
        ruta_id           INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id        INTEGER NOT NULL,
        spot_id           INTEGER NOT NULL,
        nombre_publico    TEXT,
        es_publica        INTEGER DEFAULT 0,
        distancia_total_km REAL NOT NULL DEFAULT 0.0,
        duracion_minutos  INTEGER NOT NULL DEFAULT 0,
        velocidad_media   REAL NOT NULL DEFAULT 0.0,
        velocidad_maxima  REAL DEFAULT 0.0,
        iniciada_en       TEXT NOT NULL,
        finalizada_en     TEXT,
        sincronizado      INTEGER DEFAULT 0,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
        FOREIGN KEY (spot_id)    REFERENCES spots(spot_id)
      )
    ''');

    // Tabla COORDENADAS_RUTA
    await db.execute('''
      CREATE TABLE coordenadas_ruta (
        coordenada_id INTEGER PRIMARY KEY AUTOINCREMENT,
        ruta_id       INTEGER NOT NULL,
        latitud       REAL NOT NULL,
        longitud      REAL NOT NULL,
        secuencia     INTEGER NOT NULL,
        timestamp     TEXT NOT NULL,
        FOREIGN KEY (ruta_id) REFERENCES rutas_trazadas(ruta_id)
      )
    ''');

    // Índice para acceso rápido de coordenadas por ruta
    await db.execute('''
      CREATE INDEX idx_coordenadas_ruta ON coordenadas_ruta(ruta_id, secuencia)
    ''');
  }

  // --- CRUD USUARIOS ---

  Future<int> upsertUsuario(UsuarioModel usuario) async {
    final db = await database;
    return await db.insert(
      'usuarios',
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UsuarioModel?> getUsuarioByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UsuarioModel.fromMap(maps.first);
  }

  // --- CRUD RUTAS ---

  Future<int> insertarRuta(RutaTrazadaModel ruta) async {
    final db = await database;
    return await db.insert('rutas_trazadas', ruta.toMap());
  }

  Future<void> actualizarRuta(RutaTrazadaModel ruta) async {
    final db = await database;
    await db.update(
      'rutas_trazadas',
      ruta.toMap(),
      where: 'ruta_id = ?',
      whereArgs: [ruta.rutaId],
    );
  }

  Future<List<RutaTrazadaModel>> getRutasPorUsuario(int usuarioId) async {
    final db = await database;
    final maps = await db.query(
      'rutas_trazadas',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'iniciada_en DESC',
    );
    return maps.map(RutaTrazadaModel.fromMap).toList();
  }

  Future<List<RutaTrazadaModel>> getRutasSinSincronizar() async {
    final db = await database;
    final maps = await db.query(
      'rutas_trazadas',
      where: 'sincronizado = 0 AND finalizada_en IS NOT NULL',
    );
    return maps.map(RutaTrazadaModel.fromMap).toList();
  }

  Future<void> marcarRutaSincronizada(int rutaId) async {
    final db = await database;
    await db.update(
      'rutas_trazadas',
      {'sincronizado': 1},
      where: 'ruta_id = ?',
      whereArgs: [rutaId],
    );
  }

  // --- CRUD COORDENADAS ---

  Future<void> insertarCoordenada(CoordenadasRutaModel coord) async {
    final db = await database;
    await db.insert('coordenadas_ruta', coord.toMap());
  }

  Future<void> insertarCoordenadas(List<CoordenadasRutaModel> coords) async {
    final db = await database;
    final batch = db.batch();
    for (final c in coords) {
      batch.insert('coordenadas_ruta', c.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<CoordenadasRutaModel>> getCoordenadas(int rutaId) async {
    final db = await database;
    final maps = await db.query(
      'coordenadas_ruta',
      where: 'ruta_id = ?',
      whereArgs: [rutaId],
      orderBy: 'secuencia ASC',
    );
    return maps.map(CoordenadasRutaModel.fromMap).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
