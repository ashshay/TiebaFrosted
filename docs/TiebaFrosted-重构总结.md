# TiebaFrosted 重构总结

> 对应计划文档：`docs/TiebaFrosted-重构计划.md`  
> 目标工程：`D:\coding\TiebaFrosted`（包名 `com.tiebafrosted.app`，Dart 包名 `tieba_frosted`）  
> 源工程：`D:\coding\TiebaLite`（全程零修改，`git status` 干净）

---

## 1. 总体成果

已完成 **TiebaLite（Kotlin / Jetpack Compose）→ TiebaFrosted（Flutter / Dart + `prism_ui`）** 的全量重构、现网只读接口联调、Android 14 模拟器实机视觉验证以及 Debug / Release APK 双产物构建。

| 指标 | 结果 |
| --- | --- |
| 业务源码规模 | `lib/` 共 **75 个 Dart 文件 / 21,671 行**（另含 `test/` 2 文件 436 行、`tool/` 1 文件 76 行、Android 原生通道 `MainActivity.kt`） |
| 静态分析 | `flutter analyze --no-fatal-infos` → **0 error / 0 warning** |
| 自动化测试 | `flutter test` → **15/15 全部通过** |
| 设计规范扫描 | `RoundedRectangleBorder` / `ClipRRect` / `StadiumBorder` / `drawRRect` / `flutter/material.dart` / 裸 `fontSize:` → **0 处违规** |
| 现网接口探测 | `tool/verify_p0_live.dart` 对百度贴吧真实服务器 **15 个核心只读接口全部通过** |
| Release 构建 | `build/app/outputs/flutter-apk/app-release.apk`（arm64，**19.80 MB**） |
| Debug 构建 | `build/app/outputs/flutter-apk/app-debug.apk`（多 ABI，**186.51 MB**，已安装至 `emulator-5554` 验证） |
| 模拟器运行时错误 | `logcat -d -s flutter:E AndroidRuntime:E` → **0 条错误** |
| 源仓合规 | `D:\coding\TiebaLite` 零修改；已继承 GPL-3.0 `LICENSE` 并提供 `THIRD-PARTY-NOTICES.md` |

---

## 2. 关键技术决策

### 2.1 P0 决策门：Protobuf 现网协议（零 `protoc` 依赖方案）

- 核对 `TiebaLite` 实际调用链（`MixedTiebaApiImpl.kt`）后确认：`OfficialTiebaApi.threadContent`（JSON）已是历史废弃路径，现网核心内容接口均走 `https://tiebac.baidu.com` 的 **Protobuf + Multipart（`--------7da3d81520810*`）** 协议，包括：
  - `pb/page`（302001）、`pb/floor`（302002）、`frs/page`（301001）、`frs/threadlist`（301002）
  - `personalized`（309264）、`userlike`（309474）、`hotThreadList`（309661）、`topicList`（309289）
  - `profile`（303012）、`userpost`（303002）、`getuserinfo`（303024）
  - `getforumdetail`（303021）、`forumRuleDetail`（309690）、`searchSug`（309438）
  - 写接口 `addPost`（309731）、`addThread`（309730）、`addPollPost`（309006）
- 为避免引入 `protoc` 生成流水线膨胀和构建脆弱性，自研纯 Dart 的容错 Protobuf 编解码器 `lib/core/proto_wire.dart`（`ProtoWriter` / `ProtoReader`），并直接对照 `TiebaLite/app/src/main/protos/` 核准字段号实现 `lib/data/proto_codec.dart`，同时兼顾官方 JSON / Mini / New / Hybrid 接口及 `/c/s/uploadPicture` 分片上传。

### 2.2 纯 Dart 核心与设备签名解耦

- `lib/core/` 完整复刻 `TiebaLite` 的 `SortAndSignInterceptor` 与设备指纹体系：MD5 大写签名（`tiebaclient!!!`）、表单/Multipart 排序、IEEE CRC32、XXHash32、40-bit Helios Hasher、Helios Base32、RC4-42，以及 `baseCuid` / `finalCuid` / `newCuid` / `aid` / `sofireCuid`。
- 通过 `DeviceKvStore` 抽象接口将 `TiebaDevice` 与 Flutter 插件 `shared_preferences` 解耦，使得 `lib/core/` 与协议探测脚本可在纯 `dart run` 环境下独立执行，无需依赖 `dart:ui`。

