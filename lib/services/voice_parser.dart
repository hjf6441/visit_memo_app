import '../models/visit_record.dart';

class VoiceParserEngine {
  static ParsedResult parse(String transcript) {
    if (transcript.trim().isEmpty) {
      return ParsedResult(rawText: transcript, confidence: 0.0);
    }
    final lines = transcript.split(RegExp(r'[\n\r]+')).where((l) => l.trim().isNotEmpty).toList();
    final visitTime = _extractTime(transcript);
    final participants = _extractParticipants(transcript);
    final (company, person) = _extractContact(transcript);
    final result_ = _extractResult(transcript);
    final keyPoints = _extractKeyPoints(lines);
    final summary = _genSummary(lines, keyPoints);

    double c = 0;
    if (visitTime != null) c += 0.25;
    if (participants.isNotEmpty) c += 0.15;
    if (person != null) c += 0.2;
    if (company != null) c += 0.2;
    if (result_ != '待补充') c += 0.1;
    if (keyPoints.isNotEmpty) c += 0.1;

    return ParsedResult(
      rawText: transcript, visitTime: visitTime, participants: participants,
      contactPerson: person, contactCompany: company, summary: summary,
      result: result_, keyPoints: keyPoints, confidence: c.clamp(0.0, 1.0),
    );
  }

  static DateTime? _extractTime(String text) {
    final now = DateTime.now();
    final rm = RegExp(r'(今天|明天|后天|昨日|昨天)?\s*(早上|上午|中午|下午|晚上|凌晨)?\s*(\d{1,2})\s*点\s*(?:(\d{1,2})\s*分)?').firstMatch(text);
    if (rm != null) {
      String dayInd = rm.group(1) ?? '今天';
      String period = rm.group(2) ?? '';
      int hour = int.parse(rm.group(3)!);
      int minute = rm.group(4) != null ? int.parse(rm.group(4)!) : 0;
      if (period == '下午' || period == '晚上') { if (hour < 12) hour += 12; }
      else if (period == '中午') { if (hour < 12) hour += 12; }
      DateTime td;
      if (dayInd == '明天' || dayInd == '明日') td = now.add(const Duration(days: 1));
      else if (dayInd == '后天') td = now.add(const Duration(days: 2));
      else if (dayInd == '昨天' || dayInd == '昨日') td = now.subtract(const Duration(days: 1));
      else td = now;
      return DateTime(td.year, td.month, td.day, hour, minute);
    }
    final tm = RegExp(r'(\d{1,2})\s*[：:]\s*(\d{2})').firstMatch(text);
    if (tm != null) return DateTime(now.year, now.month, now.day, int.parse(tm.group(1)!), int.parse(tm.group(2)!));
    return null;
  }

  static List<String> _extractParticipants(String text) {
    final ps = <String>{};
    const junk = {'一起','同行','前往','拜访','见面','认识','沟通','讨论','客户','同事','领导','参加','陪同','去的'};
    final m1 = RegExp(r'(和|与|同|陪同)\s*([\u4e00-\u9fa5]{2,4}(?:、)[\u4e00-\u9fa5]{2,4})').firstMatch(text);
    if (m1 != null) {
      for (final n in m1.group(2)!.split('、')) {
        final t = n.trim();
        if (t.length >= 2 && t.length <= 4 && !junk.contains(t)) ps.add(t);
      }
    }
    final m2 = RegExp(r'(参与人员|陪同人员|同行人员|人员)[：:]\s*([\u4e00-\u9fa5]{1,4}(?:[，,、 ][\u4e00-\u9fa5]{1,4})*)').firstMatch(text);
    if (m2 != null) {
      for (final n in m2.group(2)!.split(RegExp(r'[，,、 ]'))) {
        final t = n.trim();
        if (t.isNotEmpty && t.length >= 1 && !junk.contains(t)) ps.add(t);
      }
    }
    return ps.toList();
  }

