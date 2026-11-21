import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 「一键签到」的通知栏播报，对齐 TiebaLite `OKSignService` 的行为：
/// 低优先级渠道、固定 id 原地刷新、结束后自动消失。
///
/// 只在 Android 上真正发通知；其他平台与测试环境静默降级，调用方不必判断。
class OkSignNotifier {
  static const channelId = 'tieba_frosted_oksign';
  static const _channelName = '一键签到';
  static const _channelDescription = '一键全签的进度与结果';
  static const _notificationId = 1089;
  static const _icon = 'ic_stat_oksign';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _granted = true;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureReady() async {
    if (_initialised || !_supported) return;
    _initialised = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Android 13+ 首次使用会弹权限框；用户拒绝就安静地不发，不影响签到本身。
      _granted = await android?.requestNotificationsPermission() ?? true;
    } on Object {
      _granted = false;
    }
  }

  /// 发一条或原地更新当前进度。[ongoing] 为真时通知不可滑走。
  Future<void> show({
    required String title,
    required String text,
    Color? accent,
    bool ongoing = false,
  }) async {
    await _ensureReady();
    if (!_supported || !_granted) return;
    try {
      await _plugin.show(
        id: _notificationId,
        title: title,
        body: text,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: _icon,
            importance: Importance.low,
            priority: Priority.low,
            color: accent,
            ongoing: ongoing,
            autoCancel: !ongoing,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            channelShowBadge: false,
            styleInformation: BigTextStyleInformation(
              text,
              contentTitle: title,
            ),
          ),
        ),
      );
    } on Object {
      // 通知失败不该打断签到。
    }
  }

  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } on Object {
      // 同上。
    }
  }
}

/// 全应用共用一个实例，权限框只弹一次。
final okSignNotifier = OkSignNotifier();