### 2.3 零 Material、`prism_ui` 视觉与交互体系

- `pubspec.yaml` 设置 `uses-material-design: false`，本地接入 FlClash 的 `prism_ui` 与 `dynamic_color`，全工程 0 处 `flutter/material.dart` 导入。
- 统一采用超椭圆（`ClipRSuperellipse` / `AppShape`）、四级 `SurfaceLevel`（单测锁定深色模式单调递增）、Dynamic Type 排版刻度、`ColorStyle` 四档配色（vivid / tinted / soft / monochrome）+ Monet `exactAccent`、以及 3 档 Liquid Glass（关 / 标准 / 极致）。
- 避开已知坑点：使用 `showFloatingDialog` + `AlertDialog` 替代 `showSheet`；`PrismApp.builder` 显式注入 `ViewScope(isMobile: true)`；Android 清单设置 `EnableImpeller=false` 与 `usesCleartextTraffic="true"`。

### 2.4 Android 原生能力与 Windows 构建稳定性

- 在 `android/app/src/main/kotlin/com/tiebafrosted/app/MainActivity.kt` 中实现 4 条 MethodChannel：
  - `frosted/cookies`（WebView Cookie 提取/清除，支撑扫码与网页登录同步）
  - `frosted/media`（Android MediaStore 图片保存）
  - `frosted/browser`（外部浏览器拉起）
  - `frosted/share`（系统分享面板）
- `android/gradle.properties` 固化 AGP 9 Windows 稳定构建参数（`android.newDsl=false`、`android.builtInKotlin=false`、`kotlin.incremental=false`、`org.gradle.daemon=false`、`org.gradle.parallel=false`），确保 Debug 与 arm64 Release 均可一次构建成功。

---

## 3. 代码结构与分层清单

| 目录 | 数量 / 行数 | 职责与主要文件 |
| --- | --- | --- |
| `lib/` 入口 | 2 文件 / 241 行 | `main.dart`（初始化 `LocalDb` / `Settings` / `Store` / `TiebaRepo`）、`app.dart`（`PrismApp`、`ViewScope`、动态取色与路由） |
| `lib/core/` | 7 文件 / 1,118 行 | `signer.dart`、`cuid.dart`、`device.dart`、`proto_wire.dart`、`emoticons.dart`、`links.dart`、`html_text.dart` |
| `lib/data/` | 11 文件 / 7,284 行 | `json.dart`、`models.dart`、`proto_codec.dart`、`api.dart`、`repo.dart`、`local_db.dart`（6 表 SQLite + `inMemory()`）、`store.dart`（多账号、置顶吧、关键词/正则/用户/吧/白名单屏蔽引擎、浏览历史）、`cookie_vault.dart`、`settings.dart`、`native_channels.dart`、`media_saver.dart` |
| `lib/ui/` 基础 | 6 文件 / 878 行 | `theme.dart`、`shell.dart`（4-Tab Liquid Glass `NavigationDock`、首页双击刷新、我的长按 480ms 快切账号）、`chrome.dart`、`nav.dart`、`localizations.dart`、`routes.dart` |
| `lib/ui/widgets/` | 13 文件 / 3,504 行 | `common.dart`、`glyphs.dart`、`press_scale.dart`（`PressScale` + `CountRoll`）、`refresh.dart`、`remote_image.dart`、`rich_text.dart`、`profile_header.dart`（纯函数几何回归 `ProfileHeaderLayout.at`）、`skeleton.dart`、`thread_card.dart`、`post_tile.dart`、`subpost_tile.dart`、`forum_card.dart`、`user_list.dart` |
| `lib/ui/pages/` | 36 文件 / 8,646 行 | 4 主 Tab + §5.2 全部 31 个二级页面 + `video_page.dart` |
| `test/` & `tool/` | 3 文件 / 512 行 | `test/core_test.dart`（9 个核心/几何测试）、`test/data_and_widget_test.dart`（6 个主题/数据库/编解码/App 冒烟测试）、`tool/verify_p0_live.dart`（现网接口探针） |

---

## 4. 页面迁移覆盖对照

