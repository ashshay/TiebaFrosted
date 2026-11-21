# TiebaFrosted 重构计划

> 用 Hobo / Bifu 的设计方式重写 TiebaLite。
> 目标工程：`D:\coding\TiebaFrosted`　源工程：`D:\coding\TiebaLite`（Kotlin/Compose，保持可用）

---

## 0. 一句话

**TiebaFrosted = 贴吧的数据与容错 + prism_ui 的界面与手感。**
沿用 Hobo / Bifu 已经跑通两次的配方：Kotlin 原版不动，用 Flutter/Dart 重写一份，
界面全部换成 FlClash 的 `prism_ui` 设计语言（液态玻璃、超椭圆圆角、卡片分层、跟手转场），
数据接口与容错规则逐项照搬 Kotlin 版。

---

## 1. 先例：Hobo 与 Bifu 到底做了什么

这两个项目不是"参考风格"，而是**同一套方法论的两次实践**，TiebaFrosted 是第三次。

| 维度 | Hobo（微博） | Bifu（知乎） | TiebaFrosted（贴吧） |
| --- | --- | --- | --- |
| 源工程 | Cobo（Kotlin） | Zhihu++（Kotlin） | **TiebaLite（Kotlin/Compose）** |
| 重写技术栈 | Flutter 3.47.6 / Dart 3.13 | Flutter / Dart | Flutter / Dart |
| 设计语言 | `prism_ui`（path 依赖 FlClash） | 同左 | 同左 |
| 包名 | `com.hobo.app` | `com.bifu.app` | `com.tiebafrosted.app` |
| 代码规模 | ~17,000 行 Dart | ~13,000 行 Dart | 预估 ~20,000 行 |
| 分层 | `data/` + `ui/` | `core/` + `data/` + `ui/` | `core/` + `data/` + `ui/` |
| 状态管理 | provider | provider | provider |
| 网络 | dio | dio | dio |
| 本地存储 | shared_preferences | SQLite + shared_preferences | SQLite + shared_preferences |

### 1.1 两个项目共有的骨架（直接照抄）

```
lib/
├── main.dart              入口，runApp
├── app.dart               依赖装配（同构单例，经 provider 下发）
├── data/                  接口、模型、仓库、设置、存储
└── ui/
    ├── theme.dart         prism ThemeData + 颜色扩展
    ├── shell.dart         四格液态玻璃底栏 + IndexedStack
    ├── chrome.dart        顶栏/底栏自动隐藏控制器
    ├── routes.dart        全部页面跳转与动作入口
    ├── nav.dart           导航 key
    ├── localizations.dart prism 组件自身文案
    ├── pages/             每个页面一个文件
    └── widgets/           卡片、评论、图片、刷新、按压等
```

`ui/chrome.dart` 在 Hobo 里只有 18 行、Bifu 16 行，`ui/nav.dart` 11 行 / 7 行——
说明这套骨架已经稳定到几乎不用改，TiebaFrosted 直接沿用。

### 1.2 prism_ui 提供的、TiebaLite 现在没有的东西

| 能力 | prism_ui 落点 | TiebaLite 现状 |
| --- | --- | --- |
| 液态玻璃底栏 | `navigation_dock.dart` + `liquid_glass.dart`（fragment shader） | 无，普通 NavigationBar |
| 超椭圆圆角 | `shape.dart` 的 `AppShape` / `AppCorner` / `AppRadius` | 普通 `RoundedCornerShape` |
| 表面层级 | `surface.dart` 的 `SurfaceLevel`（page/card/block/inset） | `ExtendedColors` 里 20+ 个平铺颜色 |
| 四档配色风格 | `color_scheme.dart` 的 `ColorStyle`（vivid/tinted/soft/monochrome） | 只有 dynamic + 固定主题 |
| iOS 排版刻度 | `typography.dart` 的 `AppTextStyle`（13 档） | Material `Typography` |
| 跟手转场 | `page_transition.dart` / `deferred_push.dart` | 默认 Compose 转场 |
| 按压反馈 | `press_surface.dart` / `press_sparkle.dart` | ripple |
| 描边图标引擎 | `icons/glyph.dart` + `animated_glyph.dart` | Material Icons |
| 高性能列表 | `sliver_list/`（Fenwick tree 变高列表） | LazyColumn |

