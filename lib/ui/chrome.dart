import 'package:flutter/foundation.dart';

/// 顶栏/底栏滚动隐藏与底栏双击刷新的联动控制器。
///
/// 底栏第 1 格「首页」、第 2 格「动态」、第 3 格「消息」各有一个刷新计数，
/// 页面监听自己的那个，互不干扰。
class ChromeController extends ChangeNotifier {
  bool _hidden = false;
  int _homeRefreshCount = 0;
  int _feedRefreshCount = 0;
  int _notificationsRefreshCount = 0;

  bool get hidden => _hidden;
  int get homeRefreshCount => _homeRefreshCount;
  int get feedRefreshCount => _feedRefreshCount;
  int get notificationsRefreshCount => _notificationsRefreshCount;

  void setHidden(bool value) {
    if (_hidden == value) return;
    _hidden = value;
    notifyListeners();
  }

  void requestHomeRefresh() {
    _homeRefreshCount++;
    notifyListeners();
  }

  void requestFeedRefresh() {
    _feedRefreshCount++;
    notifyListeners();
  }

  void requestNotificationsRefresh() {
    _notificationsRefreshCount++;
    notifyListeners();
  }
}