- **主壳 4 Tab**：`home_page.dart`（推荐 / 进吧 / 关注）、`explore_page.dart`（热榜 / 话题 / 发现）、`notifications_page.dart`（回复 / @我 / 点赞 / 通知）、`me_page.dart`（个人中心 / 账号卡片 / 收藏历史入口）。
- **贴吧与帖子浏览（9 页）**：`forum_page.dart`、`forum_detail_page.dart`、`forum_rule_page.dart`、`thread_page.dart`、`subposts_page.dart`、`reply_page.dart`、`hot_topic_list_page.dart`、`hot_topic_detail_page.dart`、`video_page.dart`。
- **搜索体系（4 页）**：`search_page.dart`、`search_forum_page.dart`、`search_thread_page.dart`、`search_user_page.dart`。
- **用户与内容资产（7 页）**：`user_profile_page.dart`、`follow_list_page.dart`、`user_post_page.dart`、`user_like_forum_page.dart`、`edit_profile_page.dart`、`history_page.dart`、`thread_store_page.dart`。
- **登录、媒体与内置浏览（3 页）**：`login_page.dart`、`image_viewer_page.dart`、`web_page.dart`。
- **设置中心（9 页）**：`settings_page.dart`、`settings_theme_page.dart`、`settings_account_page.dart`、`settings_block_page.dart`、`settings_habit_page.dart`、`settings_oksign_page.dart`、`settings_more_page.dart`、`settings_custom_page.dart`、`about_page.dart`。

---

## 5. 验证过程与问题修复记录

1. **纯 Dart 探针解耦**：初次运行 `dart run tool/verify_p0_live.dart` 时因 `lib/core/device.dart` 直接依赖 `shared_preferences` 导致无法脱离 Flutter 运行；抽取 `DeviceKvStore` 接口后，15 个真实贴吧接口全部通过实测。
2. **`prism_ui` API 对齐与静态分析清零**：修正 `LinearProgressIndicator` 名称、`SearchField(hintText:, onSubmitted: VoidCallback)` 签名及 2 处未使用导入，`flutter analyze --no-fatal-infos` 达成 0 error / 0 warning。
3. **Widget 冒烟测试修复**：
   - 修复 `HomePage.dispose()` 阶段调用 `context.read<ChromeController>()` 导致的生命周期异常，改为缓存 `_chrome` 引用并在 `dispose` 中移除监听。
   - 在测试中为 `Dio` 挂载 `_EmptyProtoAdapter`，消除 `FakeAsync` 遗留超时 Timer。
4. **模拟器实测视觉打磨**：
   - **贴吧表情加载失败**：发现 `https://static.tieba.baidu.com/tb/editor/images/client/...` 存在 TLS 证书错误导致表情显示裂图占位；切换为实测 HTTP 200 且证书正常的 `https://tb2.bdstatic.com/tb/editor/images/client/...`，并在 `lib/ui/widgets/rich_text.dart` 中将失败回退改为渲染原始 `#(表情名)` 文本。重装验证后，楼层内联贴吧表情（如滑稽）已清晰渲染。
   - **短楼中楼预览块宽度不一致**：在 `lib/ui/widgets/post_tile.dart` 中以 `SizedBox(width: double.infinity)` 包裹楼中楼预览容器，短回复预览块也与卡片内边距完全等宽对齐。

---

## 6. §8 验收标准对照

- **§8.1 设计一致性**：全部通过（零 Material、全超椭圆、四级 `SurfaceLevel` 深色单调递增、3 档 Liquid Glass、4 档 `ColorStyle`、Dynamic Type）。
- **§8.2 功能对齐**：全部 4 主 Tab 与 31 个二级页面完整落位，只读全链路已现网实测通过，登录/回帖/发帖/签到/多账号/屏蔽规则逻辑均已打通接线。
- **§8.3 工程质量**：`flutter analyze --no-fatal-infos` 0 error / 0 warning；`flutter test` 15/15 全绿；Debug 与 arm64 Release APK 均成功产出；模拟器多页面交互 `logcat` 零异常。

---

## 7. 后续可选迭代项

1. **已登录态写操作实测**：在真机使用个人百度账号完成登录后，逐项端到端验证回帖、发帖、图片分片上传、收藏/点赞、关注/取关、一键签到与多账号切换。
2. ~~**应用图标定制**~~：已完成，见 §8.2。
3. **真机 Profile 帧率与内存体检**：在真机通过 `flutter run --profile` 压测快速滑动帖流与 Liquid Glass 渲染帧时间。
4. ~~**清理剩余 info 级 lint**~~：已完成，`flutter analyze` 现为 `No issues found!`，见 §8.3。

---

