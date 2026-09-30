import AppKit
import Carbon
import QuartzCore
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
    // dirtyRect can extend past bounds now that views no longer clip by default.
    override func draw(_ dirtyRect: NSRect) { AquaStyle.background.setFill(); dirtyRect.intersection(bounds).fill() }
}

final class AquaWindowButton: NSButton {
    enum Glyph { case close, minimize, zoom }
    let tint: NSColor
    let border: NSColor
    let glyph: Glyph
    // Like native traffic lights, hovering any button reveals the glyphs of the whole group.
    var showsGlyph = false { didSet { if showsGlyph != oldValue { needsDisplay = true } } }
    init(tint: NSColor, border: NSColor? = nil, glyph: Glyph, title: String, target: AnyObject?, action: Selector?) {
        self.tint = tint; self.border = border ?? tint.blended(withFraction: 0.45, of: .black)!; self.glyph = glyph
        super.init(frame: .zero)
        self.title = ""; self.target = target; self.action = action
        isBordered = false; setAccessibilityLabel(title); toolTip = title
    }
    required init?(coder: NSCoder) { fatalError() }
    private var group: [AquaWindowButton] { superview?.subviews.compactMap { $0 as? AquaWindowButton } ?? [self] }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { group.forEach { $0.showsGlyph = true } }
    override func mouseExited(with event: NSEvent) {
        guard let superview else { return }
        let point = superview.convert(event.locationInWindow, from: nil)
        if !group.contains(where: { $0.frame.contains(point) }) { group.forEach { $0.showsGlyph = false } }
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // The window may close or miniaturize without delivering mouseExited.
        group.forEach { $0.showsGlyph = false }
    }
    override func draw(_ dirtyRect: NSRect) {
        let d = dp(18), rect = NSRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)
        let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
        let top = tint.blended(withFraction: isHighlighted ? 0.3 : 0.12, of: border)!
        NSGradient(colors: [tint.blended(withFraction: 0.25, of: .white)!, tint, top])?.draw(in: circle, angle: 90)
        border.setStroke(); circle.lineWidth = 1; circle.stroke()
        let gleam = NSBezierPath(ovalIn: NSRect(x: rect.midX - d * 0.28, y: rect.midY + d * 0.06, width: d * 0.56, height: d * 0.36))
        NSGradient(starting: .white.withAlphaComponent(0.1), ending: .white.withAlphaComponent(0.9))?.draw(in: gleam, angle: 90)
        if showsGlyph { drawGlyph(in: rect) }
    }
    private func drawGlyph(in rect: NSRect) {
        let color = border.blended(withFraction: 0.35, of: .black)!.withAlphaComponent(isEnabled ? 0.85 : 0.5)
        // All glyphs share one extent so they read at the same size.
        let h = rect.width * 0.25, c = NSPoint(x: rect.midX, y: rect.midY)
        let path = NSBezierPath(); path.lineWidth = max(1.1, rect.width * 0.1); path.lineCapStyle = .round
        switch glyph {
        case .close:
            let r = h * 0.75
            path.move(to: NSPoint(x: c.x - r, y: c.y - r)); path.line(to: NSPoint(x: c.x + r, y: c.y + r))
            path.move(to: NSPoint(x: c.x - r, y: c.y + r)); path.line(to: NSPoint(x: c.x + r, y: c.y - r))
            color.setStroke(); path.stroke()
        case .minimize:
            path.move(to: NSPoint(x: c.x - h * 0.8, y: c.y)); path.line(to: NSPoint(x: c.x + h * 0.8, y: c.y))
            color.setStroke(); path.stroke()
        case .zoom:
            // Two opposing triangles toward the top-left and bottom-right, as in the native full-screen glyph.
            let up: CGFloat = isFlipped ? -1 : 1, s = h * 1.15
            for sign: CGFloat in [1, -1] {
                let corner = NSPoint(x: c.x - sign * h, y: c.y + sign * up * h)
                let tri = NSBezierPath()
                tri.move(to: corner)
                tri.line(to: NSPoint(x: corner.x + sign * s, y: corner.y))
                tri.line(to: NSPoint(x: corner.x, y: corner.y - sign * up * s))
                tri.close()
                color.setFill(); tri.fill()
            }
        }
    }
}

