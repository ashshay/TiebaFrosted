# TiebaFrosted v1.0.0

贴吧的数据与容错 + `prism_ui` 的液态玻璃界面与手感。

TiebaLite（Kotlin / Jetpack Compose）的 Flutter 重写版，界面换成 FlClash 的
[`prism_ui`](https://github.com/chen08209/prism_ui) 设计语言。

## 安装

| 文件 | 适用 |
| --- | --- |
| `TiebaFrosted-1.0.0.apk` | 全部设备（arm64-v8a + x86_64） |

```powershell
adb install -r TiebaFrosted-1.0.0.apk
```

- 最低 Android 7.0（API 24），targetSdk 36
- 包名 `com.tiebafrosted.app`，可与 TiebaLite 共存
- 本包使用 debug 签名，仅供测试；正式分发请自行签名

## 功能

**浏览**
- 关注贴吧列表（网格 / 单列两种排列，可切换）
- 动态：推荐 / 关注 / 热榜三段
- 帖子详情：主楼 + 楼层 + 楼中楼，正序 / 倒序 / 热门
- 倒序从最后一页进入，直接看最新回复
- 吧主页、吧资料、吧规、吧内搜索
- 用户主页、关注/粉丝、TA 的帖子与关注的吧
- 搜索：吧 / 帖 / 用户
- 看图、视频播放、内置浏览器

**交互**
- 液态玻璃底栏，三档可调（关 / 标准 / 极致）
- 顶栏底栏滚动自动隐藏
- 双击底栏「首页」「动态」刷新并回顶
- 长按底栏「我的」快速切号
- 卡片按压缩放、点赞填充动效、数字滚动
- 吧主页 / 个人页折叠头

**账号与内容**
- 网页登录 / 粘贴 Cookie / 游客模式
- 多账号管理与快速切换
- 回帖、发帖（九图）、楼中楼回复、投票
- 点赞、收藏、关注、签到
- 一键全签（进度显示在通知栏）
- 屏蔽：关键词、正则、用户、吧

**外观**
- 深浅色 / 跟随系统
- 四档配色风格（vivid / tinted / soft / monochrome）
- Android 12+ Monet 壁纸取色
- 自适应图标，支持 Android 13+ 主题图标

## 已知限制

- **写操作未做端到端验证**：回帖、发帖、图片上传、签到、多账号切换的代码路径已打通，
  但为避免向真实账号发内容，未逐项实测。
- **接口依赖非官方协议**：贴吧接口随时可能变更，届时需跟随 TiebaLite 更新。
- **倒序分页**：服务端 `sortType` 只反转页内顺序，页码仍按正序编号，因此倒序从末页
  往前翻。这是服务端行为，不是客户端取舍。

## 技术栈

- Flutter 3.47.6 / Dart 3.13.5
- `prism_ui`（path 依赖 FlClash）：超椭圆圆角、四级 SurfaceLevel、Dynamic Type 排版、
  液态玻璃 shader
- 纯 Dart 协议层：MD5 签名、Helios CUID、Protobuf 编解码（自研 `ProtoWriter`/`ProtoReader`，
  无 `protoc` 依赖）
- `lib/` 77 个文件 / 约 20,700 行

## 验证

- `flutter analyze --no-fatal-infos` → 0 error / 0 warning / 0 info
- `flutter test` → 15/15
- 现网接口探针：15 个只读接口全部通过
- 雷电模拟器（Android 14 / x86_64）实测：登录、浏览、搜索、看图、设置全链路正常

## 开源许可

GPL-3.0。本项目是 [TiebaLite](https://github.com/HuanCheng65/TiebaLite) 的衍生作品，
遵循同一许可；`prism_ui` 亦为 GPL-3.0。详见 `LICENSE` 与 `THIRD-PARTY-NOTICES.md`。

**本软件及源码仅供学习交流使用，严禁用于商业用途。**
