import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/health_data.dart';
import '../models/ppg_data.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ppg_health.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to ppg_data table
      await db.execute('ALTER TABLE ppg_data ADD COLUMN bpm_readings TEXT DEFAULT ""');
      await db.execute('ALTER TABLE ppg_data ADD COLUMN timestamps TEXT DEFAULT ""');
      await db.execute('ALTER TABLE ppg_data ADD COLUMN hrv REAL');
      await db.execute('ALTER TABLE ppg_data ADD COLUMN min_bpm INTEGER');
      await db.execute('ALTER TABLE ppg_data ADD COLUMN max_bpm INTEGER');
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // Create health_data table
    await db.execute('''
      CREATE TABLE health_data(
        id TEXT PRIMARY KEY,
        age INTEGER NOT NULL,
        bmi REAL NOT NULL,
        timestamp TEXT NOT NULL,
        additional_data TEXT
      )
    ''');

    // Create ppg_data table
    await db.execute('''
      CREATE TABLE ppg_data(
        id TEXT PRIMARY KEY,
        health_data_id TEXT NOT NULL,
        raw_values TEXT NOT NULL,
        bpm_readings TEXT DEFAULT "",
        timestamps TEXT DEFAULT "",
        heart_rate INTEGER NOT NULL,
        duration REAL NOT NULL,
        timestamp TEXT NOT NULL,
        spo2 REAL,
        hrv REAL,
        min_bpm INTEGER,
        max_bpm INTEGER,
        FOREIGN KEY (health_data_id) REFERENCES health_data (id)
      )
    ''');
  }

  // Health Data operations
  Future<String> insertHealthData(HealthData healthData) async {
    final db = await database;
    await db.insert('health_data', healthData.toMap());
    return healthData.id;
  }

  Future<List<HealthData>> getAllHealthData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('health_data');
    
    return List.generate(maps.length, (i) {
      return HealthData.fromMap(maps[i]);
    });
  }

  Future<HealthData?> getHealthData(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'health_data',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return HealthData.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateHealthData(HealthData healthData) async {
    final db = await database;
    await db.update(
      'health_data',
      healthData.toMap(),
      where: 'id = ?',
      whereArgs: [healthData.id],
    );
  }

  Future<void> deleteHealthData(String id) async {
    final db = await database;
    await db.delete(
      'health_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // PPG Data operations
  Future<String> insertPPGData(PPGData ppgData) async {
    final db = await database;
    await db.insert('ppg_data', ppgData.toMap());
    return ppgData.id;
  }

  Future<List<PPGData>> getAllPPGData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('ppg_data');
    
    return List.generate(maps.length, (i) {
      return PPGData.fromMap(maps[i]);
    });
  }

  Future<List<PPGData>> getPPGDataByHealthId(String healthDataId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ppg_data',
      where: 'health_data_id = ?',
      whereArgs: [healthDataId],
    );
    
    return List.generate(maps.length, (i) {
      return PPGData.fromMap(maps[i]);
    });
  }

  Future<PPGData?> getPPGData(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ppg_data',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return PPGData.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updatePPGData(PPGData ppgData) async {
    final db = await database;
    await db.update(
      'ppg_data',
      ppgData.toMap(),
      where: 'id = ?',
      whereArgs: [ppgData.id],
    );
  }

  Future<void> deletePPGData(String id) async {
    final db = await database;
    await db.delete(
      'ppg_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Combined operations
  Future<Map<String, dynamic>> getCompleteUserData() async {
    final healthDataList = await getAllHealthData();
    final ppgDataList = await getAllPPGData();
    
    return {
      'health_data': healthDataList,
      'ppg_data': ppgDataList,
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('ppg_data');
    await db.delete('health_data');
  }
}