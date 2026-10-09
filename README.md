# 每日记录 · DailyLog

一个 iOS 日记 App：按日历展开，记录每天遇到的新鲜事，可以插图，每天自动换到新的一页。

## 功能

- **今日卡片**：打开就是今天，直接写、直接插图。
- **日历视图**：月历网格，有记录的日期显示小圆点；当天有图时，格子直接显示缩略图。
- **心情 / 天气**：每天点一个 emoji 心情和天气，日历格子上直接显示，一个月翻下来一眼看出状态。
- **标签**：给每天打标签（旅行、美食…），支持从历史标签里一键复用。
- **中国节假日**：日历上标注「休」「班」，含调休补班日，详情页显示节日名。数据来自国务院办公厅通知原文（已收录 2025、2026 年）。
- **那年今日**：主页自动展示往年同一天的记录，点进去可以回看。
- **全文搜索**：搜正文和标签，可按标签筛选，命中关键词会高亮。
- **每日详情页**：文字 + 图片（相册一次最多选 9 张，也可以直接拍照），自动保存，不用点保存按钮。
- **语音输入**：点「语音输入」说话，实时转成文字。优先用设备端离线识别，识别内容不出手机。
- **图片全屏查看**：点开大图，双指缩放、拖动、左右翻页，可以存回相册、分享、删除。
- **记录统计**：连续记录天数、最长连续、26 周热力图、心情分布、标签统计。
- **应用锁**：Face ID / Touch ID 解锁（可回退设备密码），离开 App 再回来需要验证。
- **导出长图**：把一个月拼成一张长图，一键分享/保存。
- **每日提醒**：本地通知，自定义时间提醒你写今天的新鲜事（不需要服务器）。如果那天正好有往年同一天的记录，会改推「那年今日」。
- **每天自动换新页**：跨过零点后，停在"今天"的页面会自动切到新的一天，空白待记；App 回到前台时也会立刻校准。
- **本地存储**：文字存 `Documents/entries.json`，图片压缩后存 `Documents/Images/`，完全离线，不联网。写盘带防抖，语音输入时不会卡。
- **应用内检查更新**：启动时静默检查 Releases 上的新版本，有新版会在左上角显示红点；点开「设置」可以手动检查并跳转下载。
- **深浅色**：设置里可以选「跟随系统 / 浅色 / 深色」，只影响本 App。
- **备份与恢复**：把全部记录和图片导出成一个文件（可以存到 iCloud 云盘、微信、电脑），换手机时导入合并回来。同一天按修改时间取较新的一份，不会覆盖刚写的内容。
- **键盘自动避让**：点开输入框，页面会自动把正在写的那一块滚到键盘上方。

### 节假日数据的维护

放假调休安排每年由国务院办公厅单独发布（通常在前一年 11 月左右）。
数据在 `DailyLog/Models/Holiday.swift` 的 `table` 里，新一年公布后补一段 `off(...)` / `work(...)` 即可，同时把年份加进 `coveredYears`。

### 更新流程（已自动化）

每次 `git push` 到 main，GitHub Actions 会：

1. 重新构建 **未签名 ipa**
2. 生成 `version.json`（含版本号、构建号 = Actions 运行序号、提交说明、下载地址）
3. 把 ipa 和 `version.json` 一起发到 **Releases**，固定 tag 为 `latest`

于是：

- **下载地址永久固定**，且**不需要登录 GitHub**：
  `https://github.com/5smf8w67j9-commits/DailyLog/releases/latest`
- **App 内检查更新**读的是：
  `https://github.com/5smf8w67j9-commits/DailyLog/releases/download/latest/version.json`

构建号每次自增，App 只要发现远端构建号大于本机构建号，就提示有新版本。

> 注意：App 内只能"告诉你"有新版本，**下载后仍需自行签名安装** —— iOS 的签名环节绕不过去。
> 想彻底免签名一键更新，需要走 TestFlight（需付费开发者账号）。

## 目录结构