---

## 2. 设计规范（从 prism_ui 源码提取，非臆测）

### 2.1 圆角：全部超椭圆

来源 `prism_ui/lib/shape.dart`。**禁止** `StadiumBorder` / `RoundedRectangleBorder` / `ClipRRect` / `drawRRect`。

| Token | 值 | 用途 |
| --- | --- | --- |
| `AppCorner.xs` | 4 | 徽标、小标签 |
| `AppCorner.sm` | 8 | 输入框内元素 |
| `AppCorner.md` | 16 | 卡片、转发块、图片 |
| `AppCorner.lg` | 20 | 大卡片、弹层 |
| `AppCorner.xl` | 24 | 页面级容器 |
| `AppCorner.xxl` | 28 | 底栏、sheet |
| `AppCorner.alert` | 34 | 对话框 |
| `AppCorner.full` | 1000 | 药丸 |

`AppCorner.fit(shortestSide)` 按短边自动降档（上限 `xxl`），小尺寸控件用它。

### 2.2 表面层级：四级，深色模式只升不降

来源 `prism_ui/lib/surface.dart`。

| 层级 | 浅色 | 深色 |
| --- | --- | --- |
| `page` | `surfaceContainer` | `surface` |
| `card` | `surfaceBright` | `surfaceContainer` |
| `block` | `surfaceContainer` | `surfaceContainerHigh` |
| `inset` | `surfaceContainerHighest` | `surfaceContainerHighest` |

规则：`context.surfaceLevel.next` 得到"上一层"，卡片里的卡片用 `block`，再往里用 `inset`。
深色模式**永远不往回降**——这是 prism 的硬约束，TiebaFrosted 必须遵守。

### 2.3 排版：iOS Dynamic Type 刻度

来源 `prism_ui/lib/typography.dart`，单位 dp = pt。

| 样式 | 字号 / 行高 | 贴吧用途 |
| --- | --- | --- |
| `largeTitle` 34/41 | 吧名大标题（折叠头展开态） |
| `title1` 28/34 | 页面标题 |
| `pageTitle` 24/30 | 顶栏标题 |
| `title2` 22/28 | 帖子标题 |
| `title3` 20/25 | 楼层号、区块标题 |
| `headline` 17/22 w600 | 用户名、按钮 |
| `body` 17/22 | 正文 |
| `callout` 16/21 | 楼中楼正文 |
| `subheadline` 15/20 | 卡片默认文字 |
| `footnote` 13/18 | 时间、来源、楼层信息 |
| `caption1` 12/16 | 徽标、计数 |
| `caption2` 11/13 | 角标 |

中文字体回退链（Hobo/Bifu 一致，直接抄）：
`PingFang SC → Noto Sans CJK SC → Source Han Sans SC → Microsoft YaHei → sans-serif`

### 2.4 配色：种子色 + 四档风格

来源 `prism_ui/lib/color_scheme.dart` + `hobo/lib/ui/theme.dart`。

```dart
seededColorScheme(
  seedColor: Color(accentArgb),
  brightness: brightness,
  style: tintCards ? ColorStyle.tinted : ColorStyle.soft,
)
```

| 风格 | 特征 | TiebaFrosted 默认 |
| --- | --- | --- |
| `vivid` | 强调色最抢眼 | 可选 |
| `tinted` | 背景也带种子色相（"卡片跟随壁纸取色"） | 可选 |
| `soft` | 柔和克制 | **默认** |
| `monochrome` | 去色相只留明度 | 可选 |

贴吧默认强调色建议 `Color(0xFF4E9EF5)`（贴吧蓝），支持 Android 12+ Monet 覆盖：
拿到系统强调色时直接当 `primary`，不让算法二次推导（Hobo 的 `exactAccent` 做法）。

### 2.5 动效：四级时长表

来源 `hobo/docs/卡片交互动效方案.md` §2，已被 Hobo 实测验证。

