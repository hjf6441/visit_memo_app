import 'package:flutter_test/flutter_test.dart';

import 'package:visit_memo_app/services/voice_parser.dart';

void main() {
  group('VoiceParserEngine', () {
    test('解析标准拜访语句', () {
      final text = '今天下午3点拜访了金川矿业的张总，和李经理、王工一起去的。'
          '聊了IPv6网络改造方案，客户对方案比较满意，初步达成合作意向，需要下周出详细报价。';

      final result = VoiceParserEngine.parse(text);

      // 检查结果不为空
      expect(result, isNotNull);
      expect(result.rawText, text);

      // 检查置信度
      expect(result.isHighConfidence, isTrue);

      // 检查时间解析
      expect(result.visitTime, isNotNull);
      // 时间应该在今天下午3点左右
      expect(result.visitTime!.hour, 15); // 下午3点 = 15时

      // 检查参与人员
      expect(result.participants, isNotEmpty);
      expect(
          result.participants.any((p) => p.contains('李') || p.contains('王')),
          isTrue);

      // 检查联系人
      expect(result.contactPerson, isNotNull);
      expect(result.contactPerson!.contains('张'), isTrue);

      // 检查单位
      expect(result.contactCompany, isNotNull);
      expect(result.contactCompany!.contains('金川'), isTrue);

      // 检查结果
      expect(result.result, '达成意向');

      // 检查关键句
      expect(result.keyPoints, isNotEmpty);
    });

    test('解析带明确标记的语句', () {
      final text = '拜访对象：联通公司 王经理\n参与人员：小张、小李\n'
          '讨论了5G专网方案，需进一步沟通报价问题。';

      final result = VoiceParserEngine.parse(text);

      expect(result.contactCompany, '联通公司');
      expect(result.contactPerson, '王经理');
      expect(result.result, '需跟进');
      expect(result.participants, hasLength(greaterThanOrEqualTo(2)));
    });

    test('解析空文本返回低置信度', () {
      final result = VoiceParserEngine.parse('');

      expect(result.confidence, 0.0);
      expect(result.rawText, '');
    });

    test('解析简单介绍语句', () {
      final text = '今天上午去了移动公司，认识了陈总，简单介绍了我们的产品。';

      final result = VoiceParserEngine.parse(text);

      expect(result.contactCompany, contains('移动'));
      expect(result.contactPerson, contains('陈'));
      expect(result.result, '初步接触');
    });
  });
}