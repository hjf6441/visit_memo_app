import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo_item.dart';
import '../models/visit_record.dart';

/// 本地SQLite数据库服务
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'visit_memo.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE todo_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        due_date TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        visit_record_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE visit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visit_time TEXT NOT NULL,
        participants TEXT,
        contact_person TEXT,
        contact_company TEXT,
        summary TEXT,
        full_transcript TEXT,
        result TEXT NOT NULL DEFAULT '待补充',
        created_at TEXT NOT NULL,
        key_points TEXT
      )
    ''');

    // 索引
    await db.execute(
        'CREATE INDEX idx_todo_is_completed ON todo_items(is_completed)');
    await db.execute(
        'CREATE INDEX idx_todo_due_date ON todo_items(due_date)');
    await db.execute(
        'CREATE INDEX idx_visit_visit_time ON visit_records(visit_time)');
    await db.execute(
        'CREATE INDEX idx_visit_contact ON visit_records(contact_person, contact_company)');
  }

  // ==================== 待办事项 CRUD ====================

  Future<int> insertTodo(TodoItem item) async {
    final db = await database;
    return await db.insert('todo_items', item.toMap());
  }

  Future<List<TodoItem>> getTodos({bool? isCompleted}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (isCompleted != null) {
      where = 'is_completed = ?';
      whereArgs = [isCompleted ? 1 : 0];
    }

    final maps = await db.query(
      'todo_items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'due_date ASC, created_at DESC',
    );
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<List<TodoItem>> getTodayIncompleteTodos() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final maps = await db.query(
      'todo_items',
      where:
          'is_completed = 0 AND (due_date IS NULL OR (due_date >= ? AND due_date < ?))',
      whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
      orderBy: 'due_date ASC, created_at DESC',
    );

    if (maps.isEmpty) {
      // 如果没有今天截止的，取所有未完成的
      final allMaps = await db.query(
        'todo_items',
        where: 'is_completed = 0',
        orderBy: 'due_date ASC, created_at DESC',
      );
      return allMaps.map((m) => TodoItem.fromMap(m)).toList();
    }
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<int> getIncompleteCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM todo_items WHERE is_completed = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> updateTodo(TodoItem item) async {
    final db = await database;
    return await db.update(
      'todo_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> toggleTodoComplete(int id) async {
    final db = await database;
    final todos = await db.query(
      'todo_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (todos.isEmpty) return 0;

    final current = TodoItem.fromMap(todos.first);
    final updated = current.copyWith(
      isCompleted: !current.isCompleted,
      completedAt: !current.isCompleted ? DateTime.now() : null,
    );
    return await db.update(
      'todo_items',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete('todo_items', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 拜访记录 CRUD ====================

  Future<int> insertVisitRecord(VisitRecord record) async {
    final db = await database;
    return await db.insert('visit_records', record.toMap());
  }

  Future<List<VisitRecord>> getVisitRecords({
    String? searchQuery,
    String? contactFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add(
          '(contact_person LIKE ? OR contact_company LIKE ? OR summary LIKE ? OR full_transcript LIKE ?)');
      final q = '%$searchQuery%';
      args.addAll([q, q, q, q]);
    }
    if (contactFilter != null && contactFilter.isNotEmpty) {
      conditions.add(
          '(contact_person LIKE ? OR contact_company LIKE ?)');
      final q = '%$contactFilter%';
      args.addAll([q, q]);
    }
    if (dateFrom != null) {
      conditions.add('visit_time >= ?');
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      conditions.add('visit_time <= ?');
      args.add(dateTo.toIso8601String());
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final maps = await db.query(
      'visit_records',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'visit_time DESC',
    );
    return maps.map((m) => VisitRecord.fromMap(m)).toList();
  }

  Future<List<VisitRecord>> getAllVisitRecords() async {
    final db = await database;
    final maps = await db.query(
      'visit_records',
      orderBy: 'visit_time DESC',
    );
    return maps.map((m) => VisitRecord.fromMap(m)).toList();
  }

  Future<int> deleteVisitRecord(int id) async {
    final db = await database;
    return await db.delete('visit_records', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 数据导出 ====================

  Future<String> exportToJson() async {
    final db = await database;
    final todos = await db.query('todo_items');
    final visits = await db.query('visit_records');

    final export = {
      'export_time': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'todo_items': todos,
      'visit_records': visits,
    };

    // 使用 dart:convert 序列化
    final jsonStr = _mapToJson(export);
    return jsonStr;
  }

  String _mapToJson(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    buffer.write('{');
    bool first = true;
    map.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$key":');
      buffer.write(_valueToJson(value));
    });
    buffer.write('}');
    return buffer.toString();
  }

  String _valueToJson(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
    if (value is num || value is bool) return value.toString();
    if (value is DateTime) return '"${value.toIso8601String()}"';
    if (value is List) {
      final items = value.map((e) => _valueToJson(e)).join(',');
      return '[$items]';
    }
    if (value is Map) {
      return _mapToJson(value.cast<String, dynamic>());
    }
    return '"$value"';
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}