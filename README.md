# Luma Trail · macOS MVP

一个原生 Swift / AppKit 菜单栏鼠标粒子工具。参考 Sparkle Mouse 的桌面粒子方向独立实现，未复制其代码、图像或品牌素材。

## 运行

Apple Silicon（M1 或更新）Mac，macOS 13+。

解压 `Luma-Trail-MVP.zip`，打开 `Luma Trail.app`。首次启动显示设置窗口；关闭窗口后，效果继续运行，可从菜单栏的星光图标打开设置或退出。

这是本地开发构建，使用 ad-hoc 签名，未经过 Developer ID 公证，不是 App Store 发布包。无需关闭 SIP。此版本只读取指针位置和鼠标按键状态，不请求辅助功能或屏幕录制权限。

## 功能

- 二十四套原创绘制的效果，外加缤纷混合和自定义图片。全部支持原有闪烁、大小、密度、消散时间和不透明度设置。已有皮肤编号保持兼容。
- 皮肤选择区为两列可滚动卡片。新主题包含樱花、萤火虫、碎纸、流星、枫叶、蒲公英、音符、星环、仙尘、极光、羽毛、月牙、火花和水波。
- 仙女星尘采用粉色四角亮片：完整实心四角星（无中心白点）、随机大小与旋转，移动时向外散开，停止后现有亮片自然消失，不再生成粒子。
- 导入自己的 PNG / JPEG / TIFF；透明 PNG 最佳，单张小于 10 MB。图片在本机缩放为 128×128 后保存。
- 调节粒子大小、密度、消散时间、不透明度、闪烁速度（0.2–4 Hz）。所有主题和自定义图片都独立闪烁。
- 可选点击绽放；实时深浅色预览。
- ⌘⇧S 全局暂停 / 开启，也可点击设置窗口右下角的状态或从菜单栏操作；若热键冲突，状态提示会说明。
- 每块屏幕独立透明覆盖窗口，鼠标事件穿透。粒子层与鼠标外观设置独立。
- 最多 240 个粒子，运动时 60 Hz、粒子消失后 24 Hz 采样，暂停后停止桌面计时器。
- 设置自动记忆；仅检查和下载更新时联网，没有账户、自动开机启动或额外常驻后台服务。
- Sparkle 应用内更新：默认每天自动检查，设置页显示当前版本、检查状态和可用新版，可关闭自动检查；设置页和菜单栏菜单均可手动检查。安装需用户确认。

## 鼠标外观（0.2.0）

点击设置窗口顶部的“鼠标美化”：

1. 选择默认箭头、链接、文本、精确选择、可抓取、抓取中、水平缩放、垂直缩放、不可用之一。
2. 为当前状态导入静态 PNG / JPEG / TIFF（≤ 10 MB），建议透明 PNG。图片缩放保存，原文件可以移动。
3. 可保留原色，或开启统一染色并选择颜色。没有上传图片时，统一染色使用系统形状。
4. 调整当前状态大小（最长边 16–64 pt），在棋盘预览中点击设置热点。热点按图片左上角计算。
5. 点击“应用鼠标外观”。清除某状态后需再次应用；开启统一染色时，该状态会回到染色的系统形状。

图片和草稿参数保存在本机。恢复原鼠标不会删除图片；退出时自动恢复，异常退出后下次打开尝试恢复。重新打开不会自动套用外观，需要点击应用。拖影开关只控制粒子，鼠标外观可单独恢复。

系统彩色等待球暂不支持替换，避免原生 30 帧动画无法通过注册接口完整还原。当前 macOS 26 上精确选择资源未开放，应用时会明确报告跳过。不同系统可用状态有差异；应用自绘的鼠标、网页自己的 CSS 图片鼠标不保证替换。

此功能通过动态加载 WindowServer 非公开接口实现，未修改系统文件、未关闭 SIP，也不修改系统的辅助功能指针颜色设置。应用前使用进程内的资源注册检查原图能否恢复；检查失败的状态不会替换。系统更新可能影响兼容性；系统辅助功能中的自定义指针颜色也可能遮盖主题效果。

