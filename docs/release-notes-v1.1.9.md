# TiebaFrosted v1.1.9

这一版修 **看图页捏合放大在真机上不生效**：把下拉关闭从手势竞技场里挪出来，双指缩放不再被单指拖动或翻页抢走。

## 安装

| 文件 | 适用 |
| --- | --- |
| `TiebaFrosted-1.1.9-release.apk` | 通用包（arm64-v8a + armeabi-v7a + x86_64） |

```powershell
adb install -r TiebaFrosted-1.1.9-release.apk
```

- 最低 Android 7.0（API 24），targetSdk 36
- 包名 `com.tiebafrosted.app`，可覆盖升级或与 TiebaLite 共存
- 本包使用 debug 签名，仅供测试；正式分发请自行签名

## 修复

### 看图页捏合放大失效

- **根因**：下拉关闭挂在 `GestureDetector.onVerticalDrag*` 上，`PageView` 又用自己的横向拖动识别器抢翻页。竖向捏合时第一根手指先被竖向拖动抢走；横向或斜向捏合时，第一根手指先动一下就被 `PageView` 认成翻页，`InteractiveViewer` 的缩放识别器再也没机会赢。Widget 测试里两根手指同时落下能过，真机的手指时序更碎，就明显失效。
- **改法**：
  - 删掉下拉关闭的拖动识别器，改用 `Listener` 的原生指针自己算位移、速度与阈值；第二根手指一落下就取消关闭。
  - `PageView` 改为 `NeverScrollableScrollPhysics`，只负责渲染与承接程序化的 `jumpTo` / `animateToPage`；横滑翻页改由看图页自己的指针逻辑驱动（跟手、过阈值翻页）。
  - 双指手势从此只由 `InteractiveViewer` 处理，没有别的识别器抢手指；第二根手指落下时若正在横滑，会先把页面弹回当前页再开始缩放。
- **兜底**：`onLongPress` 与 `onTap` 在多指时摘掉；缩放不足 `1.08×` 松手弹回 1×。

### 保留的看图手势

- 双指捏合 `1.0× → 5.0×`，实时倍率胶囊，倍率超过 `1.6×` 自动换原图。
- 双击定点放大到 `2.4×` / 再双击复原。
- 放大后单指拖动；1× 时横滑翻页、上下拖跟手关闭。

### 其它

- 版本号 `1.1.9`（build 17）。

## 验证

- `flutter analyze --no-fatal-infos` → **0 issues**
- `flutter test` → **136/136 通过**
- 看图手势用例覆盖：双指倍率与翻页锁、双击 2.4×/复原/自动换原图、**竖向捏合**、**错峰捏合（竖向 / 横向：第一根先动、第二根后落）**、横滑翻页、下拉关闭 pop

## 开源许可

GPL-3.0。详见 `LICENSE` 与 `THIRD-PARTY-NOTICES.md`。
