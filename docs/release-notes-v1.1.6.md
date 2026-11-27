# TiebaFrosted v1.1.6

这一版主要包含三项改动：**修复首页关注贴吧网格显示不全**、**修复预测性返回手势动画缓慢**，以及在**看图页长按选单中新增「分享图片」**。

## 安装

| 文件 | 适用 |
| --- | --- |
| `TiebaFrosted-1.1.6-release.apk` | 通用包（arm64-v8a + armeabi-v7a + x86_64，57.3 MB） |

```powershell
adb install -r TiebaFrosted-1.1.6-release.apk
```

- 最低 Android 7.0（API 24），targetSdk 36
- 包名 `com.tiebafrosted.app`，可覆盖升级或与 TiebaLite 共存
- 本包使用 debug 签名，仅供测试；正式分发请自行签名

## 更新内容

### 修复首页关注贴吧列表显示不全

- **根因**：网格模式仅在显示「经过贴吧」header 时才留出顶栏高度 `top + 8`，无访问记录或关闭「首页显示『经过贴吧』」时网格直接从 `8dp` 起排，前两行被透明顶栏遮挡；关注的吧不足一屏时无法滚动露出。
- 修复后无 header 时网格自身补齐 `top + 8` 顶部内边距。

### 修复预测性返回动画缓慢

- **根因**：Flutter 默认 `TransitionRoute.handleCommitBackGesture()` 在 `navigator.pop()` 后会强行调用 `controller.reverse(from: 1.0)`，既让页面先跳回起点，又把 `CardRouteMixin` 的弹簧收尾替换成了约 550ms 的线性慢速倒播；取消手势的 `forward()` 同样走线性长时长。
- 为卡片路由与看图路由覆写提交/取消收尾，改用 `CardRouteMixin` 弹簧从当前手势进度直接收尾/回弹，并在 `PredictiveBackHost` 中加入活动手势守卫，避免底层路由重复收到回调。

### 图片长按选单新增「分享图片」

- 全屏看图页长按「图片操作」选单新增**「分享图片」**。
- Android 端通过 `FileProvider`（`cache/share/`，自动清理 10 分钟前旧缓存）携带 `ClipData` 与 `FLAG_GRANT_READ_URI_PERMISSION` 拉起系统图片分享面板，优先复用本地二级图片缓存。

### 其它

- 版本号 `1.1.6`（build 14）。

## 验证

- `flutter analyze --no-fatal-infos` → **0 issues**
- `flutter test` → **124/124 全部通过**
- 雷电模拟器（Android 14）实测通过首页无历史栏网格布局与看图页长按「分享图片」

## 开源许可

GPL-3.0。详见 `LICENSE` 与 `THIRD-PARTY-NOTICES.md`。