接口研究参考 [Mousecape](https://github.com/alexzielenski/Mousecape)、[Mousecape SwiftUI](https://github.com/sdmj76/Mousecape-swiftUI) 与 [macOS 26 alias notes](https://github.com/Lancelaut/mousecape-macos26-cursor-alias-fix)。动态桥接和界面独立实现，不包含第三方主题或系统鼠标素材文件。

## 构建

安装 Xcode Command Line Tools 后，在此目录执行：

```sh
bash build.sh
```

构建脚本会运行模型测试，在临时目录完成签名核验，再生成 `dist/Luma Trail.app` 与 `dist/Luma-Trail-MVP.zip`。编译缓存位于 `.build/`，生成文件均已排除在 Git 之外。Documents 文件同步服务可能给复制后的 `.app` 附加 Finder 元数据，影响严格签名核验；ZIP 来自核验通过的临时应用包，建议用 ZIP 分发。

首次构建会下载固定的 [Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)，校验 SHA-256 后嵌入 framework，并附带许可证。后续复用 `.build/sparkle/` 中的完整下载缓存。打包时仅在临时副本中保留 arm64 架构，并按 [官方说明](https://sparkle-project.org/documentation/sandboxing/#removing-xpc-services) 移除未启用的 XPC 服务；保留必需的 Autoupdate 和 Updater.app，再由内到外重新进行 ad-hoc 签名和严格校验。应用仍未公证。已有 `dist` 应用会先移到本次构建的临时目录保存，避免合并复制时残留旧框架文件。

推送到 `main` 时，GitHub Actions 会构建并发布 ZIP 和带 Ed25519 更新包签名的 `appcast.xml`。每个提交一个 Release，标签为 `v` + `CFBundleShortVersionString` + 短提交号。附件名是 `Luma-Trail-arm64.zip`。CI 把 `CFBundleVersion` 设置为 `1000 + github.run_number`，所以即使展示版本未变，新推送也能被识别为更新。同一提交重跑复用已发布附件，避免替换客户端正在下载的安装包。

发布完成后，`Publish Sparkle Update` 工作流将 appcast 发布到固定的 `updates` Release；其中安装包 URL 指向具体提交的 Release。只有仍位于 `main` 顶端的提交才能更新此源和 Latest，发布流程串行执行。客户端固定读取 [更新源](https://github.com/debugtheworldbot/luma-trail/releases/download/updates/appcast.xml)，不依赖 GitHub Latest 重定向。生成后会校验版本、下载地址、包大小和签名与构建包中的公钥一致，失败则停止发布。

### 更新签名配置

仓库需设置 GitHub Actions Secret `SPARKLE_PRIVATE_KEY`，内容为与 `Info.plist` 的 `SUPublicEDKey` 对应的 Sparkle 私钥。缺少 Secret 时 CI 会明确失败，不会发布不可验证的更新。私钥不可提交到 Git，也不可写入环境变量文件或日志。

本项目密钥使用钥匙串 account `studio.luma.trail.mvp`；已生成的公钥保存在 `Info.plist`。使用 Sparkle 官方 `generate_keys --account studio.luma.trail.mvp` 可查看公钥，`-x <安全临时路径>` 可导出私钥用于配置 Secret。长期保留该钥匙串密钥；本项目无 Developer ID 签名，不能任意换公钥后指望旧客户端继续更新。详见 [Sparkle 官方接入与签名说明](https://sparkle-project.org/documentation/)。

**首次迁移：** 0.4.0 及更早的安装包没有更新器，必须手动下载安装一次 0.5.0 或之后的接入版，此后才支持应用内更新。应用需解压放到可写位置（建议 `/Applications`）运行；系统 Gatekeeper 和公证要求仍适用。更新退出时保留原有鼠标恢复逻辑。

## 验证范围

粒子模型测试：移动发射、静止不发射、过期清除、跨屏跳变不连线、快速点击的粒子数量上限、暂停清空。

当前机器已进行设置界面和主题预览检查。鼠标图片的透明度、纵横比例、染色和分状态编码测试通过；macOS 26 实测 11 个可用系统状态资源完成替换、大小和热点读回、原图与元数据完整恢复。精确选择状态被明确跳过。多显示器、其他 macOS 版本、全屏游戏和长时间功耗仍需更多实机验证。系统窗口、锁屏和部分特殊全屏内容不保证覆盖。非常短促的点击可能落在采样间隔之间而没有绽放动画，不影响真实点击。

MVP 暂不包含 GIF 动画、主题商城、登录同步、`.sparkle` 文件兼容。

参考：https://sparklemou.se/ ，https://maxvanleeuwen.itch.io/sparkle-mouse

### 预览稳定性回归测试

构建后，在已登录的 macOS 图形会话中运行：

```sh
"dist/Luma Trail.app/Contents/MacOS/LumaTrail" --preview-stress-test
```

测试通过实际 AppKit 窗口绘制 7,200 帧，循环切换全部主题、浅色/深色背景和暂停状态，并检查提示文字。测试不保存参数、不创建桌面覆盖层、不修改系统鼠标。它覆盖了预览逐帧绘制文字时触发 CoreText 异常的历史崩溃路径；普通 `--self-test` 不覆盖窗口持续重绘。