final class AquaTitlebar: NSView {
    var title = "Luma Trail"
    var symbol: String?
    override func draw(_ dirtyRect: NSRect) {
        AquaStyle.gradient([0xFEFEFE, 0xF7F5F6, 0xEFEBED], [0, 0.5, 1]).draw(in: bounds, angle: -90)
        AquaStyle.line.setFill(); NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: AquaStyle.ink]
        let text = title as NSString, size = text.size(withAttributes: attributes)
        let icon = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 10, weight: .regular)) }
        let iconWidth = icon.map { $0.size.width + 4 } ?? 0
        let x = (bounds.width - size.width - iconWidth) / 2, y = (bounds.height - size.height) / 2 + 0.5
        if let icon {
            let tinted = NSImage(size: icon.size, flipped: false) { rect in
                icon.draw(in: rect); AquaStyle.ink.set(); rect.fill(using: .sourceAtop); return true
            }
            tinted.draw(in: NSRect(x: x, y: bounds.midY - icon.size.height / 2 + 0.5, width: icon.size.width, height: icon.size.height))
        }
        text.draw(at: NSPoint(x: x + iconWidth, y: y), withAttributes: attributes)
    }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

// Banner artwork comes from the design; the rim and corners are drawn to stay crisp.
final class BannerView: NSView {
    let image = NSImage(named: "SettingsBanner")
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 11, yRadius: 11)
        NSGraphicsContext.saveGraphicsState(); path.addClip()
        if let image { image.draw(in: bounds) } else { AquaStyle.gradient([0xE8E8FD, 0xFDF3FA], [0, 1]).draw(in: bounds, angle: 0) }
        NSGraphicsContext.restoreGraphicsState()
        AquaStyle.line.setStroke(); path.lineWidth = 1; path.stroke()
    }
}

final class ThemeBoard: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor.white.setFill(); dirtyRect.intersection(bounds).fill() }
}

func label(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular,
           _ color: NSColor = AquaStyle.ink) -> NSTextField {
    let v = NSTextField(labelWithString: text)
    v.font = .systemFont(ofSize: size, weight: weight); v.textColor = color
    return v
}

final class ThemeRow: NSButton {
    static let height = dp(80)
    override var isFlipped: Bool { false }
    let theme: TrailTheme
    var selected = false { didSet { needsDisplay = true } }
    var starTint: NSColor? { didSet { needsDisplay = true } }
    init(theme: TrailTheme, target: AnyObject, action: Selector) {
        self.theme = theme
        super.init(frame: .zero)
        self.target = target; self.action = action; title = theme.title
        setAccessibilityLabel(theme.title); isBordered = false
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        if selected || isHighlighted { NSColor(hex: selected ? 0xFFF3F9 : 0xFFF8FB).setFill(); bounds.fill() }
        let thumb = NSRect(x: dp(20), y: bounds.height - dp(69), width: dp(60), height: dp(60))
        NSColor(hex: 0xFFE7F3).setFill(); thumb.fill()
        let art = thumb.insetBy(dx: dp(7), dy: dp(7))
        if theme == .custom || theme == .mixed {
            let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular).applying(.init(paletteColors: [NSColor(hex: 0xD0679F)]))
            if let symbol = NSImage(systemSymbolName: theme.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                symbol.draw(in: NSRect(x: art.midX - symbol.size.width / 2, y: art.midY - symbol.size.height / 2, width: symbol.size.width, height: symbol.size.height))
            }
        } else {
            let swatch = theme.colors(tinted: starTint)[0]
            NSImage(cgImage: ParticlePainter.texture(theme: theme, color: swatch), size: NSSize(width: 128, height: 128)).draw(in: art)
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(hex: 0x574A50)]
        let text = theme.title as NSString, size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: dp(101), y: bounds.midY - size.height / 2 - 0.5), withAttributes: attributes)
        let heart = AquaStyle.heart(in: NSRect(x: dp(319), y: bounds.midY - dp(9), width: dp(20), height: dp(18)).insetBy(dx: 0.5, dy: 0.5))
        heart.lineJoinStyle = .round
        if selected {
            AquaStyle.jelly(heart, rim: NSColor(hex: 0xB65D89))
        } else {
            NSColor(hex: 0xF7F5F6).setFill(); heart.fill()
            NSColor(hex: 0xE2DADF).setStroke(); heart.lineWidth = 1; heart.stroke()
        }
    }
}

