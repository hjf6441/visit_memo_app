import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../services/database_service.dart';

/// 主页 — 每日待办清单页面
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final DatabaseService _db = DatabaseService();
  List<TodoItem> _todos = [];
  bool _showCompleted = false;
  bool _isLoading = true;
  StreamSubscription? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);
    try {
      final todos = await _db.getTodos(
        isCompleted: _showCompleted ? null : false,
      );
      if (mounted) {
        setState(() {
          _todos = todos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refresh() => _loadTodos();

  /// 显示添加待办对话框
  void _showAddTodoDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加待办'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '待办事项',
                    hintText: '请输入待办内容',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('截止日期：'),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        dueDate != null
                            ? DateFormat('MM/dd HH:mm').format(dueDate!)
                            : '设置',
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate:
                              dueDate ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 18, minute: 0),
                          );
                          if (time != null) {
                            setDialogState(() {
                              dueDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    if (dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setDialogState(() => dueDate = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                await _db.insertTodo(TodoItem(
                  title: title,
                  description: descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : null,
                  dueDate: dueDate,
                ));
                Navigator.of(ctx).pop();
                _loadTodos();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示编辑待办对话框
  void _showEditTodoDialog(TodoItem item) {
    final titleController = TextEditingController(text: item.title);
    final descController = TextEditingController(text: item.description ?? '');
    DateTime? dueDate = item.dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑待办'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '待办事项',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('截止日期：'),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        dueDate != null
                            ? DateFormat('MM/dd HH:mm').format(dueDate!)
                            : '设置',
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate:
                              dueDate ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 18, minute: 0),
                          );
                          if (time != null) {
                            setDialogState(() {
                              dueDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    if (dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setDialogState(() => dueDate = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                await _db.updateTodo(item.copyWith(
                  title: title,
                  description: descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : null,
                  dueDate: dueDate,
                ));
                Navigator.of(ctx).pop();
                _loadTodos();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        centerTitle: true,
        actions: [
          // 切换显示已完成
          IconButton(
            icon: Icon(
              _showCompleted ? Icons.filter_list_off : Icons.filter_list,
            ),
            tooltip: _showCompleted ? '隐藏已完成' : '显示全部',
            onPressed: () {
              setState(() => _showCompleted = !_showCompleted);
              _loadTodos();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTodos,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return _buildTodoCard(todo, theme);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTodoDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加待办'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showCompleted ? Icons.check_circle_outline : Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _showCompleted ? '暂无已完成的待办' : '今天还没有待办事项',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _showCompleted ? '' : '点击下方按钮添加',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(TodoItem item, ThemeData theme) {
    final isOverdue = item.dueDate != null &&
        item.dueDate!.isBefore(DateTime.now()) &&
        !item.isCompleted;
    final isDueToday = item.dueDate != null &&
        !item.isCompleted &&
        DateUtils.isSameDay(item.dueDate!, DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: item.isCompleted ? 0.5 : 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditTodoDialog(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              // 勾选按钮
              Checkbox(
                value: item.isCompleted,
                onChanged: (_) async {
                  await _db.toggleTodoComplete(item.id!);
                  _loadTodos();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (item.dueDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: isOverdue
                                  ? Colors.red
                                  : isDueToday
                                      ? Colors.orange
                                      : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MM/dd HH:mm').format(item.dueDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue
                                    ? Colors.red
                                    : isDueToday
                                        ? Colors.orange
                                        : Colors.grey[500],
                                fontWeight: isOverdue || isDueToday
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            if (isOverdue)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '已过期',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.red[700]),
                                  ),
                                ),
                              ),
                            if (isDueToday)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '今天截止',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[700]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: Colors.grey[400]),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text('确定删除"${item.title}"？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('删除',
                              style: TextStyle(color: Colors.red[600])),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _db.deleteTodo(item.id!);
                    _loadTodos();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}