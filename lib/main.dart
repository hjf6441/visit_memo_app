import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/visit_record.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/todo_list_screen.dart';
import 'screens/visit_records_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/voice_input_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const VisitMemoApp());
}

class VisitMemoApp extends StatelessWidget {
  const VisitMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拜访助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

/// 主界面 — 底部导航栏
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final DatabaseService _db = DatabaseService();

  final List<Widget> _screens = const [
    TodoListScreen(),
    VisitRecordsScreen(),
    SettingsScreen(),
  ];

  /// 语音录入 -> 保存记录 -> 自动生成跟进待办
  Future<void> _onVoiceInputResult(VisitRecord record) async {
    // 1. 保存拜访记录
    final recordId = await _db.insertVisitRecord(record);

    // 2. 自动生成跟进待办（截止时间 = 拜访后3个工作日）
    final followUpDate = _calculateFollowUpDate(record.visitTime);
    final title = record.contactPerson != null
        ? '跟进${record.contactPerson}'
        : '跟进${record.contactDisplay}';
    final desc = record.summary != null
        ? '拜访记录摘要：${record.summary}'
        : '来自语音录入的拜访记录';

    await _db.insertTodo(
      TodoItem(
        title: title,
        description: desc,
        dueDate: followUpDate,
        visitRecordId: recordId,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已保存记录，自动创建待办：$title'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '查看',
            onPressed: () {
              setState(() => _currentIndex = 0);
            },
          ),
        ),
      );
    }
  }

  /// 计算3个工作日后的日期
  DateTime _calculateFollowUpDate(DateTime from) {
    DateTime result = from.add(const Duration(days: 3));
    // 如果落在周末，顺延到周一
    while (result.weekday == DateTime.saturday ||
        result.weekday == DateTime.sunday) {
      result = result.add(const Duration(days: 1));
    }
    return DateTime(result.year, result.month, result.day, 18, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '待办',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      // 语音录入悬浮按钮 — 在待办页和记录页显示
      floatingActionButton: _currentIndex <= 1
          ? FloatingActionButton(
              onPressed: () {
                VoiceInputSheet.show(context, _onVoiceInputResult);
              },
              tooltip: '语音录入',
              child: const Icon(Icons.mic),
            )
          : null,
    );
  }
}

/// 本地 TodoItem 声明（防止数据库服务中的导入冲突）
class TodoItem {
  final int? id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? visitRecordId;

  TodoItem({
    this.id,
    required this.title,
    this.description,
    DateTime? createdAt,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.visitRecordId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'visit_record_id': visitRecordId,
    };
  }
}