| 层级 | 用在哪 | 时长 | 曲线 | 只动 |
| --- | --- | --- | --- | --- |
| L1 按压 | 卡片、图片、操作图标按下 | 进 90ms / 出 140ms | `easeOutCubic` | transform |
| L2 状态 | 点赞、收藏翻转 | 350ms 填充 + 1.1 峰值 pop | `easeInOutCubic` | color + transform |
| L3 数值 | 赞/回复/浏览数变化 | 180ms | `easeOutCubic` | transform + opacity |
| L4 页面 | 页面转场、顶栏、底栏 | 不改 | — | — |

三条硬约束：
1. 只动 `transform` / `opacity` / `color`，不动 `width`/`height`/`padding`。
2. 跟手优先：按下当帧响应；指针移动 > 10px 立即回弹。
3. `MediaQuery.disableAnimations` 时全部降为 0ms 终态，功能不变。

### 2.6 尺寸常量

来源 `prism_ui/lib/metrics.dart`。

```dart
const listRowMinHeight = 56.0;
const pageToolbarHeight = 72.0;
const sheetToolbarHeight = 48.0;
const sheetAppBarHeight = 68.0;
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
```

---

## 3. 目标架构

### 3.1 目录结构

```
D:\coding\TiebaFrosted\
├── pubspec.yaml                    prism_ui / dynamic_color 走 path 依赖
├── pubspec_overrides.yaml          本机路径覆盖（.gitignore）
├── android/
│   └── app/src/main/kotlin/.../MainActivity.kt   原生通道：Cookie、相册保存、图标切换
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── signer.dart             贴吧 sign 算法（MD5(排序参数 + secret)）
│   │   ├── cuid.dart               cuid / client_id 生成
│   │   ├── device.dart             设备指纹参数
│   │   ├── emoticons.dart          表情包映射
│   │   ├── links.dart              贴吧链接解析（帖子/吧/用户/楼中楼）
│   │   └── html_text.dart         富文本 AST（贴吧正文的 [表情]/@/链接/图片）
│   ├── data/
│   │   ├── api.dart                dio + 拦截器链
│   │   ├── cookie_vault.dart       域名 → cookie 表
│   │   ├── models.dart             容错解析模型
│   │   ├── json.dart               宽松 JSON 读取工具
│   │   ├── repo.dart               业务仓库
│   │   ├── store.dart              会话/多账号/草稿/历史/收藏
│   │   ├── settings.dart           全部设置项 + ChangeNotifier
│   │   ├── local_db.dart           SQLite（sqflite）
│   │   └── media_saver.dart        保存图片/视频到相册
│   └── ui/
│       ├── theme.dart              frostedTheme()
│       ├── shell.dart              四格液态玻璃底栏
│       ├── chrome.dart             顶栏/底栏自动隐藏
│       ├── routes.dart             全部跳转与动作
│       ├── nav.dart
│       ├── localizations.dart
│       ├── pages/                  见 §5 页面清单
│       └── widgets/
│           ├── common.dart         通用组件（HoboEmpty / showFrostedChoices / toast）
│           ├── glyphs.dart         贴吧专用描边图标
│           ├── press_scale.dart    按压缩放
│           ├── refresh.dart        prism 风格下拉刷新药丸
│           ├── remote_image.dart   带 Cookie 的图片加载
│           ├── thread_card.dart    帖子卡片
│           ├── post_tile.dart      楼层
│           ├── subpost_tile.dart   楼中楼
│           ├── forum_card.dart     吧卡片
│           ├── user_list.dart      用户列表
│           ├── rich_text.dart      贴吧富文本渲染
│           └── profile_header.dart 折叠头（照抄 Hobo 的几何可回归做法）
└── docs/
    └── TiebaFrosted-重构计划.md    本文件
```

### 3.2 依赖清单

```yaml
dependencies:
  flutter: {sdk: flutter}
  prism_ui:
    path: D:/coding/repos/FlClash/plugins/prism_ui
  dynamic_color:
    path: D:/coding/repos/FlClash/plugins/dynamic_color
  dio: ^5.11.1
  provider: ^6.1.5
  shared_preferences: ^2.5.6
  sqflite: ^2.4.2
  path_provider: ^2.1.6
  path: ^1.9.1
  crypto: ^3.0.7
  webview_flutter: ^4.14.1
  image_picker: ^1.2.4
  video_player: ^2.11.1
  package_info_plus: ^10.2.2
  photo_view: ^0.15.0
```

