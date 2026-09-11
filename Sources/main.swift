import AppKit
import Carbon
import UniformTypeIdentifiers

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class OverlayView: NSView {
    let system: ParticleSystem
    let painter: ParticlePainter
    let settings: TrailSettings
    var screenOrigin: CGPoint
    init(frame: NSRect, origin: CGPoint, system: ParticleSystem, painter: ParticlePainter, settings: TrailSettings) {
        self.system = system; self.painter = painter; self.settings = settings; screenOrigin = origin
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        painter.draw(system.particles, in: ctx, origin: screenOrigin, at: ProcessInfo.processInfo.systemUptime, twinkleSpeed: settings.twinkleSpeed)
    }
}

final class Surface: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor(hex: 0xF9F6F2).setFill(); bounds.fill() }
}

func label(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular,
           _ color: NSColor = NSColor(hex: 0x39343D)) -> NSTextField {
    let v = NSTextField(labelWithString: text)
    v.font = .systemFont(ofSize: size, weight: weight); v.textColor = color
    return v
}

final class ThemeButton: NSButton {
    override var isFlipped: Bool { false }
    let theme: TrailTheme
    var selected = false { didSet { needsDisplay = true } }
    init(theme: TrailTheme, target: AnyObject, action: Selector) {
        self.theme = theme
        super.init(frame: .zero)
        self.target = target; self.action = action; title = theme.title
        setAccessibilityLabel(theme.title); isBordered = false
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
        (selected ? NSColor(hex: 0xECE3F3) : NSColor.white.withAlphaComponent(0.78)).setFill(); path.fill()
        (selected ? NSColor(hex: 0xAA8BBE) : NSColor(hex: 0xE9E3DE)).setStroke(); path.lineWidth = 1; path.stroke()
        let image = NSImage(systemSymbolName: theme.symbol, accessibilityDescription: nil)!
        let configuration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(hex: 0x9876AD)]))
        image.withSymbolConfiguration(configuration)?.draw(in: NSRect(x: 16, y: 25, width: 25, height: 25))
        (theme.title as NSString).draw(at: NSPoint(x: 54, y: 38), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor(hex: 0x423749)])
        (theme.subtitle as NSString).draw(at: NSPoint(x: 54, y: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor(hex: 0x8A7D8E)])
        if selected { ("✓" as NSString).draw(at: NSPoint(x: bounds.width - 24, y: 37), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor(hex: 0x9876AD)]) }
    }
}

