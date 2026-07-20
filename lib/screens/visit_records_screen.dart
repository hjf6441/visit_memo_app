import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/visit_record.dart';
import '../services/database_service.dart';

/// 拜访记录列表页面 — 时间线归档+搜索筛选
class VisitRecordsScreen extends StatefulWidget {
  const VisitRecordsScreen({super.key});

  @override
  State<VisitRecordsScreen> createState() => _VisitRecordsScreenState();
}

class _VisitRecordsScreenState extends State<VisitRecordsScreen> {
  final DatabaseService _db = DatabaseService();
  List<VisitRecord> _records = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _resultFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final List<String> _resultOptions = [
    '全部',
    '达成意向',
    '需跟进',
    '初步接触',
    '未果',
    '待补充'
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _db.getVisitRecords(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        contactFilter: null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      // 前端过滤结果
      var filtered = records;
      if (_resultFilter != null && _resultFilter != '全部') {
        filtered =
            records.where((r) => r.result == _resultFilter).toList();
      }

      if (mounted) {
        setState(() {
          _records = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDateFilterDialog() {
    DateTime? from = _dateFrom;
    DateTime? to = _dateTo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('筛选日期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('从：'),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: from ?? DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setDialogState(() => from = d);
                    },
                    child: Text(from != null
                        ? DateFormat('yyyy/MM/dd').format(from!)
                        : '选择日期'),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('到：'),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: to ?? DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setDialogState(() => to = d);
                    },
                    child: Text(to != null
                        ? DateFormat('yyyy/MM/dd').format(to!)
                        : '选择日期'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _dateFrom = null;
                  _dateTo = null;
                });
                Navigator.pop(ctx);
                _loadRecords();
              },
              child: const Text('清除'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _dateFrom = from;
                  _dateTo = to;
                });
                Navigator.pop(ctx);
                _loadRecords();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拜访记录'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _dateFrom != null ? Colors.blue : null,
            ),
            tooltip: '日期筛选',
            onPressed: _showDateFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索单位、人员、内容...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadRecords();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onSubmitted: (v) {
                setState(() => _searchQuery = v.trim());
                _loadRecords();
              },
            ),
          ),

          // 结果筛选标签
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _resultOptions.map((opt) {
                final isSelected = (opt == '全部' && _resultFilter == null) ||
                    _resultFilter == opt;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _resultFilter = selected && opt != '全部' ? opt : null;
                      });
                      _loadRecords();
                    },
                    selectedColor: Colors.blue[100],
                  ),
                );
              }).toList(),
            ),
          ),

          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRecords,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            return _buildRecordCard(_records[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无拜访记录',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '通过语音录入添加第一条记录',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(VisitRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: _buildResultBadge(record.result),
        title: Text(
          record.contactDisplay,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy/MM/dd HH:mm').format(record.visitTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (record.summary != null && record.summary!.isNotEmpty)
              Text(
                record.summary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.participants.isNotEmpty)
                  _buildInfoRow(Icons.people, '参与人员',
                      record.participantsDisplay),
                if (record.summary != null && record.summary!.isNotEmpty)
                  _buildInfoRow(
                      Icons.chat_bubble_outline, '摘要', record.summary!),
                if (record.fullTranscript != null &&
                    record.fullTranscript!.isNotEmpty)
                  _buildInfoRow(Icons.article_outlined, '原文',
                      record.fullTranscript!),
                if (record.keyPoints != null && record.keyPoints!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: record.keyPoints!
                          .map((kp) => Chip(
                                label: Text(kp,
                                    style: const TextStyle(fontSize: 12)),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBadge(String result) {
    Color color;
    switch (result) {
      case '达成意向':
        color = Colors.green;
        break;
      case '需跟进':
        color = Colors.orange;
        break;
      case '初步接触':
        color = Colors.blue;
        break;
      case '未果':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          result.length > 2 ? result.substring(0, 2) : result,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}