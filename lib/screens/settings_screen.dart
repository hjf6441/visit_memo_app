import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

/// 设置页面 — 数据导出/备份等
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _morningReminder = true;
  bool _eveningReminder = true;
  bool _isExporting = false;
  String? _exportResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morningReminder = prefs.getBool('morning_reminder') ?? true;
      _eveningReminder = prefs.getBool('evening_reminder') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_reminder', _morningReminder);
    await prefs.setBool('evening_reminder', _eveningReminder);
  }

  /// 导出数据到 JSON 文件
  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
      _exportResult = null;
    });

    try {
      final db = DatabaseService();
      final jsonStr = await db.exportToJson();

      // 获取导出目录
      final dir = await _getExportDirectory();
      final fileName =
          'visit_memo_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);

      setState(() {
        _isExporting = false;
        _exportResult = '导出成功：$fileName\n路径：${dir.path}';
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportResult = '导出失败：$e';
      });
    }
  }

  Future<Directory> _getExportDirectory() async {
    try {
      // 尝试获取文档目录
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      // 备用
      return Directory('/storage/emulated/0/Download');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 提醒设置
          const _SectionTitle(title: '通知提醒'),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('早上提醒 (08:00)'),
                  subtitle: const Text('提醒未完成的待办事项'),
                  value: _morningReminder,
                  onChanged: (v) {
                    setState(() => _morningReminder = v);
                    _saveSettings();
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('晚上提醒 (20:00)'),
                  subtitle: const Text('提醒未完成的待办事项'),
                  value: _eveningReminder,
                  onChanged: (v) {
                    setState(() => _eveningReminder = v);
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 数据管理
          const _SectionTitle(title: '数据管理'),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('导出备份'),
                  subtitle: const Text('将所有数据导出为JSON文件'),
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onPressed: _isExporting ? null : _exportData,
                ),
                if (_exportResult != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _exportResult!.startsWith('导出成功')
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _exportResult!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _exportResult!.startsWith('导出成功')
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 关于
          const _SectionTitle(title: '关于'),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('应用版本'),
                  trailing: Text('v1.0.0'),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('数据存储'),
                  subtitle: Text('本地存储，无需网络'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}