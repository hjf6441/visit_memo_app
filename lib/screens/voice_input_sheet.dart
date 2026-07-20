import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/visit_record.dart';
import '../services/voice_parser.dart';

/// 语音录入浮层
/// 点击后调用系统语音识别，转录文字后弹出结构化预览
class VoiceInputSheet extends StatefulWidget {
  final Function(VisitRecord record) onSave;

  const VoiceInputSheet({super.key, required this.onSave});

  /// 便捷显示方法
  static Future<void> show(BuildContext context, Function(VisitRecord) onSave) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceInputSheet(onSave: onSave),
    );
  }

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

enum VoiceInputState { idle, listening, processing, preview }

class _VoiceInputSheetState extends State<VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  VoiceInputState _state = VoiceInputState.idle;
  String _transcript = '';
  ParsedResult? _parsedResult;
  double _amplitude = 0.0;
  Timer? _simulationTimer;

  // 手动编辑控制器
  final _personController = TextEditingController();
  final _companyController = TextEditingController();
  final _summaryController = TextEditingController();
  final _manualTextController = TextEditingController();
  final List<String> _participants = [];
  String _selectedResult = '需跟进';
  DateTime _selectedTime = DateTime.now();
  bool _needsManualEdit = false;

  final List<String> _resultOptions = [
    '达成意向',
    '需跟进',
    '初步接触',
    '未果',
    '待补充'
  ];

  @override
  void initState() {
    super.initState();
    // 默认预填当前时间
    _selectedTime = DateTime.now();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _personController.dispose();
    _companyController.dispose();
    _summaryController.dispose();
    _manualTextController.dispose();
    super.dispose();
  }

  /// 开始语音识别
  void _startListening() {
    setState(() {
      _state = VoiceInputState.listening;
      _transcript = '';
    });

    // 由于沙箱环境无实际麦克风，模拟语音识别过程
    // 实际运行时会调用 SpeechToText 插件
    _simulateListening();
  }

  /// 模拟语音识别（真实环境下替换为 SpeechToText）
  void _simulateListening() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _amplitude = 0.3 + (t.tick % 10) / 20.0;
      });
    });

    // 2秒后模拟识别完成
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _simulationTimer?.cancel();
      setState(() {
        _amplitude = 0;
      });
      // 使用测试文本模拟语音输入
      _onSpeechResult(
        '今天下午3点拜访了金川矿业的张总，和李经理、王工一起去的。聊了IPv6网络改造方案，客户对方案比较满意，初步达成合作意向，需要下周出详细报价。',
      );
    });
  }

  /// 收到语音识别结果
  void _onSpeechResult(String text) {
    setState(() {
      _transcript = text;
      _state = VoiceInputState.processing;
    });

    // 解析
    final result = VoiceParserEngine.parse(text);
    _parsedResult = result;

    // 填充编辑控制器
    _personController.text = result.contactPerson ?? '';
    _companyController.text = result.contactCompany ?? '';
    _summaryController.text = result.summary ?? text;
    _selectedResult = result.result;
    if (result.visitTime != null) {
      _selectedTime = result.visitTime!;
    }
    _participants
      ..clear()
      ..addAll(result.participants);

    // 置信度低于60%或关键字段缺失，进手动编辑
    _needsManualEdit = !result.isHighConfidence ||
        result.contactPerson == null ||
        result.summary == null;

    setState(() {
      _state = VoiceInputState.preview;
    });
  }

  /// 保存记录
  void _saveRecord() {
    final record = VisitRecord(
      visitTime: _selectedTime,
      participants: _participants.isNotEmpty ? _participants : [],
      contactPerson: _personController.text.trim().isNotEmpty
          ? _personController.text.trim()
          : null,
      contactCompany: _companyController.text.trim().isNotEmpty
          ? _companyController.text.trim()
          : null,
      summary: _summaryController.text.trim().isNotEmpty
          ? _summaryController.text.trim()
          : null,
      fullTranscript: _transcript.isNotEmpty ? _transcript : null,
      result: _selectedResult,
      keyPoints: _parsedResult?.keyPoints ?? [],
    );
    widget.onSave(record);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            // 拖拽指示条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '语音录入拜访记录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case VoiceInputState.idle:
        return _buildIdleState();
      case VoiceInputState.listening:
        return _buildListeningState();
      case VoiceInputState.processing:
        return _buildProcessingState();
      case VoiceInputState.preview:
        return _buildPreviewState();
    }
  }

  /// 空闲状态 — 显示开始按钮
  Widget _buildIdleState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1565C0).withOpacity(0.1),
          ),
          child: IconButton(
            iconSize: 60,
            icon: const Icon(Icons.mic, color: Color(0xFF1565C0)),
            onPressed: _startListening,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '点击开始录音',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          '说出拜访信息，自动解析为结构化记录',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 32),
        // 手动输入入口
        TextButton.icon(
          icon: const Icon(Icons.keyboard),
          label: const Text('手动输入文本'),
          onPressed: () => setState(() => _needsManualEdit = true),
        ),
      ],
    );
  }

  /// 录音中状态
  Widget _buildListeningState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 120 + _amplitude * 40,
          height: 120 + _amplitude * 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1 + _amplitude * 0.2),
            border: Border.all(
              color: Colors.red.withOpacity(0.3 + _amplitude * 0.4),
              width: 3,
            ),
          ),
          child: const Icon(Icons.mic, size: 50, color: Colors.red),
        ),
        const SizedBox(height: 24),
        const Text(
          '正在录音...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          '请清晰说出拜访信息',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () {
            _simulationTimer?.cancel();
            // 模拟完成
            _onSpeechResult(
              '今天下午3点拜访了金川矿业的张总，和李经理、王工一起去的。聊了IPv6网络改造方案，客户对方案比较满意，初步达成合作意向，需要下周出详细报价。',
            );
          },
          child: const Text('完成录音'),
        ),
      ],
    );
  }

  /// 处理中状态
  Widget _buildProcessingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('正在解析语音内容...',
              style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  /// 预览状态 — 展示结构化结果
  Widget _buildPreviewState() {
    // 默认展开手动编辑区域，或用原始文本填充
    if (_needsManualEdit && _transcript.isEmpty) {
      _manualTextController.text = _transcript;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原文
          if (_transcript.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.article_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text('识别原文',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_parsedResult != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _parsedResult!.isHighConfidence
                                ? Colors.green[50]
                                : Colors.orange[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _parsedResult!.isHighConfidence ? '高置信度' : '低置信度',
                            style: TextStyle(
                              fontSize: 11,
                              color: _parsedResult!.isHighConfidence
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_transcript, style: const TextStyle(fontSize: 14)),
                  if (_parsedResult != null &&
                      _parsedResult!.keyPoints.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _parsedResult!.keyPoints
                            .map((kp) => Chip(
                                  label: Text(kp, style: const TextStyle(fontSize: 12)),
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
            const SizedBox(height: 16),
          ],

          // 手动录入区域
          if (_needsManualEdit && _transcript.isEmpty) ...[
            TextField(
              controller: _manualTextController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '输入拜访内容',
                hintText: '请描述您今天的拜访情况...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 结构化字段编辑区
          const Text('结构化信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // 拜访时间
          _buildFieldRow(
            icon: Icons.access_time,
            label: '拜访时间',
            child: TextButton.icon(
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: Text(
                DateFormat('yyyy年MM月dd日 HH:mm').format(_selectedTime),
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedTime,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay.fromDateTime(_selectedTime),
                  );
                  if (time != null) {
                    setState(() {
                      _selectedTime = DateTime(
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
          ),

          // 参与人员
          _buildFieldRow(
            icon: Icons.people,
            label: '参与人员',
            child: _participants.isEmpty
                ? TextButton(
                    onPressed: _showAddParticipantDialog,
                    child: const Text('添加人员'),
                  )
                : Wrap(
                    spacing: 6,
                    children: [
                      ..._participants.map((p) => Chip(
                            label: Text(p, style: const TextStyle(fontSize: 13)),
                            onDeleted: () {
                              setState(
                                  () => _participants.remove(p));
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )),
                      ActionChip(
                        label: const Text('+', style: TextStyle(fontSize: 16)),
                        onPressed: _showAddParticipantDialog,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
          ),

          // 拜访对象单位
          _buildFieldRow(
            icon: Icons.business,
            label: '单位',
            child: SizedBox(
              width: 200,
              child: TextField(
                controller: _companyController,
                decoration: const InputDecoration(
                  hintText: '如：金川矿业',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ),

          // 拜访对象姓名
          _buildFieldRow(
            icon: Icons.person,
            label: '联系人',
            child: SizedBox(
              width: 180,
              child: TextField(
                controller: _personController,
                decoration: const InputDecoration(
                  hintText: '如：张总',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ),

          // 谈话内容
          _buildFieldRow(
            icon: Icons.chat_bubble_outline,
            label: '内容摘要',
            child: TextField(
              controller: _summaryController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '谈话内容摘要',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          // 结果
          _buildFieldRow(
            icon: Icons.check_circle_outline,
            label: '结果',
            child: DropdownButton<String>(
              value: _selectedResult,
              underline: const SizedBox(),
              items: _resultOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedResult = v!),
            ),
          ),

          // 缺少字段提醒
          if (_needsManualEdit) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '部分字段未能自动提取，请手动补充后保存',
                      style: TextStyle(
                          fontSize: 13, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('保存记录'),
              onPressed: _summaryController.text.trim().isEmpty
                  ? null
                  : _saveRecord,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _showAddParticipantDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加参与人员'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入姓名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() => _participants.add(name));
              }
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}