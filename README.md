# 每日记录 · DailyLog

一个 iOS 日记 App：按日历展开，记录每天遇到的新鲜事，可以插图，每天自动换到新的一页。

## 功能

- **今日卡片**：打开就是今天，直接写、直接插图。
- **日历视图**：月历网格，有记录的日期显示小圆点；当天有图时，格子直接显示缩略图。
- **每日详情页**：文字 + 图片（最多一次选 9 张），自动保存，不用点保存按钮。
- **每天自动换新页**：跨过零点后，停在"今天"的页面会自动切到新的一天，空白待记；App 回到前台时也会立刻校准。
- **本地存储**：文字存 `Documents/entries.json`，图片压缩后存 `Documents/Images/`，完全离线，不联网。
- **深浅色**：跟随系统。

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
    ├── Store/EntryStore.swift
    ├── Views/CalendarView.swift
    ├── Views/DayDetailView.swift
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

需要 macOS + Xcode 15 以上。

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

## 后续可加的功能

- iCloud / 云端同步（需要后端或 CloudKit）
- 全文搜索
- 记录导出（PDF / 长图）
- 每日提醒推送
- 心情 / 标签
- 拍照直接录入（现在只做了相册选图）