// Classic Aqua scroller: arrow caps, a recessed slot and a pink jelly thumb.
final class AquaScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { false }
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat { dp(19) }
    private var slot: NSRect { NSRect(x: 0, y: dp(23), width: bounds.width, height: max(0, bounds.height - dp(23) - dp(23))) }
    override func rect(for part: NSScroller.Part) -> NSRect {
        switch part {
        case .knobSlot: return slot
        case .knob:
            guard knobProportion > 0, knobProportion < 1, isEnabled else { return .zero }
            let length = max(dp(60), slot.height * knobProportion)
            return NSRect(x: slot.minX, y: slot.minY + (slot.height - length) * doubleValue, width: slot.width, height: length)
        default: return super.rect(for: part)
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        AquaStyle.line.setFill(); NSRect(x: 0, y: 0, width: dp(1), height: bounds.height).fill()
        let track = NSBezierPath(roundedRect: slot.insetBy(dx: 1, dy: -0.5).offsetBy(dx: 0.5, dy: 0), xRadius: slot.width / 2 - 1, yRadius: slot.width / 2 - 1)
        NSColor(hex: 0xF7F6F6).setFill(); track.fill()
        AquaStyle.line.setStroke(); track.lineWidth = 1; track.stroke()
        AquaStyle.soft.setFill()
        let mid = bounds.midX + dp(0.5), w = dp(9), h = dp(8)
        for (tip, base) in [(dp(9), dp(9) + h), (bounds.height - dp(8), bounds.height - dp(8) - h)] {
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: mid, y: tip)); arrow.line(to: NSPoint(x: mid + w / 2, y: base)); arrow.line(to: NSPoint(x: mid - w / 2, y: base))
            arrow.close(); arrow.fill()
        }
        drawKnob()
    }
    override func drawKnob() {
        let rect = self.rect(for: .knob)
        guard !rect.isEmpty else { return }
        let r = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: r, xRadius: r.width / 2, yRadius: r.width / 2)
        AquaStyle.gradient([0xDF74A9, 0xFFE3F1, 0xFFC6E2, 0xFFB6DB, 0xFFD2E8, 0xDEB2C7], [0, 0.12, 0.3, 0.48, 0.75, 1]).draw(in: path, angle: 0)
        AquaStyle.pinkRim.setStroke(); path.lineWidth = 1; path.stroke()
    }
}

// Flat translucent pill; its own layer keeps the 30 Hz preview from redrawing the text.
final class FlatPill: NSButton {
    init(title: String, symbol: String, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.title = title; self.target = target; self.action = action
        isBordered = false; wantsLayer = true; setAccessibilityLabel(title)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 8.5, weight: .regular))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor(hex: 0xEFEBED).withAlphaComponent(isHighlighted ? 1 : 0.94).setFill(); path.fill()
        if isHighlighted { NSColor(hex: 0x6B4A5B).withAlphaComponent(0.08).setFill(); path.fill() }
        if let image {
            let tinted = NSImage(size: image.size, flipped: false) { rect in
                image.draw(in: rect); AquaStyle.soft.set(); rect.fill(using: .sourceAtop); return true
            }
            tinted.draw(in: NSRect(x: dp(20), y: bounds.midY - image.size.height / 2, width: image.size.width, height: image.size.height))
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: AquaStyle.soft]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: dp(46), y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}

// Status line that doubles as the on/off switch for the desktop overlay.
final class StatusButton: NSButton {
    var on = true { didSet { title = on ? "桌面效果已开启" : "桌面效果已暂停"; needsDisplay = true } }
    init(target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.target = target; self.action = action; isBordered = false; title = "桌面效果已开启"
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: isHighlighted ? AquaStyle.pinkRim : AquaStyle.soft]
        let text = title as NSString, size = text.size(withAttributes: attributes)
        let x = bounds.maxX - size.width - 2
        text.draw(at: NSPoint(x: x, y: bounds.midY - size.height / 2), withAttributes: attributes)
        let d = dp(16), dot = NSBezierPath(ovalIn: NSRect(x: x - dp(11) - d, y: bounds.midY - d / 2, width: d, height: d).insetBy(dx: 0.5, dy: 0.5))
        if on { NSColor(hex: 0xFFBADC).setFill(); dot.fill(); AquaStyle.pinkRim.setStroke() }
        else { NSColor(hex: 0xEDE9EB).setFill(); dot.fill(); AquaStyle.rim.setStroke() }
        dot.lineWidth = 1; dot.stroke()
    }
}