```
DailyLog/
├── project.yml                     # XcodeGen 工程描述（生成 .xcodeproj）
├── .github/workflows/build-ipa.yml # 云端自动编译出 ipa
├── tools/make_icon.py              # 生成 App 图标（可选，已生成好）
└── DailyLog/
    ├── Info.plist
    ├── DailyLogApp.swift
    ├── Models/Entry.swift
    ├── Models/Appearance.swift       # 浅色 / 深色 / 跟随系统
    ├── Models/Holiday.swift          # 中国节假日 / 调休数据
    ├── Store/EntryStore.swift        # 读写、图片落盘、统计、备份 / 恢复
    ├── Store/UpdateChecker.swift     # 应用内检查更新
    ├── Store/NotificationManager.swift # 每日提醒 / 那年今日（本地通知）
    ├── Store/AppLock.swift           # 应用锁（Face ID / 设备密码）
    ├── Store/SpeechRecognizer.swift  # 语音转文字（Speech 框架）
    ├── Views/Theme.swift             # 视觉风格 / 卡片 / 动画 / 流式布局
    ├── Views/CalendarView.swift
    ├── Views/DayDetailView.swift
    ├── Views/SearchView.swift        # 全文搜索 + 关键词高亮
    ├── Views/StatsView.swift         # 连续天数 / 热力图 / 心情分布
    ├── Views/PhotoViewer.swift       # 全屏看图 + 存相册
    ├── Views/SettingsView.swift      # 设置：外观 / 隐私 / 提醒 / 统计 / 备份 / 版本
    ├── Views/MonthExportView.swift   # 导出月历长图
    ├── Views/UIKitBridges.swift      # 相机、系统分享
    └── Assets.xcassets/            # 图标 + 主题色
```

> 工程文件（`.xcodeproj`）没有提交，由 XcodeGen 从 `project.yml` 现场生成，避免二进制冲突。

---

## 方式一：云端编译出 ipa（推荐，不用 Mac）

1. 在 GitHub 新建一个仓库（公开/私有都行），把本目录推上去：

   ```bash
   cd DailyLog
   git init
   git add .
   git commit -m "init"
   git branch -M main
   git remote add origin git@github.com:<你的账号>/DailyLog.git
   git push -u origin main
   ```

2. 推上去后，仓库的 **Actions** 页会自动开始跑 `Build Unsigned IPA`。
3. 跑完（约 3–5 分钟），点进这次运行，最下方 **Artifacts** 里下载 `DailyLog-unsigned-ipa`，解压得到 `DailyLog-unsigned.ipa`。
4. 用你自己的方式签名后安装。

> 这是**未签名 ipa**，直接装不上，必须签名。你既然有签名办法，直接拿它签就行。

## 方式二：本地用 Mac 编译

需要 macOS + Xcode 15 以上。App 最低支持 **iOS 16.0**。

```bash
brew install xcodegen
cd DailyLog
xcodegen generate          # 生成 DailyLog.xcodeproj
open DailyLog.xcodeproj
```

- 真机调试：在 Xcode 里选自己的 Team，直接 Run。
- 出 ipa：Product → Archive → Distribute App。

## 手动重新生成图标（可选）

```bash
python3 tools/make_icon.py
```

会覆盖 `DailyLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png`。

---

## 想改点什么

| 需求 | 改哪里 |
| --- | --- |
| App 名字 | `DailyLog/Info.plist` 的 `CFBundleDisplayName` |
| Bundle ID | `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER` |
| 主题色 | `Assets.xcassets/AccentColor.colorset/Contents.json` |
| 图片压缩质量 / 最大边长 | `EntryStore.swift` → `addImage` 里的 `downscale(maxSide:quality:)` |
| 每次最多选几张图 | `DayDetailView.swift` → `maxSelectionCount` |

## 用到的系统权限

| 权限 | 用途 |
| --- | --- |
| 相册（读） | 从相册选图插进日记 |
| 相册（写） | 把日记里的图存回相册 |
| 相机 | 直接拍照记录 |
| 麦克风 | 语音输入 |
| 语音识别 | 把说的话转成文字（优先设备端离线） |
| Face ID | 应用锁 |
| 通知 | 每日提醒 / 那年今日 |

全部都是本地能力，App 不联网、不上传任何内容。

## 后续可加的功能

- **iCloud 自动同步**（CloudKit）：需要付费 Apple 开发者账号（$99/年）+ iCloud entitlement，
  免费账号自签的 App 拿不到这个权限，所以暂时用「备份与恢复」替代。
- **桌面 / 锁屏小组件**：需要新建 Widget Extension，并且要靠 App Group 才能读到主 App 的记录；
  App Group 同样是付费账号才有的能力，而且自签时多一个 bundle 要签，容易把安装流程搞坏。
  等上 TestFlight 之后再做最稳。
- 安卓版（Kotlin + Jetpack Compose）
- 记录导出 PDF
- iPad 双栏布局
