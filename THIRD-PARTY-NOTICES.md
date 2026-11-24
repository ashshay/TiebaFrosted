# 第三方组件与许可

TiebaFrosted 作为 TiebaLite 的衍生作品并静态链接了 `prism_ui`，整体以 **GNU General Public License v3.0** 发布（见 [`LICENSE`](LICENSE)）。

## 直接依赖

| 组件 | 版本 | 许可 | 说明 |
| --- | --- | --- | --- |
| [TiebaLite](https://github.com/HuanCheng65/TiebaLite) | 源工程参照 | **GPL-3.0** | 接口协议与业务容错规则来源 |
| [`prism_ui`](https://github.com/chen08209/prism_ui) | path: `FlClash/plugins/prism_ui` 0.1.2 | **GPL-3.0** | 液态玻璃底栏 / 卡片 / 弹层 / 转场 / 图标引擎 |
| [`dynamic_color`](https://pub.dev/packages/dynamic_color) | path: `FlClash/plugins/dynamic_color` | **Apache-2.0** | Android 12+ 壁纸取色（Monet） |
| [dio](https://pub.dev/packages/dio) | ^5.7.0 | MIT | HTTP 客户端 |
| [provider](https://pub.dev/packages/provider) | ^6.1.2 | MIT | 状态注入 |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | ^2.3.0 | BSD-3-Clause | 设置持久化 |
| [sqflite](https://pub.dev/packages/sqflite) | ^2.4.1 | BSD-2-Clause | SQLite 本地存储 |
| [path_provider](https://pub.dev/packages/path_provider) | ^2.1.5 | BSD-3-Clause | 应用私有目录 |
| [path](https://pub.dev/packages/path) | ^1.9.0 | BSD-3-Clause | 路径拼接 |
| [crypto](https://pub.dev/packages/crypto) | ^3.0.6 | BSD-3-Clause | MD5 签名与摘要 |
| [webview_flutter](https://pub.dev/packages/webview_flutter) | ^4.10.0 | BSD-3-Clause | 网页登录与内置浏览器 |
| [image_picker](https://pub.dev/packages/image_picker) | ^1.1.2 | Apache-2.0 | 发帖与回复选图 |
| [video_player](https://pub.dev/packages/video_player) | ^2.9.2 | BSD-3-Clause | 视频播放 |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | ^8.1.0 | BSD-3-Clause | 应用版本读取 |

## 图标路径

- `lib/ui/widgets/glyphs.dart` 中的矢量路径基于 Material Icons（Apache-2.0）。

## 图片资源

- `assets/donate/donate_qr.png`：设置页「捐赠」里的赞赏码，仓库作者自备（与 Hobo 项目同款）。
