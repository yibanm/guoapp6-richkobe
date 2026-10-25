# 科比短剧 — 多站源短剧观看与下载客户端

Flutter + Go 多端短剧应用，站源请求、解析、在线播放、下载与合并全部在设备端完成，不依赖自建服务。单一版本内置全部站源：红果、黄豆、剧果、野果、帝果、黄果（视频 / AI / 旧版），以及芽果、猫果、饭果、观果、河果、星果、花果、牛果、网果、发果、皮果、伍果。

功能亮点：

- 多站源浏览、搜索、榜单与推荐，分类翻页自动加载
- 在线播放支持多线路选择与切换、跨集线路复用、清晰度切换、倍速、弹幕、画中画
- 追剧 / 观看历史 / 继续观看，按用户独立保存，支持搜索与筛选
- 分集批量下载、断点续传、下载后合并导出，兼容 Emby 媒体库
- 手机 / 平板 / Android TV / Windows 自适应布局，浅色深色主题

## 功能特性

### 浏览与搜索

- 分类目录支持默认排序、名称、自然季号、上线日期、热度、播放量排序，及连载状态筛选；下拉或「更新剧库」执行查新与资料补齐
- 红果合并官网与名称索引搜索，输入停顿即出联想；剧果、野果等站源支持在线分页搜索；其余站源筛选已加载内容
- 红果分类栏提供真人剧、漫剧、AI 剧推荐流，可刷新续推

### 播放

- 播放器提供线路选择（清晰度按钮右侧「线路 N」），播放中可切线路并保留位置；同剧后续集数默认复用已选线路
- 手机端：上滑下一集、下滑上一集、长按临时 2 倍速、单击切控制层、双击暂停 / 继续；桌面端：空格播放暂停、方向键快进快退与音量、F 全屏、M 静音
- 支持弹幕（红果在线播放默认开启）、画中画（Android 手机 / 平板）、局域网推送播放
- Windows 桌面端提供画质增强入口（关闭 / 自动 / 省电增强 / 清晰优先）

### 追剧与下载

- 按想看 / 在看 / 已看 / 有更新筛选追剧，红果发现新季自动进入「有更新」；观看进度每 5 秒及退出时记录
- 播放页与详情页均可选择分集与画质下载，支持批量暂停、继续、重试、删除；「更新本剧」补新增分集
- 下载完成后可合并导出，生成兼容 Emby 的媒体库结构

### 多端适配

- Android 手机 / 平板：竖屏视频下方选集 / 简介 / 下载 Tab，横屏分栏
- Android TV：遥控焦点布局，统一横屏，播放设置面板含线路入口
- Windows：安装版与便携版，键盘快捷键完整

## 截图

（待补充实机截图）

## 下载与安装

从本仓库 Releases 或 Actions Artifact 获取：

| 平台 | 文件 | 安装方式 |
| --- | --- | --- |
| Android 8.0+ | `kobedrama-<版本>-android-arm64.apk` | 允许未知来源后直接安装（多数现代机型） |
| Android 8.0+（32 位） | `kobedrama-<版本>-android-arm.apk` | 同上 |
| Windows 10 1903+ / 11 x64 | `kobedrama-<版本>-windows-x64-setup.exe` | 双击安装到当前用户目录 |
| Windows 便携版 | `kobedrama-<版本>-windows-x64-portable.zip` | 完整解压后运行 `kobedrama.exe` |

Android 包名为 `com.richkobe.shortdrama`，与上游「短剧视界 / 全剧视界」不互通，首次安装为全新应用。校验值见产物同目录 `SHA256SUMS.txt`。

## 使用说明

- 普通点剧直接进入播放；下载和兜底入口保留详情页
- 卡片「更多」菜单提供收藏、状态设置与下载选集；发现页长按卡片进入多选下载，一次最多 50 部
- 「更多」页含站源管理、用户管理、设置与备份、界面模式；外观主题支持浅色 / 深色 / 跟随系统
- 站源可用性、清晰度和区域限制取决于源站及网络；应用不解除源站 VIP 或其他授权限制，VIP 内容可能只有试看

## 从源码构建

依赖：Flutter 3.47.4（stable）、Go（版本见 `native/go.mod`）、Python 3.12+；Android 构建需 `ANDROID_HOME` 与 NDK 28.2.13676358；Windows 打包需 MinGW-w64 与 Inno Setup 6。

```sh
# Android（全部站源版）
python scripts/build_android.py --all-sources

# Windows（全部站源版，产出安装版 + 便携版）
python scripts/build_windows.py --all-sources
```

产物输出到 `dist/`。国内网络可加 `--cn-mirrors` 使用镜像源。CI 使用 GitHub Actions（`.github/workflows/build.yml`）：每次推送先运行 checks（脚本测试、dart format / analyze / test、go test），通过后并行构建 Android 与 Windows；Release 仅在手动 workflow_dispatch 勾选 `publish_release` 时创建。

### 上游同步

本仓库是 `WangXingFan/guoapp` 的品牌重制 fork。同步上游只拉取源码：`README.md`、`CHANGELOG.md`、`AGENTS.md` 已标记 `merge=ours`，合并前一次性执行 `git config merge.ours.driver true`，再 `git fetch upstream && git merge upstream/main`。详见 AGENTS.md。

## 项目结构

| 目录 | 内容 |
| --- | --- |
| `lib/` | Flutter / Dart 应用层（页面、播放器、下载、存储） |
| `native/core/` | Go 原生核心：站源解析、目录缓存、播放线路、下载调度 |
| `native/bridge/` | Go c-shared 桥接层，产出 `libduanju_core.so` / `duanju_core.dll` |
| `android/` `windows/` `ios/` | 各平台工程（iOS 仅保留源码，不构建） |
| `scripts/` | 构建、打包、图标生成、收尾同步脚本 |
| `test/` `integration_test/` | Dart 单元与组件测试 |

## 常见问题

- **APK 安装报 `INSTALL_FAILED_NO_MATCHING_ABIS`**：架构不匹配，换对应架构安装包。
- **部分剧集只有前几集能播**：源站 VIP / 试看限制，应用不解除授权限制；可尝试切换线路或其他站源搜索同名剧集。
- **Windows 便携版启动失败**：确认完整解压了 ZIP（含全部 DLL 与 `data` 目录），不能只运行 EXE。

## 许可证

播放器使用 [media_kit](https://github.com/media-kit/media-kit) / libmpv，合并导出使用 [FFmpegKit min-gpl](https://github.com/sk3llo/ffmpeg_kit_flutter)（含 FFmpeg、x264 / x265 等 GPL 组件），各组件适用其上游许可证。本仓库源码许可跟随上游 `WangXingFan/guoapp`。
