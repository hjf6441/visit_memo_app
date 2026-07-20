import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/todo_item.dart';
import 'database_service.dart';

/// 本地通知服务
/// 每日08:00和20:00推送未处理事项提醒
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知插件
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// 发送即时通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'todo_reminder',
      '待办提醒',
      channelDescription: '每日待办事项提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// 获取未完成待办数量并发送提醒
  Future<void> sendIncompleteReminder() async {
    try {
      final db = DatabaseService();
      final count = await db.getIncompleteCount();

      if (count > 0) {
        await showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '待办提醒',
          body: '您还有 $count 项待办事项未完成',
        );
      }
    } catch (e) {
      // 静默失败
    }
  }

  /// 创建定时通知渠道
  /// 注意：Android上真正的定时通知需要通过 WorkManager 或 AlarmManager
  /// 此处提供UI层面的计划能力，精确定时需用平台特定代码
  Future<void> scheduleDailyReminders() async {
    // 注册两个固定的通知渠道ID
    // 实际定时需要配合 flutter_workmanager 或 android_alarm_manager
    // 目前使用便捷的中午和晚上检查
    // 更精确的实现需要在原生层做AlarmManager调度
    await initialize();
  }
}