## 8. 接管记录（2026-11-21）

接手时项目**没有任何版本控制**，且质量门禁仍留有 20 条 info 级 lint。本节记录接管后完成的事项。

### 8.1 版本控制基线

- `git init` + 首次提交，108 个受控文件；`build/`、`.dart_tool/`、`pubspec_overrides.yaml` 均被既有 `.gitignore` 正确排除。
- 新增 `.gitattributes`（`* text=auto eol=lf`，二进制与 `*.ps1/*.bat` 单独声明），避免 Windows 上 CRLF 抖动污染后续 diff。

### 8.2 应用图标

用户提供 IconKitchen 导出的完整图标包（`tieba.zip`），已落入 `android/app/src/main/res/`：

| 资源 | 说明 |
| --- | --- |
| `mipmap-anydpi-v26/ic_launcher.xml` | 自适应图标声明（background / foreground / monochrome） |
| `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` | 传统图标，供 Android < 8 使用 |
| `mipmap-*/ic_launcher_{background,foreground,monochrome}.png` | 自适应图层，monochrome 支持 Android 13+ 主题图标 |

外观为蓝色圆角方块 + 白色窗口符号 + 底部紫色 "TIEBA" 字条，与 Hobo / Bifu / FlClash 同一设计家族。`AndroidManifest.xml` 的 `android:icon="@mipmap/ic_launcher"` 无需改动——存在 `mipmap-anydpi-v26` 时 Android 8+ 自动选用自适应版本。

### 8.3 lint 归零

| 位置 | 原问题 | 处理 |
| --- | --- | --- |
| `thread_page.dart` ×3 | `use_build_context_synchronously` | `_buildBody(BuildContext context, …)` 的形参遮蔽了 `State.context`，分析器无法确认 `mounted` 与之相关；改用 `context.mounted`，并在 `await` 前取出 `repo` |
| `home_page.dart` ×1 | 同上 | 同上，`_buildBody` 形参遮蔽 |
| `forum_page.dart` ×1 | 同上 | 同上 |
| `reply_page.dart` ×1 | 同上 | 缺前置守卫，补 `if (!mounted) return;` 后再取 `LocalDb` |
| `tool/verify_p0_live.dart` ×14 | `avoid_print` | 文件级 `// ignore_for_file: avoid_print`；该脚本的用途就是向终端打印探针结果 |

结果：`flutter analyze --no-fatal-infos` → `No issues found!`（此前为 0 error / 0 warning / 20 info）。

### 8.4 调试环境：雷电模拟器

**AVD 路线不可行**，本机不装虚拟机监控器：

- `ANDROID_HOME` / `ANDROID_SDK_ROOT` 均未设置，真实 SDK 在 `D:\Android\sdk`，而插件（`@zseven-w/dsh-android`）按 `ANDROID_HOME → ANDROID_SDK_ROOT → %LOCALAPPDATA%\Android\Sdk → adb 同级 → PATH` 查找，五处全部落空，故 `android_devices.avds` 恒为空、`android_boot` 无法工作。
- 更关键的是 **x86_64 镜像硬性要求硬件加速**：`HypervisorPresent: False`，AEHD / HAXM / gvm 驱动均未安装。`-accel off` 的 TCG 回退虽能把进程拉起，但 qemu 在 10 秒内 CPU 增量 0.0s（累计 0.4s），guest 从未执行，adb 始终 `offline`。

**改走雷电 14**（`C:\leidian\LDPlayer14`，实例 `0`，1080×2400@440dpi）：`ldconsole launch --index 0` 后经自身 adb 桥接注册为 `emulator-5554`，`android_devices` 正确识别 `kind: emulator`、Android 14 / SDK 34 / x86_64，`android_boot` 的 AVD 发现与此无关。

验证结果：

- `flutter build apk --debug --target-platform android-x64` 成功（161.42 MB）
- `adb -s emulator-5554 install -r` 成功；`monkey` 在雷电镜像中缺失，改用 `am start -n com.tiebafrosted.app/.MainActivity`
- `topResumedActivity` 为 `MainActivity`，进程存活（pid 33568），crash buffer 为空，无 Flutter 异常
- 截图确认：液态玻璃底栏、超椭圆 chip、卡片分层均正常渲染，内容来自真实贴吧接口
- 启动器确认新图标生效，512px 源图文字为 **TIEBA**（非 TEIBA）

