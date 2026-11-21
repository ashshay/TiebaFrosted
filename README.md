# TiebaFrosted

> 贴吧的数据与容错 + `prism_ui` 液态玻璃界面与手感。
> 参照源工程：`D:\coding\TiebaLite`（保持独立可用，不修改）。

🌐 **发布页**：<https://ashshay.github.io/TiebaFrosted/>
📦 **下载**：<https://github.com/ashshay/TiebaFrosted/releases/latest>

## 架构概览

```text
lib/
├── main.dart              应用入口与依赖装配
├── app.dart               PrismApp / Monet 动态取色 / 4 档 ColorStyle / 3 档液态玻璃
├── core/                  纯 Dart 协议核心（MD5 签名、Helios CUID/c3_aid、ProtoWire 编解码、链接与富文本 AST、表情映射）
├── data/                  全协议网络层（Protobuf V11/V12/V22/V12_POST + Official/Mini/New/Hybrid JSON）、SQLite、多账号、屏蔽规则、媒体保存
└── ui/
    ├── theme.dart         frostedTheme() 与 iOS Dynamic Type 排版刻度
    ├── shell.dart         四格液态玻璃底栏 + 双击首页刷新 + 长按切号
    ├── chrome.dart        顶栏/底栏滚动自动隐藏控制器
    ├── routes.dart        全页面路由与统一链接分发
    ├── pages/             4 个主标签页 + 32 个二级业务页面
    └── widgets/           超椭圆卡片、楼层、楼中楼、折叠头、富文本、骨架屏、下拉刷新药丸
```

## 本地构建与验证

```powershell
cd D:\coding\TiebaFrosted
$env:Path = "D:\tools\flutter\bin;" + $env:Path
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.21.102-hotspot"

flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
flutter build apk --release --target-platform android-arm64
```

### 构建约束（勿随意回退）

- `android/app/build.gradle.kts` 把 `compileSdk` 固定为 **37**（Flutter 默认仍是 36）：
  `flutter_local_notifications` 23 的 AAR 元数据要求 API 37。降回去会直接构建失败。
- 同一个 `compileOptions` 里开启了 `isCoreLibraryDesugaringEnabled`，并依赖
  `com.android.tools:desugar_jdk_libs`；这是该插件对 `java.time` 的硬要求。
- 通知渠道 `tieba_frosted_oksign` 的栏图标是 `res/drawable-*/ic_stat_oksign.png`
  （由自适应图标的 monochrome 剪影生成），换图标时记得一并重新生成。

## 开源许可

本项目遵循 **GNU General Public License v3.0**（见 [`LICENSE`](LICENSE) 与 [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md)）。