`uses-material-design: false`——和 Hobo/Bifu 一致，不引入 Material 组件。

---

## 4. 数据层迁移：Kotlin → Dart 对照

### 4.1 接口层

TiebaLite 的接口分四套（`api/retrofit/interfaces/`）：

| Kotlin 接口 | 行数 | 说明 | Dart 落点 |
| --- | --- | --- | --- |
| `OfficialTiebaApi.kt` | 561 | 官方 JSON 接口（主用） | `data/api.dart` 的 `official` 组 |
| `MiniTiebaApi.kt` | 416 | 小程序接口 | `data/api.dart` 的 `mini` 组 |
| `WebTiebaApi.kt` | 200 | 网页接口（登录、部分写操作） | `data/api.dart` 的 `web` 组 |
| `OfficialProtobufTiebaApi.kt` | 129 | Protobuf 接口（帖子详情、楼层） | `data/api.dart` 的 `pb` 组 |
| `NewTiebaApi.kt` | 92 | 新版接口 | `data/api.dart` 的 `new` 组 |
| `AppHybridTiebaApi.kt` | 69 | 混合 | 按需 |

**关键决策：Protobuf 怎么办。**
TiebaLite 用 Wire 从 `app/src/main/protos/` 的 **260+ 个 .proto** 生成 Kotlin 类，
帖子详情（`PbPageResponse`）、楼层（`PbFloorResponse`）都走 protobuf。

三条路，按优先级：

1. **优先走 JSON 接口**：`OfficialTiebaApi.threadContent` 有 JSON 版本，
   先确认它返回的字段够不够渲染详情页。够就完全不碰 protobuf。
2. **不够则用 Dart 的 protobuf 包**：`protobuf: ^4.x` + `protoc` 生成 Dart 类，
   只生成实际用到的 proto（`PbPageResponse`、`PbFloorResponse`、`ThreadInfo`、`Post`、`User` 等约 15 个），
   不生成全部 260 个。
3. **兜底**：把 protobuf 解析留在原生侧，通过 MethodChannel 返回 JSON。
   代价是每次详情页多一次跨平台调用，不推荐。

> 这一条是**整个计划最大的技术风险**，必须在 P0 阶段用真实接口验证，不能拖到后期。

### 4.2 签名与设备参数

来源 `api/retrofit/interceptors/SortAndSignInterceptor.kt`：

```
sign = MD5(排序后的参数串 + appSecret)
```

- Query 参数：按 `&` 切分后**排序**，拼接（无分隔符）后加 secret 求 MD5。
- FormBody：按 name 排序，`name=value` 直接拼接后加 secret 求 MD5。
- Multipart：文件 part 排最后，其余按 name 排序。

Dart 落点 `core/signer.dart`，用 `crypto` 包的 `md5`。
配套 `core/cuid.dart`（`CuidUtils.kt`）、`core/device.dart`（`DeviceUtils.kt` / `MobileInfoUtil`）。

### 4.3 模型层

| Kotlin | 行数 | Dart |
| --- | --- | --- |
| `api/models/*.kt`（47 个） | — | `data/models.dart` 合并 |
| `models/*.kt`（9 个） | — | 同上 |

照搬 Hobo 的做法：**容错解析**。贴吧接口字段经常缺、类型会变（数字给字符串、数组给对象），
`data/json.dart` 提供 `str()` / `intOr()` / `listOf()` / `obj()` 这类宽松读取器，
模型全部手写 `fromJson`，不用 `json_serializable` 的严格模式。

### 4.4 本地存储

| Kotlin（Room） | Dart |
| --- | --- |
| `AccountDao` | `local_db.dart` 的 `accounts` 表 |
| `BlockDao` | `blocks` 表 |
| `DraftDao` | `drafts` 表 |
| `HistoryDao` | `history` 表 |
| `SearchDao` | `search_history` 表 |
| `TopForumDao` | `top_forums` 表 |

