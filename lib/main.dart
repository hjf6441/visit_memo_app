import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/visit_record.dart';
import 'models/todo_item.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/todo_list_screen.dart';
import 'screens/visit_records_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/voice_input_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  Future<void> _onVoiceInputResult(VisitRecord record) async {
    final recordId = await _db.insertVisitRecord(record);
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

  DateTime _calculateFollowUpDate(DateTime from) {
    DateTime result = from.add(const Duration(days: 3));
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