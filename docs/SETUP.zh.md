# UrbanFlora 本地跑通 & 交作业手册（中文）

> 面向作者自己，从零到"可以交"的一条龙。英文版说明在项目根部的
> [`README.md`](../README.md) 里，这里只写操作。

每一步做完都有 ✅ **验证**。验证过不了就别往下走。

---

## 0. 前置环境

打开 PowerShell，**工作目录 `D:\CASA0015`**。

```powershell
cd D:\CASA0015
flutter --version
dart --version
git --version
node --version          # Firebase CLI 要 Node 18+
```

✅ `flutter` 应当 `>= 3.24`，`dart` `>= 3.5`，`node` `>= 18`。

若有缺失：

| 缺什么 | 怎么装 |
|---|---|
| Flutter | https://docs.flutter.dev/get-started/install/windows 下载 zip，解压到 `C:\src\flutter`，把 `C:\src\flutter\bin` 追加到 **系统环境变量 PATH**。新开一个 PowerShell 让变量生效。|
| Node | https://nodejs.org/ 下载 LTS (20.x) 一键安装器。|
| Android toolchain | Android Studio → 启动 → Plugins 装 `Flutter` → 主界面 More Actions → SDK Manager → 勾选 `Android SDK Platform 34`、`Android SDK Build-Tools`、`Android SDK Command-line Tools`。|

装完再跑一次 `flutter doctor`，所有 `[√]` 点亮就行（`[!]` 的 iOS 那条 Windows 上可以忽略）。

---

## 1. 生成 Android / iOS 平台目录

项目里现在只有 `lib/` 和 `test/`，需要补一套平台壳子：

```powershell
flutter create . --project-name urban_flora --org com.urbanflora --platforms=android,ios
flutter pub get
```

✅ `D:\CASA0015` 下多出 `android\`、`ios\`、`.metadata` 三样东西；`flutter pub get` 最后一行是 `Got dependencies!` 或 `Resolving dependencies... Got dependencies.`。

立刻提交一次：

```powershell
git status
git add android/ ios/ .metadata
git commit -m "chore(platform): generate Android and iOS scaffolding via flutter create"
```

---

## 2. 加 Android / iOS 平台权限

### Android

用 VS Code 打开 `android\app\src\main\AndroidManifest.xml`，在最外层 `<manifest>` 标签（还没进入 `<application>`）里加四行 `<uses-permission>`：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

然后在同一文件的 `<application …>` 开标签里追加：

```
android:usesCleartextTraffic="true"
```

最后改 `android\app\build.gradle`（不是 `android\build.gradle`），把

```
minSdkVersion flutter.minSdkVersion
```

改成

```
minSdkVersion 23
```

（Firebase Auth 的硬性下限。）

### iOS

（Windows 上开发 iOS 需要 Mac 打包，但配置文件可以现在就填好。）

打开 `ios\Runner\Info.plist`，在最外层 `<dict>` 的末尾 `</dict>` **之前**追加：

```xml
<key>NSCameraUsageDescription</key>
<string>UrbanFlora needs the camera to identify plants you photograph.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>UrbanFlora uses your location to tag each plant observation.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>UrbanFlora can pick an existing photo to identify a plant.</string>
```

### 提交

```powershell
git add android/app/src/main/AndroidManifest.xml android/app/build.gradle ios/Runner/Info.plist
git commit -m "chore(platform): declare camera, location and photo library permissions"
```

---

## 3. 生成启动图和图标

项目里已经有 `assets/images/splash_logo.png` 和 `app_icon.png`，`pubspec.yaml` 里也写好了 `flutter_native_splash` 和 `flutter_launcher_icons` 的块。两条命令做完：

```powershell
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