设置项走 `shared_preferences`（`data/settings.dart`，`ChangeNotifier`），
和 Hobo 的 `Settings` 同构。

---

## 5. 页面清单与迁移映射

TiebaLite 有 **76 个页面文件**（`ui/page/` 下）。按 prism 的页面模型重新归并：

### 5.1 主壳（4 格底栏）

| 格 | 页面 | 来源 |
| --- | --- | --- |
| 首页 | 信息流（推荐/关注/最新） | `main/home/HomePage.kt` |
| 发现 | 热搜 + 分类 + 个性化推荐 | `main/explore/*`（Hot / Concern / Personalized） |
| 消息 | 通知中心（回复/At/赞/私信） | `main/notifications/*` |
| 我的 | 个人主页 | `main/user/UserPage.kt` |

### 5.2 二级页面

| TiebaFrosted 页面 | 来源 Kotlin | 备注 |
| --- | --- | --- |
| `forum_page.dart` | `forum/ForumPage.kt` | 吧主页，折叠头 |
| `forum_detail_page.dart` | `forum/detail/ForumDetailPage.kt` | 吧资料 |
| `forum_rule_page.dart` | `forum/rule/ForumRuleDetailPage.kt` | 吧规 |
| `thread_page.dart` | `thread/ThreadPage.kt` | 帖子详情（核心） |
| `subposts_page.dart` | `subposts/SubPostsPage.kt` | 楼中楼 |
| `reply_page.dart` | `reply/ReplyPage.kt` | 回复编辑器 |
| `search_page.dart` | `search/SearchPage.kt` | 搜索入口 |
| `search_forum_page.dart` | `search/forum/*` | 搜吧 |
| `search_thread_page.dart` | `search/thread/*` | 搜帖 |
| `search_user_page.dart` | `search/user/*` | 搜人 |
| `user_profile_page.dart` | `user/UserProfilePage.kt` | 他人主页 |
| `follow_list_page.dart` | `user/followlist/*` | 关注/粉丝 |
| `user_post_page.dart` | `user/post/*` | TA 的帖子 |
| `user_like_forum_page.dart` | `user/likeforum/*` | TA 关注的吧 |
| `edit_profile_page.dart` | `user/edit/*` | 编辑资料 |
| `history_page.dart` | `history/*` | 浏览历史 |
| `thread_store_page.dart` | `threadstore/*` | 收藏 |
| `hot_topic_list_page.dart` | `hottopic/list/*` | 热门话题 |
| `hot_topic_detail_page.dart` | `hottopic/detail/*` | 话题详情 |
| `image_viewer_page.dart` | `photoview/PhotoViewActivity.kt` | 看图 |
| `login_page.dart` | `login/LoginPage.kt` | 登录 |
| `web_page.dart` | `webview/WebViewPage.kt` | 内置浏览器 |
| `settings_page.dart` | `settings/SettingsPage.kt` | 设置总入口 |
| `settings_theme_page.dart` | `settings/theme/AppThemePage.kt` | 外观 |
| `settings_account_page.dart` | `settings/account/*` | 账号管理 |
| `settings_block_page.dart` | `settings/block/*` | 屏蔽 |
| `settings_habit_page.dart` | `settings/habit/*` | 使用习惯 |
| `settings_oksign_page.dart` | `settings/oksign/*` | 自动签到 |
| `settings_more_page.dart` | `settings/more/*` | 更多 |
| `settings_custom_page.dart` | `settings/custom/*` | 自定义 |
| `about_page.dart` | `settings/about/*` | 关于 |

**归并原则**：TiebaLite 的 `*ViewModel.kt` 全部消失，状态改由 `data/repo.dart` +
页面内 `ChangeNotifier` 承担（Hobo/Bifu 都是这个做法，没有 ViewModel 层）。

### 5.3 页面骨架统一

每个页面用 `PrismScaffold`：

```dart
PrismScaffold(
  bar: FrostedAppBar(title: Text('吧名')),   // 滚动自动隐藏
  body: ...,
)
```