final class PreviewView: NSView {
    let settings: TrailSettings
    let painter: ParticlePainter
    let system = ParticleSystem()
    var light = false
    var point = CGPoint.zero
    init(frame: NSRect, settings: TrailSettings, painter: ParticlePainter) {
        self.settings = settings; self.painter = painter
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
    func step() {
        let t = ProcessInfo.processInfo.systemUptime
        // A moving loop followed by a pause shows the trail fading naturally.
        let phase = min(t.truncatingRemainder(dividingBy: 5), 3.2) / 3.2 * 2 * Double.pi
        point = CGPoint(x: bounds.midX + sin(phase) * bounds.width * 0.30,
                        y: bounds.midY + sin(phase * 2) * bounds.height * 0.23)
        system.tick(at: t, cursor: settings.enabled ? point : nil, settings: settings)
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: bounds, xRadius: 20, yRadius: 20).addClip()
        let top = light ? NSColor(hex: 0xF2E9EE) : NSColor(hex: 0x393143)
        let bottom = light ? NSColor(hex: 0xE8DDF0) : NSColor(hex: 0x1C1A26)
        NSGradient(starting: bottom, ending: top)?.draw(in: bounds, angle: 90)
        (light ? NSColor.black : NSColor.white).withAlphaComponent(0.055).setFill()
        for x in stride(from: 18, to: Int(bounds.width), by: 24) {
            for y in stride(from: 15, to: Int(bounds.height), by: 24) { NSBezierPath(ovalIn: NSRect(x: CGFloat(x), y: CGFloat(y), width: 1.5, height: 1.5)).fill() }
        }
        painter.draw(system.particles, in: ctx, at: ProcessInfo.processInfo.systemUptime, twinkleSpeed: settings.twinkleSpeed)
        // Particle preview uses its own illustrative arrow; cursor skins have a separate editor.
        ctx.saveGState(); ctx.translateBy(x: point.x, y: point.y)
        let cursor = CGMutablePath(); cursor.move(to: .zero)
        // Keep the tip in the same subpath; addLines would start a new one at the next vertex.
        for vertex in [CGPoint(x: 1, y: -18), CGPoint(x: 5.5, y: -13), CGPoint(x: 10, y: -21), CGPoint(x: 13, y: -19), CGPoint(x: 9, y: -11), CGPoint(x: 16, y: -10)] {
            cursor.addLine(to: vertex)
        }
        cursor.closeSubpath(); ctx.addPath(cursor); ctx.setFillColor(NSColor.white.cgColor)
        ctx.setStrokeColor(NSColor(hex: 0x30283C).cgColor); ctx.setLineWidth(1); ctx.drawPath(using: .fillStroke); ctx.restoreGState()
        let ink = light ? NSColor(hex: 0x665870) : NSColor(hex: 0xC8BED3)
        ("LIVE PREVIEW" as NSString).draw(at: NSPoint(x: 20, y: bounds.height - 30), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium), .foregroundColor: ink])
        ((settings.enabled ? "移动时亮片散开，停下后自然消失" : "桌面效果已暂停") as NSString).draw(at: NSPoint(x: 20, y: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: ink])
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var cursorAppearance: CursorWindowController?
    let settings = TrailSettings()
    let system = ParticleSystem()
    let painter = ParticlePainter()
    var panels: [OverlayPanel] = []
    var timer: Timer?
    var previewTimer: Timer?
    var timerHz = 0.0
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow!
    var preview: PreviewView!
    var themeButtons: [ThemeButton] = []
    var sliders: [NSSlider] = []
    var valueLabels: [NSTextField] = []
    var enableButton: NSButton!
    var burstButton: NSButton!
    var hotKey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    var shortcutLabel: NSTextField!
    var suspended = false
    var previousButtons = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Bring the existing instance forward rather than doubling all overlays.
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: "studio.luma.trail.mvp").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
        }
        cursorAppearance = CursorWindowController()
        painter.loadCustom(settings.customData)
        buildMainMenu(); buildWindow(); buildStatusMenu(); buildOverlays(); configureHotkey()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(suspend), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(suspend), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(resume), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(resume), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        applyEnabled(); showSettings()
        previewTimer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, self.settingsWindow.isVisible, !self.suspended else { return }
            self.preview.step()
        }
        RunLoop.main.add(previewTimer!, forMode: .common)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        _ = cursorAppearance?.manager.restore()
        timer?.invalidate(); previewTimer?.invalidate()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        panels.forEach { $0.orderOut(nil) }
    }
    func buildMainMenu() {
        let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self; appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "退出 Luma Trail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        NSApp.mainMenu = menu
    }
    func buildStatusMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Luma Trail")
            statusItem.button?.image?.isTemplate = true
        }
        statusItem.button?.appearsDisabled = !settings.enabled
        statusItem.button?.toolTip = settings.enabled ? "Luma Trail · 已开启" : "Luma Trail · 已暂停"
        let menu = NSMenu()
        let toggle = NSMenuItem(title: settings.enabled ? "暂停桌面效果" : "开启桌面效果", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self; menu.addItem(toggle); menu.addItem(.separator())
        for theme in TrailTheme.allCases where theme != .custom || settings.customData != nil {
            let item = NSMenuItem(title: theme.title, action: #selector(menuTheme(_:)), keyEquivalent: "")
            item.target = self; item.tag = theme.rawValue; item.state = settings.theme == theme ? .on : .off; menu.addItem(item)
        }
        menu.addItem(.separator())
        let preferences = NSMenuItem(title: "打开设置…", action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self; menu.addItem(preferences)
        menu.addItem(NSMenuItem(title: "退出 Luma Trail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let cursorItem = NSMenuItem(title: "鼠标外观…", action: #selector(showCursorAppearance), keyEquivalent: "")
        cursorItem.target = self; menu.insertItem(cursorItem, at: menu.items.count - 1)
        statusItem.menu = menu
    }
    func configureHotkey() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().toggleEnabled()
            return noErr
        }, 1, &type, pointer, &eventHandler)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x4C554D41, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        shortcutLabel.stringValue = status == noErr ? "⌘ ⇧ S  随时暂停 / 开启" : "快捷键被占用，请从菜单栏暂停"
    }
    func buildOverlays() {
        panels.forEach { $0.orderOut(nil) }; panels.removeAll(); system.reset()
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.hidesOnDeactivate = false; panel.animationBehavior = .none
            panel.isReleasedWhenClosed = false
            panel.contentView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), origin: screen.frame.origin, system: system, painter: painter, settings: settings)
            panels.append(panel)
            if settings.enabled && !suspended { panel.orderFrontRegardless() }
        }
    }
    @objc func screenChanged() { buildOverlays() }
    @objc func suspend() { suspended = true; timer?.invalidate(); timer = nil; timerHz = 0; system.reset(); panels.forEach { $0.orderOut(nil) } }
    @objc func resume() { suspended = false; buildOverlays(); applyEnabled() }
    func startTimer(hz: Double) {
        guard hz != timerHz else { return }
        timer?.invalidate(); timerHz = hz
        timer = Timer(timeInterval: 1 / hz, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func tick() {
        guard settings.enabled, !suspended else { return }
        let before = system.bounds
        let now = ProcessInfo.processInfo.systemUptime
        let position = NSEvent.mouseLocation
        system.tick(at: now, cursor: position, settings: settings)
        let buttons = NSEvent.pressedMouseButtons
        if settings.clickBurst && buttons & 1 != 0 && previousButtons & 1 == 0 { system.burst(at: position, time: now, settings: settings) }
        previousButtons = buttons
        invalidate(before.union(system.bounds))
        startTimer(hz: system.particles.isEmpty ? 24 : 60)
    }
    func invalidate(_ globalRect: CGRect) {
        guard !globalRect.isNull else { return }
        for panel in panels {
            let visible = panel.frame.intersection(globalRect.insetBy(dx: -3, dy: -3))
            if !visible.isNull && !visible.isEmpty {
                panel.contentView?.setNeedsDisplay(visible.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY))
            }
        }
    }
    func clear() {
        let old = system.bounds; system.reset(); invalidate(old); preview?.system.reset()
    }
    @objc func toggleEnabled() { settings.enabled.toggle(); settings.save(); applyEnabled() }
    func applyEnabled() {
        clear()
        if settings.enabled && !suspended {
            previousButtons = NSEvent.pressedMouseButtons
            panels.forEach { $0.orderFrontRegardless() }; startTimer(hz: 24)
        } else {
            timer?.invalidate(); timer = nil; timerHz = 0; panels.forEach { $0.orderOut(nil) }
        }
        enableButton?.title = settings.enabled ? "●  桌面效果已开启" : "开启桌面效果"
        buildStatusMenu(); preview?.needsDisplay = true
    }
    @objc func showCursorAppearance() { cursorAppearance?.show() }
    @objc func showSettings() { settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func chooseTheme(_ sender: ThemeButton) {
        if sender.theme == .custom && settings.customData == nil { importImage(); return }
        setTheme(sender.theme)
    }
    @objc func menuTheme(_ sender: NSMenuItem) { setTheme(TrailTheme(rawValue: sender.tag) ?? .stardust) }
    func setTheme(_ theme: TrailTheme) {
        clear(); settings.theme = theme; settings.save()
        themeButtons.forEach { $0.selected = $0.theme == theme }; buildStatusMenu()
    }
    @objc func parameterChanged(_ sender: NSSlider) {
        switch sender.tag {
        case 0: settings.size = sender.doubleValue
        case 1: settings.density = sender.doubleValue
        case 2: settings.lifetime = sender.doubleValue
        case 3: settings.twinkleSpeed = sender.doubleValue
        default: settings.opacity = sender.doubleValue
        }
        settings.save(); updateValues()
    }
    func updateValues() {
        let values = [settings.size, settings.density, settings.lifetime, settings.twinkleSpeed, settings.opacity]
        for i in sliders.indices {
            sliders[i].doubleValue = values[i]
            valueLabels[i].stringValue = i == 0 ? String(format: "%.0f", values[i]) : i == 1 ? String(format: "%.0f%%", values[i] * 100) : i == 2 ? String(format: "%.1f s", values[i]) : i == 3 ? String(format: "%.1f Hz", values[i]) : String(format: "%.0f%%", values[i] * 100)
        }
        burstButton.state = settings.clickBurst ? .on : .off
    }
    @objc func toggleBurst(_ sender: NSButton) { settings.clickBurst = sender.state == .on; settings.save() }
    @objc func toggleBackground(_ sender: NSButton) { preview.light.toggle(); sender.title = preview.light ? "深色背景" : "浅色背景"; preview.needsDisplay = true }
    @objc func resetParameters() {
        settings.size = 19; settings.density = 0.8; settings.lifetime = 1.25; settings.opacity = 0.88; settings.twinkleSpeed = 1.8; settings.clickBurst = true
        settings.save(); updateValues(); clear()
    }
    @objc func importImage() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = [.png, .jpeg, .tiff]
        picker.allowsMultipleSelection = false; picker.canChooseDirectories = false
        picker.message = "选择自己的小图案，透明背景 PNG 效果最好。"; picker.prompt = "用作粒子"
        picker.beginSheetModal(for: settingsWindow) { [weak self] result in
            guard let self, result == .OK, let url = picker.url else { return }
            do {
                let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
                guard bytes.count < 10_000_000, let image = NSImage(data: bytes), image.size.width > 0, image.size.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                let scale = 128 / max(image.size.width, image.size.height)
                let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: NSRect(x: (128 - size.width) / 2, y: (128 - size.height) / 2, width: size.width, height: size.height))
                NSGraphicsContext.restoreGraphicsState()
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileReadCorruptFile) }
                self.settings.customData = png; self.painter.loadCustom(png); self.setTheme(.custom)
            } catch {
                let alert = NSAlert(); alert.messageText = "这张图片暂时无法导入"
                alert.informativeText = "请选择小于 10 MB 的 PNG、JPEG 或 TIFF 图片。"; alert.beginSheetModal(for: self.settingsWindow)
            }
        }
    }
    func buildWindow() {
        settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        settingsWindow.title = "Luma Trail"; settingsWindow.isReleasedWhenClosed = false
        settingsWindow.titlebarAppearsTransparent = true; settingsWindow.backgroundColor = NSColor(hex: 0xF9F6F2)
        settingsWindow.appearance = NSAppearance(named: .aqua); settingsWindow.center()
        let root = Surface(frame: NSRect(x: 0, y: 0, width: 820, height: 650)); settingsWindow.contentView = root
        func put(_ view: NSView, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { view.frame = NSRect(x: x, y: y, width: w, height: h); root.addSubview(view) }
        put(label("Luma Trail", 30, .semibold), 28, 17, 400, 42)
        put(label("给每一次移动，添一点小小的魔法。", 13, .regular, NSColor(hex: 0x8B7F90)), 29, 65, 430, 21)
        put(label("选择心情", 12, .semibold), 29, 105, 240, 20)
        for (i, theme) in TrailTheme.allCases.enumerated() {
            let button = ThemeButton(theme: theme, target: self, action: #selector(chooseTheme(_:)))
            button.selected = settings.theme == theme; themeButtons.append(button)
            put(button, 28, CGFloat(135 + i * 82), 248, 72)
        }
        let importButton = NSButton(title: "导入自己的图片…", target: self, action: #selector(importImage))
        importButton.bezelStyle = .rounded; put(importButton, 42, 472, 220, 30)
        let cursorButton = NSButton(title: "鼠标外观与状态图片…", target: self, action: #selector(showCursorAppearance))
        cursorButton.bezelStyle = .rounded; put(cursorButton, 42, 547, 220, 30)
        put(label("透明 PNG 最佳 · 图片只保存在本机", 10, .regular, NSColor(hex: 0x938699)), 42, 509, 240, 20)
        preview = PreviewView(frame: .zero, settings: settings, painter: painter)
        put(preview, 306, 105, 486, 230)
        let background = NSButton(title: "浅色背景", target: self, action: #selector(toggleBackground(_:)))
        background.bezelStyle = .rounded; background.controlSize = .small; put(background, 699, 68, 94, 25)
        let names = ["粒子大小", "闪光密度", "消散时间", "闪烁速度", "不透明度"]
        let ranges: [(Double, Double)] = [(8, 42), (0.25, 1.8), (0.4, 2.5), (0.2, 4), (0.25, 1)]
        for i in 0..<5 {
            let y = CGFloat(356 + i * 37)
            put(label(names[i], 12), 308, y + 2, 84, 22)
            let slider = NSSlider(value: 0, minValue: ranges[i].0, maxValue: ranges[i].1, target: self, action: #selector(parameterChanged(_:)))
            slider.tag = i; slider.isContinuous = true; slider.setAccessibilityLabel(names[i]); sliders.append(slider)
            put(slider, 398, y, 328, 25)
            let value = label("", 11, .medium, NSColor(hex: 0x8A719B)); value.alignment = .right; valueLabels.append(value)
            put(value, 733, y + 3, 57, 20)
        }
        burstButton = NSButton(checkboxWithTitle: "点击时绽放一小簇", target: self, action: #selector(toggleBurst(_:)))
        burstButton.font = .systemFont(ofSize: 12); put(burstButton, 308, 549, 220, 24)
        let reset = NSButton(title: "恢复默认参数", target: self, action: #selector(resetParameters)); reset.bezelStyle = .rounded; reset.controlSize = .small
        put(reset, 668, 547, 124, 27)
        let line = NSBox(); line.boxType = .separator; put(line, 28, 590, 764, 1)
        shortcutLabel = label("⌘ ⇧ S  随时暂停 / 开启", 11, .regular, NSColor(hex: 0x8B7F90)); put(shortcutLabel, 29, 611, 325, 20)
        enableButton = NSButton(title: "", target: self, action: #selector(toggleEnabled))
        enableButton.bezelStyle = .rounded; enableButton.contentTintColor = NSColor(hex: 0x826197)
        put(enableButton, 565, 603, 157, 32)
        let quit = NSButton(title: "退出", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quit.bezelStyle = .rounded; put(quit, 735, 603, 59, 32)
        updateValues()
    }
}

if CommandLine.arguments.contains("--self-test") {
    runParticleTests(); runCursorTests()
} else if CommandLine.arguments.contains("--cursor-restore") {
    _ = NSApplication.shared
    print(CursorManager().restore() ? "Restored" : "Restore failed")
} else if CommandLine.arguments.contains("--cursor-probe") {
    cursorProbe()
} else if CommandLine.arguments.contains("--cursor-integration-test") {
    cursorIntegrationTest()
} else if let i = CommandLine.arguments.firstIndex(of: "--render-fixture"), CommandLine.arguments.count > i + 1 {
    try renderGlitterFixture(to: CommandLine.arguments[i + 1])
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