✅ `android\app\src\main\res\` 下各 `mipmap-*` 文件夹新出现 `launcher_icon.png`；`ios\Runner\Assets.xcassets\AppIcon.appiconset\` 里各种尺寸图片就位。

Splash / icon 生成物不用提交（它们是构建产物，`.gitignore` 会管）。

---

## 4. 建 Firebase 项目 + 接入

### 装工具

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

把 `%LOCALAPPDATA%\Pub\Cache\bin` 加到 PATH（否则后面 `flutterfire` 命令不认）。新开 PowerShell。

### 登录 + 建项目

```powershell
firebase login                       # 浏览器走 Google 登录
firebase projects:create urbanflora-chengju --display-name "UrbanFlora"
```

如果名字被占用，换 `urbanflora-chengju-1` 之类。

### 改 `.firebaserc`

VS Code 打开项目根的 `.firebaserc`，把

```
"default": "urbanflora-dev"
```

换成你刚才创建的 project id，例如 `urbanflora-chengju`。

### 接入到 Flutter 代码

```powershell
flutterfire configure
```

- 选你刚创建的 project
- 平台勾 `android`、`ios`（iOS 即使没 Mac 也勾上，配置不会报错）
- 回车

✅ 运行完：`lib/firebase_options.dart` 被真实内容覆盖；`android/app/google-services.json`、`ios/Runner/GoogleService-Info.plist` 生成。**这三样都在 `.gitignore` 里，不会被提交，这是设计好的。**

### 打开三个服务（Firebase 控制台手点）

浏览器打开 https://console.firebase.google.com/ → 你的项目：

1. **Build → Authentication → Get started**
   - Sign-in method 下开启 `Google` 和 `Anonymous` 两项
2. **Build → Firestore Database → Create database**
   - Production mode
   - Region 选 `europe-west2 (London)`
3. **Build → Storage → Get started**
   - Production mode
   - Region 同上

### 部署已有安全规则

```powershell
firebase deploy --only firestore:rules,storage
```

✅ 输出里看到两行 `✔ ... released rules`。

---

## 5. 填真 API Key

```powershell
Copy-Item lib\core\constants\api_keys.dart.example lib\core\constants\api_keys.dart
```

VS Code 打开 `lib\core\constants\api_keys.dart`，把两个 `YOUR_*` 换成真值：

- **Pl@ntNet**：https://my.plantnet.org/ 登录 → Settings → API key，个人 500 次/天免费。
- **OpenWeatherMap**：https://openweathermap.org/api → Sign up → API Keys 标签 → 默认那一串。新 key 大概要等 10 分钟激活。

`api_keys.dart` 被 `.gitignore` 覆盖，不会误 push。

> 如果这一步暂时跳过，App 里 Pl@ntNet 服务会自动走 demo stub —— 给三个假候选让流程能跑通；天气会显示 "unavailable"。演示也行。

---

## 6. 跑起来

连真机（USB 调试打开）或起模拟器：

```powershell
flutter devices             # 确认能看到设备
flutter analyze             # 必须 0 errors
flutter test                # 5 个 test file 应全绿
flutter run
```

✅ App 装上，依次出现：启动屏 → 三页 onboarding → 登录页（点 `Continue anonymously`）→ 主页（空 codex）。

**端到端流程自测一遍：**

1. 点底部中间凸起的绿色相机按钮
2. 对着窗外植物（或屏幕上一张花的图片）拍一张
3. 弹出识别页 → 选第一个候选 → 点 `Add to my codex`
4. 成就动画弹出 → 回到主页，`Recent finds` 里新增一条、streak 变成 1 天

跑通了这一套就算 **MVP 可交**。

---

## 7. 截图 + 录 demo GIF

**用真机 + adb 截：**

```powershell
adb shell screencap -p /sdcard/s.png; adb pull /sdcard/s.png docs\screenshots\01_splash.png
```

按 README 表格的 10 个文件名顺序拍：

```
01_splash.png           启动屏
02_onboarding.png       第一页 onboarding
03_home.png             主页 + streak card
04_camera.png           相机预览 + compass HUD
05_identify.png         Top-3 候选
06_achievement.png      成就弹层
07_detail.png           观察详情（SliverAppBar）
08_map.png              地图 + 彩色 pin
09_codex.png            Codex 按科分组
10_digest.png           daily digest 弹窗
```

**录 demo 视频（3 分钟以内）：**

```powershell
# 安装 scrcpy (https://github.com/Genymobile/scrcpy/releases)
scrcpy --record docs\screenshots\demo.mp4 --max-size 720
```

按提前列好的步骤走一遍流程，录完按 Ctrl+C 停。

**转成 GIF：**

在线最快：https://ezgif.com/video-to-gif
- 宽度设 480，帧率 12
- 导出后控在 5 MB 以下
- 另存为 `docs\screenshots\demo.gif`

### 提交一波

```powershell
git add docs/screenshots/
git commit -m "docs: add device screenshots and demo gif"
```

---

## 8. 推到 GitHub

浏览器打开 https://github.com/new → 创建仓库：

- Repository name: `CASA0015`
- Description: `UrbanFlora — every plant is a chapter. CASA0015 submission.`
- Public
- **不要勾** README / .gitignore / license（本地已经有）
- Create repository

回到 PowerShell：

```powershell
git remote add origin https://github.com/ChengJu1/CASA0015.git
git branch -M main
git push -u origin main
```

首次 push 会弹浏览器要你授权 Git for Windows 的 GitHub login。

✅ 刷新 GitHub 仓库页，文件全部在；Actions 标签页里看到 `Flutter CI` 这条 workflow **自动跑**，两分钟内应该变绿勾。

---

## 9. 开 GitHub Pages

仓库页 → **Settings** → 左栏 **Pages**：

- Source: `Deploy from a branch`
- Branch: `main` / Folder: `/docs`
- Save

大概 1-2 分钟后：`https://chengju1.github.io/CASA0015/` 会出你的落地页。