个人页/吧主页用 Hobo 的折叠头方案：`PrismScaffold` 收一个零高度 bar，
body 从屏幕最顶上开始画封面，返回/更多按钮由折叠头自己画。
`ProfileHeaderLayout.at(progress)` 抽成纯函数，配单测扫 `progress` 0→1。

---

## 6. 分阶段实施

### P0　地基（1 周）

| 任务 | 产出 | 验收 |
| --- | --- | --- |
| 建工程 | `flutter create` + 包名 `com.tiebafrosted.app` | `flutter build apk --debug` 成功 |
| 接 prism_ui | `pubspec.yaml` path 依赖 + `pubspec_overrides.yaml` | `PrismApp` 能起，底栏玻璃可见 |
| 主题 | `ui/theme.dart` 的 `frostedTheme()` | 深浅色 + 4 档 ColorStyle 可切 |
| 骨架 | `shell.dart` / `chrome.dart` / `nav.dart` / `routes.dart` | 四格底栏可切页，滚动自动隐藏 |
| 签名 | `core/signer.dart` + 单测 | 与 Kotlin 版对同一组参数产出相同 MD5 |
| **接口验证** | `data/api.dart` 打通 `threadContent` | **真实拉到一条帖子详情** |

> P0 的最后一项是**决策门**：如果 JSON 接口拿不到详情页需要的字段，
> 立刻切到 protobuf 方案（§4.1 第 2 条），不要带着不确定性进入 P1。

### P1　只读主链路（2 周）

| 任务 | 页面/文件 |
| --- | --- |
| 模型 + 容错解析 | `data/models.dart`、`data/json.dart` |
| 仓库 | `data/repo.dart`（信息流、吧页、帖子、楼层、楼中楼、用户） |
| 帖子卡片 | `widgets/thread_card.dart` |
| 楼层 / 楼中楼 | `widgets/post_tile.dart`、`widgets/subpost_tile.dart` |
| 富文本 | `widgets/rich_text.dart`（表情、@、链接、图片九宫格） |
| 首页信息流 | `pages/home_page.dart` |
| 吧主页 | `pages/forum_page.dart` |
| 帖子详情 | `pages/thread_page.dart` |
| 楼中楼 | `pages/subposts_page.dart` |
| 看图 | `pages/image_viewer_page.dart` |
| 用户主页 | `pages/user_profile_page.dart` |
| 搜索 | `pages/search_page.dart` + 三个子页 |

验收：不登录状态下能完整浏览 首页 → 吧 → 帖子 → 楼中楼 → 用户 → 搜索。

### P2　交互与动效（1 周）

| 任务 | 说明 |
| --- | --- |
| `PressScale` | 卡片 0.985 / 图片 0.97，90ms 进 140ms 出，10px 取消 |
| 点赞 | `AnimatedGlyph` 350ms 填充 + 1.1 pop + 轻震 + 数字上滑 |
| 收藏 | 同上，颜色用 `primary` |
| 下拉刷新 | `widgets/refresh.dart`（prism 风格顶部药丸） |
| 数字滚动 | `CountRoll`，180ms |
| 长按菜单 | 卡片长按中震 → prism sheet |
| 折叠头 | 吧主页/个人页，几何抽成纯函数 + 单测 |

### P3　登录与写操作（2 周）

| 任务 | 说明 |
| --- | --- |
| Cookie 保险库 | `data/cookie_vault.dart` + 原生通道 `frosted/cookies` |
| 登录 | WebView 抓 Cookie / 粘贴 Cookie / 游客模式 |
| 多账号 | `store.dart` 的账号表 + 快速切换（底栏「我」长按） |
| 回复 | `pages/reply_page.dart`，含表情面板 |
| 发帖 | 标题 + 正文 + 九图 + 上传进度 |
| 楼中楼回复 | 内联编辑器 |
| 点赞/收藏/关注 | 乐观更新 + 失败回滚 |
| 签到 | 单吧签到 + 一键全签（含 mSign） |

### P4　设置与本地能力（1 周）

