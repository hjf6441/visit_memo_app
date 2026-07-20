import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';

/// 导出屏幕 — 显示查看备份列表
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  List<File> _backupFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .where((f) => f.path.endsWith('.json'))
          .map((f) => File(f.path))
          .toList();
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (mounted) {
        setState(() {
          _backupFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportNewBackup() async {
    try {
      final db = DatabaseService();
      final jsonStr = await db.exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'visit_memo_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);
      _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份成功：$fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建备份',
            onPressed: _exportNewBackup,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backupFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('暂无备份',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.backup),
                        label: const Text('创建备份'),
                        onPressed: _exportNewBackup,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBackups,
                  child: ListView.builder(
                    itemCount: _backupFiles.length,
                    itemBuilder: (context, index) {
                      final file = _backupFiles[index];
                      final stat = file.statSync();
                      final sizeKB = (stat.size / 1024).toStringAsFixed(1);
                      final modified = stat.modified;

                      return ListTile(
                        leading: const Icon(Icons.description, color: Colors.blue),
                        title: Text(file.uri.pathSegments.last),
                        subtitle: Text(
                            '${modified.year}/${modified.month.toString().padLeft(2, '0')}/${modified.day.toString().padLeft(2, '0')} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}  ·  ${sizeKB}KB'),
                        trailing: IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () {
                            // 分享/导出文件（需要 share_plus 插件）
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('文件可在设备文件管理器中找到')),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}