**把这两个 URL 贴到 README 顶部做徽章：**

打开 `README.md`，在第 3 行（`> Every plant is a chapter.` 那行）下面插入：

```markdown
[![Flutter CI](https://github.com/ChengJu1/CASA0015/actions/workflows/flutter.yml/badge.svg)](https://github.com/ChengJu1/CASA0015/actions/workflows/flutter.yml)
[![Pages](https://img.shields.io/badge/pages-live-brightgreen)](https://chengju1.github.io/CASA0015/)
```

提交：

```powershell
git add README.md
git commit -m "docs: add CI and GitHub Pages badges to README"
git push
```

---

## 10. 交作业清单

提交前最后一次勾：

- [ ] `flutter analyze` = 0 errors
- [ ] `flutter test` 全绿
- [ ] GitHub Actions `Flutter CI` 最新一次绿勾
- [ ] 仓库根部 `README.md` 能在 GitHub 上正常渲染，所有链接点得开
- [ ] `docs/screenshots/` 下 10 张 PNG + 1 个 demo.gif 齐全
- [ ] GitHub Pages 落地页 `chengju1.github.io/CASA0015/` 能访问
- [ ] `docs/personas.md`、`storyboard.md`、`user_testing_plan.md` 都在
- [ ] `firebase deploy` 过的规则生效（Firestore 控制台 Rules 标签能看到你的规则内容）
- [ ] 真机演示：拍一朵花 → 选候选 → 保存 → 成就弹层 → Codex 里多一条。整个链路 <30 秒。

然后在 Moodle 上按 CASA0015 作业页面要求提交 repo URL + Pages URL + demo GIF / 视频。

---

## 出问题速查

| 症状 | 原因 | 解法 |
|---|---|---|
| `flutter run` 立刻闪退，日志 `Firebase not configured` | `firebase_options.dart` 没被 `flutterfire configure` 覆盖 | 第 4 步重新跑 `flutterfire configure` |
| 相机点了没反应 / 一直黑屏 | Android 相机权限没给 | 手机 设置 → 应用 → UrbanFlora → 权限 → 相机允许 |
| Pl@ntNet 401 / 403 | key 填错、含空格、或 endpoint 里 `all` 被改 | 重填 key；endpoint 保持 `https://my-api.plantnet.org/v2/identify/all` |
| Pl@ntNet 返回 0 个候选 | 图片太暗 / 不是植物 | 换一张清晰的植物照 |
| OSM 地图白屏 | OSM 限速 | 等 30 秒再试；别批量加载上百 pin |
| `flutter test` 全报 null safety | dart 太旧 | 装 Flutter 3.24+ |
| GitHub Actions 红叉 | 本地分析没过就 push | `flutter analyze --fatal-infos` 本地过掉再 push |
| Google sign-in 报 `SIGN_IN_FAILED` | `google-services.json` 缺 SHA1 指纹 | `cd android; ./gradlew signingReport` 拿到 `SHA1`，回 Firebase 控制台 → Project settings → 你的 Android app → Add fingerprint |

---

## 附：每次做完一块，建议的 commit message 模板

```
feat(<模块>): 一句话说清楚这一批改了什么
chore(platform): 平台壳 / 构建配置类
docs(...):      只动文档
fix(...):       改 bug
test(...):      只加测试
ci(...):        只动 CI
```

别把截图和代码混在同一个 commit 里；别把两个不相关的功能塞同一个 commit 里。这样最后 `git log --oneline` 就是一个干净的开发故事。