// One tuning parameter: name, live value, pink Aqua slider and tick marks, in design units.
final class SliderCard: NSView {
    let slider: NSSlider
    let value = label("", 12)
    init(frame: NSRect, name: String, range: (Double, Double), tag: Int, target: AnyObject, action: Selector) {
        slider = NSSlider(value: range.0, minValue: range.0, maxValue: range.1, target: target, action: action)
        super.init(frame: frame)
        slider.tag = tag; slider.isContinuous = true; slider.setAccessibilityLabel(name)
        slider.frame = NSRect(x: dp(20), y: dp(50), width: frame.width - dp(40), height: AquaSliderCell.knob.height)
        let title = label(name, 12)
        place(title, x: 21, centerY: 27)
        value.alignment = .right
        place(value, x: frame.width * 1.5 - 22, centerY: 32, trailing: true, width: 80)
        [title, value, slider].forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        NSColor.white.setFill(); path.fill()
        NSColor(hex: 0xE2DBDF).setStroke(); path.lineWidth = 1; path.stroke()
        NSColor(hex: 0xE2DBDF).setFill()
        let first = dp(22), span = bounds.width - dp(44)
        for i in 0...8 { NSRect(x: (first + span * CGFloat(i) / 8).rounded(), y: dp(77), width: 1, height: dp(3)).fill() }
    }
}