  static (String? company, String? person) _extractContact(String text) {
    // 策略2（先）：拜访对象：联通公司 王经理
    for (final label in ['拜访对象', '客户', '对接人', '联系人']) {
      final li = text.indexOf(label);
      if (li < 0) continue;
      String after = text.substring(li + label.length);
      if (!after.startsWith('：') && !after.startsWith(':')) continue;
      after = after.substring(1).trimLeft();
      String? comp;
      final words = after.split(RegExp(r'\s+'));
      for (final w in words) {
        if (RegExp(r'(公司|集团|厂|局|部|中心)$').hasMatch(w)) { comp = w; break; }
      }
      String? pers;
      for (final w in words) {
        if (RegExp(r'[\u4e00-\u9fa5]{1,4}(?:总|经理|局长|院长|校长|主任|科长|工|董|长|会计|专员|主管)$').hasMatch(w)) { pers = w; break; }
      }
      if (pers != null) return (comp, pers);
    }

    // 策略1：拜访动词 + 公司名（到"的"/标点停止）
    for (final verb in ['拜访了', '拜访', '去了', '去', '到了', '到', '前往']) {
      final vi = text.indexOf(verb);
      if (vi < 0) continue;
      String after = text.substring(vi + verb.length).trimLeft();
      final buf = StringBuffer();
      for (int i = 0; i < after.length && i < 12; i++) {
        final ch = after.codeUnitAt(i);
        if (ch == 0x7684 || ch == 0x002C || ch == 0xFF0C || ch == 0x3001 || ch == 0xFF1A || ch == 0x003A) break;
        if (ch >= 0x4E00 && ch <= 0x9FFF) buf.writeCharCode(ch);
        else break;
      }
      String company = buf.toString();
      if (company.length < 2) continue;

      final rest = after.substring(company.length);
      for (final sfx in ['总', '经理', '局长', '院长', '校长', '主任', '科长', '工', '董', '长', '会计', '专员', '主管']) {
        final pi = rest.indexOf(sfx);
        if (pi < 0) continue;
        int start = pi; int count = 0;
        while (start > 0 && count < 4) {
          final ch = rest.codeUnitAt(start - 1);
          if (ch >= 0x4E00 && ch <= 0x9FFF) { start--; count++; } else break;
        }
        if (count >= 1) {
          String raw = rest.substring(start, pi + sfx.length);
          const junk = ['认识了', '拜访了', '见到了', '见到', '他', '她', '自己', '本人'];
          String clean = raw;
          for (final j in junk) { if (clean.startsWith(j)) { clean = clean.substring(j.length); break; } }
          if (clean.length >= 2 && clean.length <= 6) return (company, clean);
        }
      }
      return (company, null);
    }

    // 策略3：fallback
    for (final sfx in ['总', '经理', '局长', '院长', '校长', '主任', '科长', '工', '董', '长', '会计', '专员', '主管']) {
      final pi = text.indexOf(sfx);
      if (pi < 0) continue;
      int start = pi; int count = 0;
      while (start > 0 && count < 4) {
        final ch = text.codeUnitAt(start - 1);
        if (ch >= 0x4E00 && ch <= 0x9FFF) { start--; count++; } else break;
      }
      if (count >= 1) {
        String raw = text.substring(start, pi + sfx.length);
        const junk = ['认识了', '拜访了', '见到了', '见到', '他', '她', '自己', '本人'];
        String clean = raw;
        for (final j in junk) { if (clean.startsWith(j)) { clean = clean.substring(j.length); break; } }
        if (clean.length >= 2 && clean.length <= 6) return (null, clean);
      }
    }
    return (null, null);
  }

  static List<String> _extractKeyPoints(List<String> lines) {
    final kp = <String>[];
    const kw = ['聊了', '谈了', '沟通', '讨论', '确认', '达成', '约定', '计划', '主要', '重点', '问题', '需求', '方案', '合同', '报价', '签约'];
    for (final l in lines) {
      final t = l.trim();
      if (t.length < 4) continue;
      for (final w in kw) { if (t.contains(w)) { kp.add(t); break; } }
    }
    return kp;
  }

  static String _extractResult(String text) {
    if (text.contains('达成') || text.contains('签约') || text.contains('同意')) return '达成意向';
    if (text.contains('跟进') || text.contains('后续') || text.contains('再联系') || text.contains('再沟通') || text.contains('进一步') || text.contains('报价')) return '需跟进';
    if (text.contains('拒绝') || text.contains('未果') || text.contains('没谈成') || text.contains('没结果') || text.contains('暂无')) return '未果';
    if (text.contains('初步') || text.contains('了解') || text.contains('介绍') || text.contains('认识')) return '初步接触';
    return '待补充';
  }

  static String _genSummary(List<String> lines, List<String> kp) {
    if (kp.isNotEmpty) return kp.take(3).join('；');
    final m = lines.where((l) => l.length >= 6 && !l.startsWith('我') && !l.startsWith('然后')).toList();
    return m.isNotEmpty ? m.take(2).join('；') : (lines.isNotEmpty ? lines.first : '');
  }
}

class ParsedResult {
  final String rawText;
  final DateTime? visitTime;
  final List<String> participants;
  final String? contactPerson;
  final String? contactCompany;
  final String? summary;
  final String result;
  final List<String> keyPoints;
  final double confidence;

  ParsedResult({required this.rawText, this.visitTime, this.participants = const [], this.contactPerson, this.contactCompany, this.summary, this.result = '待补充', this.keyPoints = const [], this.confidence = 0.0});
  bool get isHighConfidence => confidence >= 0.6;
}