| 任务 | 说明 |
| --- | --- |
| 设置总入口 | prism 分组列表（`ListRow` + `CollapsibleSection`） |
| 外观 | 深浅色 / 强调色 / ColorStyle / 液态玻璃档位 / 图标形状 |
| 屏蔽 | 关键词、用户、吧；正则支持 |
| 历史 / 收藏 / 草稿 | SQLite |
| 自动签到 | 定时任务 + 通知 |
| 保存图片/视频 | 原生通道 `frosted/media` |
| 关于 | 版本、开源许可、更新检查 |

### P5　打磨（1 周）

- 骨架屏（`skeleton.dart`）
- 空态（`NullStatus` + 自绘插图）
- 错误态与重试
- 无障碍：`Semantics` 补齐、`disableAnimations` 全降 0ms
- 帧预算：120Hz 下 UI 工作 ≤ 8ms，`flutter run --profile` 抓 Timeline
- 图标：IconKitchen 导出一套，`activity-alias` 切圆角/圆形

**合计约 8 周**（单人全职估算）。

---

## 7. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| **Protobuf 接口** | 帖子详情/楼层拿不到数据，P1 卡死 | P0 决策门；优先 JSON，不够则只生成 15 个 proto |
| 贴吧接口风控 | 请求被拒、账号受限 | 照搬 Kotlin 版全部设备参数与请求头；控制频率；不并发轰炸 |
| 液态玻璃性能 | 低端机掉帧 | prism 已提供 `LiquidGlassQuality.standard/ultra` + 关闭档；默认 standard |
| 表情包体积 | 包体膨胀 | 按需下载 + 本地缓存（`EmoticonManager.kt` 的做法） |
| 富文本复杂度 | 贴吧正文格式多（表情/@/链接/图片/视频/投票） | 先做 AST 解析（`core/html_text.dart`），渲染分阶段补 |
| 76 个页面归并 | 漏功能 | §5.2 的映射表逐行打勾，P5 做一次全量对照 |
| 模拟器卡死 | Hobo 遇到过（Flutter 引擎图形栈） | 关闭 Impeller、图片 `cacheWidth` 下采样；优先真机验证 |

---

## 8. 验收标准

### 8.1 设计一致性

- [ ] 全工程无 `RoundedRectangleBorder` / `ClipRRect` / `StadiumBorder`（grep 为 0）
- [ ] 所有卡片走 `SurfaceLevel`，无硬编码颜色
- [ ] 深色模式表面层级只升不降
- [ ] 底栏是液态玻璃，三档可切（关/标准/超高）
- [ ] 排版全部用 `AppTextStyle`，无裸 `fontSize`

### 8.2 功能对齐

- [ ] §5.2 映射表 31 个页面全部落地
- [ ] 登录 → 浏览 → 回复 → 发帖 → 签到 全链路走通
- [ ] 多账号切换正常
- [ ] 屏蔽规则生效

### 8.3 工程质量

- [ ] `flutter analyze --no-fatal-infos` → 0 error / 0 warning
- [ ] `flutter test` 全绿（含签名算法、折叠头几何、富文本解析的单测）
- [ ] `flutter build apk --release --target-platform android-arm64` 成功
- [ ] `flutter run --profile` 抓 Timeline：滚动与动效期间无 > 16ms 帧

---

## 9. 与源工程的关系

- `D:\coding\TiebaLite` **保持可用**，不删不改（Hobo 对 Cobo、Bifu 对 Zhihu++ 都是这个约定）。
- TiebaFrosted 是独立工程，独立包名，可与 TiebaLite 同时安装。
- 接口变更时以 TiebaLite 为准，TiebaFrosted 跟随。
- 许可证：TiebaLite 为 GPL-3.0（见 `LICENSE`），TiebaFrosted 作为衍生作品同样遵循 GPL-3.0；
  `prism_ui` 亦为 GPL-3.0，需在 `THIRD-PARTY-NOTICES.md` 中列明。

---

## 10. 下一步

1. 确认 §4.1 的 protobuf 路线（P0 决策门）。
2. 建工程骨架，跑通 `PrismApp` + 四格底栏。
3. 用真实接口验证 `threadContent`，拿到第一条帖子详情。
4. 按 P1 顺序推进只读主链路。