final class PreviewView: NSView {
    let settings: TrailSettings
    let painter: ParticlePainter
    let system = ParticleSystem()
    var light = true { didSet { needsDisplay = true } }
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
        system.tick(at: t, cursor: point, settings: settings)
        needsDisplay = true
    }
    // Pink arrow in points, tip first, y growing downwards from the hotspot.
    static let arrow: [CGPoint] = [(0, 0), (0, 16.4), (3.9, 12.8), (6.5, 18.6), (9, 17.6), (6.5, 11.8), (11.6, 11.8)].map { CGPoint(x: $0.0, y: $0.1) }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        NSGraphicsContext.saveGraphicsState()
        // Only the bottom corners are rounded; the panel header sits above.
        let r: CGFloat = 6.5, clip = NSBezierPath()
        clip.move(to: NSPoint(x: 0, y: bounds.maxY)); clip.line(to: NSPoint(x: 0, y: r))
        clip.appendArc(withCenter: NSPoint(x: r, y: r), radius: r, startAngle: 180, endAngle: 270)
        clip.appendArc(withCenter: NSPoint(x: bounds.maxX - r, y: r), radius: r, startAngle: 270, endAngle: 360)
        clip.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY)); clip.close(); clip.addClip()
        // Pinstripes brighten towards pink at the bottom, like the classic Aqua window fill.
        (light ? NSColor(hex: 0xF7F5F6) : NSColor(hex: 0x2A1F28)).setFill(); bounds.fill()
        let topStripe = light ? NSColor(hex: 0xFFFDFE) : NSColor(hex: 0x33263A)
        let bottomStripe = light ? NSColor(hex: 0xFFF1F8) : NSColor(hex: 0x40283A)
        for y in stride(from: bounds.height - 1.5, through: -1.5, by: -3) {
            topStripe.blended(withFraction: 1 - y / bounds.height, of: bottomStripe)!.setFill()
            NSRect(x: 0, y: y, width: bounds.width, height: 1.5).fill()
        }
        painter.draw(system.particles, in: ctx, at: ProcessInfo.processInfo.systemUptime, twinkleSpeed: settings.twinkleSpeed)
        let arrow = NSBezierPath()
        for (i, p) in Self.arrow.enumerated() {
            let q = NSPoint(x: point.x + p.x * 1.15, y: point.y - p.y * 1.15)
            if i == 0 { arrow.move(to: q) } else { arrow.line(to: q) }
        }
        arrow.close(); arrow.lineJoinStyle = .round; arrow.lineWidth = 1.2
        NSColor(hex: 0xFF7DBE).setFill(); NSColor(hex: 0xFF7DBE).setStroke(); arrow.fill(); arrow.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    enum SettingsTab { case trail, cursor }
    let appUpdater = AppUpdater()
    var updateCheckButton: NSButton?
    var automaticUpdateButton: NSButton?
    var cursorAppearance: CursorAppearanceController?
    let folderIcons = FolderIconWindowController()
    let settings = TrailSettings()
    let system = ParticleSystem()
    let painter = ParticlePainter()
    var panels: [OverlayPanel] = []
    var timer: Timer?
    var previewTimer: Timer?
    var timerHz = 0.0
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow!
    var settingsContent: NSView!
    var trailContent: NSView!
    var settingsTabs: [NSButton] = []
    var selectedSettingsTab = SettingsTab.trail
    var preview: PreviewView!
    var themeButtons: [ThemeRow] = []
    var sliders: [NSSlider] = []
    var valueLabels: [NSTextField] = []
    var enableButton: StatusButton!
    var burstButton: NSButton!
    var starColorToggle: NSButton!
    var starColorWell: NSColorWell!
    var hotKey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    var suspended = false
    var previousButtons = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: "showInDock") ? .regular : .accessory)
        // Bring the existing instance forward rather than doubling all overlays.
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: "studio.luma.trail.mvp").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
        }
        cursorAppearance = CursorAppearanceController()
        _ = cursorAppearance?.manager.restore()
        painter.loadCustom(settings.customData)
        buildMainMenu(); buildWindow(); buildStatusMenu(); buildOverlays(); configureHotkey()
        appUpdater.onChange = { [weak self] in self?.refreshUpdateUI() }
        appUpdater.start()
        folderIcons.startWatching()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(suspend), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(suspend), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(resume), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(resume), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        applyEnabled(); showSettings()
        previewTimer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, self.settingsWindow.isVisible, self.selectedSettingsTab == .trail, !self.suspended else { return }
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
        appMenu.addItem(appUpdater.makeMenuItem())
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
        for theme in TrailTheme.displayOrder where theme != .custom || settings.customData != nil {
            let item = NSMenuItem(title: theme.title, action: #selector(menuTheme(_:)), keyEquivalent: "")
            item.target = self; item.tag = theme.rawValue; item.state = settings.theme == theme ? .on : .off; menu.addItem(item)
        }
        menu.addItem(.separator())
        let preferences = NSMenuItem(title: "打开设置…", action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self; menu.addItem(preferences)
        menu.addItem(NSMenuItem(title: "退出 Luma Trail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let cursorItem = NSMenuItem(title: "鼠标外观…", action: #selector(showCursorAppearance), keyEquivalent: "")
        cursorItem.target = self; menu.insertItem(cursorItem, at: menu.items.count - 1)
        let folderItem = NSMenuItem(title: "文件夹图标…", action: #selector(showFolderIcons), keyEquivalent: "")
        folderItem.target = self; menu.insertItem(folderItem, at: menu.items.count - 1)
        menu.insertItem(appUpdater.makeMenuItem(), at: menu.items.count - 1)
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
        enableButton.toolTip = status == noErr ? "点击或按 ⌘ ⇧ S 随时暂停 / 开启" : "快捷键被占用，请点击这里或从菜单栏暂停"
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
        enableButton?.on = settings.enabled
        buildStatusMenu(); preview?.needsDisplay = true
    }
    @objc func showCursorAppearance() { selectSettingsTab(.cursor); showSettings() }
    @objc func showTrailEffects() { selectSettingsTab(.trail) }
    func selectSettingsTab(_ tab: SettingsTab, animated: Bool = true) {
        guard tab != selectedSettingsTab else { return }
        if tab == .cursor {
            if cursorAppearance == nil { cursorAppearance = CursorAppearanceController() }
            if cursorAppearance?.view == nil {
                let view = cursorAppearance!.buildView(size: settingsContent.bounds.size)
                view.wantsLayer = true; view.isHidden = true
                settingsContent.addSubview(view)
            }
        }
        guard let cursorContent = cursorAppearance?.view else { return }
        let incoming = tab == .trail ? trailContent! : cursorContent
        settingsWindow.makeFirstResponder(nil)
        if starColorWell.isActive { starColorWell.deactivate() }
        if let color = cursorAppearance?.color, color.isActive { color.deactivate() }
        settingsContent.layer?.removeAnimation(forKey: "tabTransition")
        for view in [trailContent!, cursorContent] { view.layer?.removeAnimation(forKey: "tabSlide") }
        let shouldAnimate = animated && settingsWindow.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            let fade = CATransition()
            fade.type = .fade; fade.duration = 0.26
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            settingsContent.layer?.add(fade, forKey: "tabTransition")
        }
        selectedSettingsTab = tab
        trailContent.isHidden = tab != .trail
        cursorContent.isHidden = tab != .cursor
        for (index, button) in settingsTabs.enumerated() {
            let selected = index == (tab == .trail ? 0 : 1)
            button.state = selected ? .on : .off
            (button.cell as? AquaButtonCell)?.pink = selected
            button.needsDisplay = true
        }
        if shouldAnimate {
            let slide = CABasicAnimation(keyPath: "transform.translation.x")
            slide.fromValue = tab == .cursor ? 14.0 : -14.0; slide.toValue = 0
            slide.duration = 0.26
            slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
            incoming.layer?.add(slide, forKey: "tabSlide")
        }
    }
    @objc func showFolderIcons() { folderIcons.show() }
    @objc func showSettings() { settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func chooseTheme(_ sender: ThemeRow) {
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
        starColorToggle?.state = settings.starTintEnabled ? .on : .off
        starColorWell?.color = NSColor(srgbRed: settings.starRed, green: settings.starGreen, blue: settings.starBlue, alpha: 1)
    }
    func applyStarTint() {
        painter.applyStarTint(settings.starTint)
        let tint = settings.starTint
        themeButtons.forEach { $0.starTint = tint }
        preview?.needsDisplay = true
    }
    @objc func toggleStarColor(_ sender: NSButton) {
        if sender.state == .on { settings.setStarTint(starColorWell.color) } else { settings.starTintEnabled = false }
        settings.save(); applyStarTint()
    }
    @objc func starColorChanged() {
        settings.setStarTint(starColorWell.color)
        starColorToggle.state = .on
        settings.save(); applyStarTint()
    }
    @objc func toggleDockVisibility(_ sender: NSButton) {
        let showInDock = sender.state == .on
        guard NSApp.setActivationPolicy(showInDock ? .regular : .accessory) else {
            sender.state = NSApp.activationPolicy() == .regular ? .on : .off
            return
        }
        UserDefaults.standard.set(showInDock, forKey: "showInDock")
        // Switching activation policy can change focus; keep the settings accessible.
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }
    @objc func toggleBurst(_ sender: NSButton) { settings.clickBurst = sender.state == .on; settings.save() }
    @objc func toggleBackground(_ sender: NSButton) { preview.light.toggle() }
    @objc func resetParameters() {
        settings.resetTuning()
        settings.save(); updateValues(); applyStarTint(); clear()
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
    func refreshUpdateUI() {
        updateCheckButton?.isEnabled = appUpdater.canCheckForUpdates
        updateCheckButton?.title = appUpdater.availableVersion == nil ? "检查更新…" : "查看更新…"
        automaticUpdateButton?.state = appUpdater.automaticallyChecks ? .on : .off
    }

    func buildWindow() {
        // Every frame below quotes the 1.5× design mockup, whose window starts at (99, 74).
        let size = NSSize(width: dp(1341), height: dp(1182))
        settingsWindow = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        settingsWindow.title = "Luma Trail"; settingsWindow.isReleasedWhenClosed = false
        settingsWindow.center()
        let root = Surface(frame: NSRect(origin: .zero, size: size))
        settingsWindow.contentView = root
        var container: NSView = root
        var contentOrigin = NSPoint.zero
        func frame(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: dp(x - 99) - contentOrigin.x, y: dp(y - 74) - contentOrigin.y, width: dp(w), height: dp(h)) }
        func put(_ view: NSView, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { view.frame = frame(x, y, w, h); container.addSubview(view) }
        func text(_ field: NSTextField, _ x: CGFloat, _ centerY: CGFloat) {
            place(field, x: x - 99, centerY: centerY - 74)
            field.frame.origin.x -= contentOrigin.x; field.frame.origin.y -= contentOrigin.y
            container.addSubview(field)
        }

        AquaStyle.installWindowChrome(in: settingsWindow, title: "给鼠标加一点魔法", symbol: "heart")
        put(BannerView(), 120, 136, 1300, 140)
        let dragTab = NSButton(title: "拖动效果", target: self, action: #selector(showTrailEffects))
        dragTab.identifier = NSUserInterfaceItemIdentifier("aquaTabOn")
        dragTab.state = .on
        let cursorTab = NSButton(title: "鼠标美化", target: self, action: #selector(showCursorAppearance))
        cursorTab.identifier = NSUserInterfaceItemIdentifier("aquaTab")
        for (i, tab) in [dragTab, cursorTab].enumerated() { tab.font = .systemFont(ofSize: 13); put(tab, 600 + CGFloat(i) * 180, 296, 160, 45) }
        settingsTabs = [dragTab, cursorTab]
        settingsContent = Surface(frame: frame(120, 360, 1300, 830))
        settingsContent.wantsLayer = true; settingsContent.layer?.masksToBounds = true
        root.addSubview(settingsContent)
        trailContent = Surface(frame: settingsContent.bounds)
        trailContent.wantsLayer = true
        settingsContent.addSubview(trailContent)
        container = trailContent; contentOrigin = settingsContent.frame.origin

        // Effect library.
        put(AquaGroup(title: "效果库"), 120, 360, 380, 828)
        let themes = TrailTheme.displayOrder
        let board = ThemeBoard(frame: NSRect(x: 0, y: 0, width: dp(359), height: CGFloat(themes.count) * ThemeRow.height))
        for (i, theme) in themes.enumerated() {
            let row = ThemeRow(theme: theme, target: self, action: #selector(chooseTheme(_:)))
            row.selected = settings.theme == theme; themeButtons.append(row)
            row.toolTip = theme.subtitle
            row.frame = NSRect(x: 0, y: CGFloat(i) * ThemeRow.height, width: board.frame.width, height: ThemeRow.height)
            board.addSubview(row)
        }
        let scroller = NSScrollView(frame: .zero)
        scroller.verticalScroller = AquaScroller()
        scroller.scrollerStyle = .legacy; scroller.hasVerticalScroller = true; scroller.autohidesScrollers = false
        scroller.borderType = .noBorder; scroller.backgroundColor = .white; scroller.documentView = board
        put(scroller, 121, 402, 378, 659)
        let divider = NSBox(); divider.boxType = .custom; divider.borderWidth = 0; divider.fillColor = AquaStyle.line
        put(divider, 121, 1061, 378, 1)
        let importButton = NSButton(title: "导入自定义图片…", target: self, action: #selector(importImage))
        importButton.font = .systemFont(ofSize: 12); put(importButton, 140, 1091, 340, 41)
        let caption = label("透明 PNG 最佳 · 图片只存在本机", 9, .regular, AquaStyle.soft)
        caption.sizeToFit(); text(caption, 310 - caption.frame.width * 0.75, 1149)

        // Live preview.
        put(AquaGroup(title: "效果预览"), 520, 360, 900, 330)
        preview = PreviewView(frame: .zero, settings: settings, painter: painter)
        put(preview, 521, 402, 898, 287)
        put(FlatPill(title: "切换背景", symbol: "arrow.triangle.2.circlepath", target: self, action: #selector(toggleBackground(_:))), 550, 421, 120, 40)

        // Tuning cards: two per row, the fifth spanning the panel.
        put(AquaGroup(title: "效果调节"), 520, 709, 900, 481)
        let names = ["粒子大小", "闪光密度", "消散时间", "闪烁速度", "不透明度"]
        let ranges: [(Double, Double)] = [(8, 42), (0.25, 1.8), (0.4, 2.5), (0.2, 4), (0.25, 1)]
        for i in 0..<5 {
            let rect = frame(540 + CGFloat(i % 2) * 440, 771 + CGFloat(i / 2) * 120, i == 4 ? 860 : 420, 100)
            let card = SliderCard(frame: rect, name: names[i], range: ranges[i], tag: i, target: self, action: #selector(parameterChanged(_:)))
            sliders.append(card.slider); valueLabels.append(card.value); container.addSubview(card)
        }
        let reset = NSButton(title: "恢复默认", target: self, action: #selector(resetParameters))
        reset.font = .systemFont(ofSize: 12); put(reset, 540, 1131, 132, 41)
        starColorToggle = NSButton(checkboxWithTitle: "自定义星星颜色", target: self, action: #selector(toggleStarColor(_:)))
        starColorToggle.identifier = NSUserInterfaceItemIdentifier("aquaCheckbox")
        starColorToggle.font = .systemFont(ofSize: 12)
        starColorToggle.toolTip = "只改变星星：仙女星尘、银河星环、香槟仙尘、月牙星语、暖光火花。"
        put(starColorToggle, 688, 1136, 248, 28)
        starColorWell = NSColorWell()
        starColorWell.target = self; starColorWell.action = #selector(starColorChanged)
        starColorWell.toolTip = starColorToggle.toolTip
        put(starColorWell, 948, 1128, 64, 44)
        burstButton = NSButton(checkboxWithTitle: "点击绽放效果", target: self, action: #selector(toggleBurst(_:)))
        burstButton.identifier = NSUserInterfaceItemIdentifier("aquaCheckbox")
        burstButton.font = .systemFont(ofSize: 12); put(burstButton, 1259.5, 1136, 142, 28)

        // Single-row footer: Dock, version, update controls and effects.
        container = root; contentOrigin = .zero
        let versionLabel = label(appUpdater.currentVersion, 11)
        let automaticUpdates = NSButton(checkboxWithTitle: "自动检查更新", target: appUpdater, action: #selector(AppUpdater.toggleAutomaticChecks(_:)))
        automaticUpdates.identifier = NSUserInterfaceItemIdentifier("aquaCheckbox")
        automaticUpdates.font = .systemFont(ofSize: 11)
        automaticUpdateButton = automaticUpdates
        let checkUpdates = NSButton(title: "检查更新…", target: appUpdater, action: #selector(AppUpdater.checkForUpdates(_:)))
        checkUpdates.font = .systemFont(ofSize: 12)
        updateCheckButton = checkUpdates
        let updateControls = NSStackView(views: [versionLabel, automaticUpdates, checkUpdates])
        updateControls.orientation = .horizontal
        updateControls.alignment = .centerY
        updateControls.spacing = dp(12)
        updateControls.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(updateControls)
        NSLayoutConstraint.activate([
            updateControls.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: dp(344 - 99)),
            updateControls.centerYAnchor.constraint(equalTo: root.topAnchor, constant: dp(1222 - 74)),
            checkUpdates.widthAnchor.constraint(equalToConstant: dp(150)),
            checkUpdates.heightAnchor.constraint(equalToConstant: dp(41))
        ])
        refreshUpdateUI()

        let dockButton = NSButton(checkboxWithTitle: "在 Dock 中显示", target: self, action: #selector(toggleDockVisibility(_:)))
        dockButton.identifier = NSUserInterfaceItemIdentifier("aquaCheckbox")
        dockButton.font = .systemFont(ofSize: 12)
        dockButton.state = UserDefaults.standard.bool(forKey: "showInDock") ? .on : .off
        put(dockButton, 139.5, 1207, 180, 28)
        enableButton = StatusButton(target: self, action: #selector(toggleEnabled))
        enableButton.on = settings.enabled
        put(enableButton, 1230, 1207, 172, 30)
        AquaStyle.install(in: root)
        updateValues(); applyStarTint()
        if let selected = themeButtons.first(where: \.selected) { board.scrollToVisible(selected.frame.insetBy(dx: 0, dy: -ThemeRow.height)) }
    }
}

// Exercise the real AppKit display loop, including autorelease-pool turnover.
// Uses isolated settings and never installs overlays or changes the system cursor.
func runPreviewStressTest() {
    _ = NSApplication.shared
    let settings = TrailSettings()
    let preview = PreviewView(frame: NSRect(x: 0, y: 0, width: 486, height: 230), settings: settings, painter: ParticlePainter())
    let window = NSWindow(contentRect: preview.bounds, styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = preview
    window.orderFrontRegardless()
    let start = ProcessInfo.processInfo.systemUptime
    for frame in 0..<7200 {
        autoreleasepool {
            if frame % 120 == 0 {
                preview.light.toggle()
                settings.enabled = (frame / 120) % 3 != 0
                settings.theme = TrailTheme.displayOrder[(frame / 120) % TrailTheme.displayOrder.count]
            }
            preview.step()
            precondition(preview.bounds.insetBy(dx: -1, dy: -1).contains(preview.point))
            preview.display()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0 / 240))
        }
        if frame % 1200 == 1199 { print("Preview stress: \(frame + 1) frames"); fflush(stdout) }
    }
    window.orderOut(nil)
    print("PASS: 7200 preview frames, light/dark, pause/resume and every theme in \(Int(ProcessInfo.processInfo.systemUptime - start)) seconds")
}

if CommandLine.arguments.contains("--preview-stress-test") {
    runPreviewStressTest()
} else if let i = CommandLine.arguments.firstIndex(of: "--render-settings"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    let delegate = AppDelegate(); delegate.buildWindow()
    if CommandLine.arguments.contains("--cursor-tab") { delegate.selectSettingsTab(.cursor, animated: false) }
    delegate.preview.step()
    let view = delegate.settingsWindow.contentView!
    view.display()
    if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    }
} else if let i = CommandLine.arguments.firstIndex(of: "--render-folder-icons"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    let controller = FolderIconWindowController()
    if CommandLine.arguments.contains("--split") { controller.options.splitEmpty = true }
    controller.build()
    let view = controller.window.contentView!
    if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    }
} else if CommandLine.arguments.contains("--self-test") {
    runParticleTests(); runCursorTests(); runFolderIconTests()
} else if CommandLine.arguments.contains("--cursor-restore") {
    _ = NSApplication.shared
    print(CursorManager().restore() ? "Restored" : "Restore failed")
} else if CommandLine.arguments.contains("--cursor-probe") {
    cursorProbe()
} else if CommandLine.arguments.contains("--cursor-integration-test") {
    cursorIntegrationTest()
} else if let i = CommandLine.arguments.firstIndex(of: "--render-ink"), CommandLine.arguments.count > i + 1 {
    try renderInkFixture(to: CommandLine.arguments[i + 1])
} else if let i = CommandLine.arguments.firstIndex(of: "--render-rainbow"), CommandLine.arguments.count > i + 1 {
    try renderRainbowFixture(to: CommandLine.arguments[i + 1])
} else if let i = CommandLine.arguments.firstIndex(of: "--render-themes"), CommandLine.arguments.count > i + 1 {
    try renderCuteThemeSheet(to: CommandLine.arguments[i + 1])
} else if let i = CommandLine.arguments.firstIndex(of: "--render-fixture"), CommandLine.arguments.count > i + 1 {
    try renderGlitterFixture(to: CommandLine.arguments[i + 1])
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
