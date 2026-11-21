import 'package:flutter/foundation.dart';

/// 顶栏/底栏滚动隐藏与双击首页刷新的联动控制器。
class ChromeController extends ChangeNotifier {
  bool _hidden = false;
  int _homeRefreshCount = 0;

  bool get hidden => _hidden;
  int get homeRefreshCount => _homeRefreshCount;

  void setHidden(bool value) {
    if (_hidden == value) return;
    _hidden = value;
    notifyListeners();
  }

  void requestHomeRefresh() {
    _homeRefreshCount++;
    notifyListeners();
  }
}
