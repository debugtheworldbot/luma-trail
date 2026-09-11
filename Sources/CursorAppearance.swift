import AppKit
import UniformTypeIdentifiers
import ImageIO

struct CursorKind {
    let id: String, title: String
    let keys: [String]
    let native: () -> NSCursor
    static let all: [CursorKind] = [
        .init(id: "arrow", title: "默认箭头", keys: ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"], native: { .arrow }),
        .init(id: "link", title: "链接 / 指向", keys: ["com.apple.cursor.13", "com.apple.cursor.2"], native: { .pointingHand }),
        .init(id: "text", title: "文本选择", keys: ["com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS", "com.apple.coregraphics.IBeamXOR", "com.apple.cursor.26"], native: { .iBeam }),
        .init(id: "cross", title: "精确选择", keys: ["com.apple.cursor.7", "com.apple.cursor.8"], native: { .crosshair }),
        .init(id: "open", title: "可抓取", keys: ["com.apple.cursor.12"], native: { .openHand }),
        .init(id: "closed", title: "抓取中", keys: ["com.apple.cursor.11"], native: { .closedHand }),
        .init(id: "horizontal", title: "水平缩放", keys: ["com.apple.cursor.19", "com.apple.cursor.28"], native: { .resizeLeftRight }),
        .init(id: "vertical", title: "垂直缩放", keys: ["com.apple.cursor.23", "com.apple.cursor.32"], native: { .resizeUpDown }),
        .init(id: "forbidden", title: "不可用", keys: ["com.apple.cursor.3"], native: { .operationNotAllowed })
    ]
}
struct CursorAsset: Codable {
    var png: Data?
    var width: Double = 32
    var x: Double = 0.08
    var y: Double = 0.08
}
struct CursorTheme: Codable {
    var assets: [String: CursorAsset] = [:]
    var tint = false
    var red = 0.94, green = 0.34, blue = 0.66
    var color: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}
// Hotspots are normalized top-left coordinates. Rasterization preserves aspect and alpha.
func cursorRaster(_ image: NSImage, tint: NSColor?, maxPixels: Int = 128) -> Data? {
    guard image.size.width > 0, image.size.height > 0 else { return nil }
    let scale = Double(maxPixels) / max(image.size.width, image.size.height)
    let w = max(1, Int((image.size.width * scale).rounded()))
    let h = max(1, Int((image.size.height * scale).rounded()))
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
    if let tint { tint.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill(using: .sourceAtop) }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}
final class CursorManager {
    var theme: CursorTheme
    var active = false
    var originals: [String: NSDictionary] = [:]
    let defaults = UserDefaults.standard
    let nativeImages: [String: NSCursor]
    init() {
        nativeImages = Dictionary(uniqueKeysWithValues: CursorKind.all.map { ($0.id, $0.native()) })
        theme = defaults.data(forKey: "cursorTheme.v1").flatMap { try? JSONDecoder().decode(CursorTheme.self, from: $0) } ?? CursorTheme()
        if let data = defaults.data(forKey: "cursorRecovery.v1"), let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: NSDictionary] { originals = dict }
    }
    func save() { if let data = try? JSONEncoder().encode(theme) { defaults.set(data, forKey: "cursorTheme.v1") } }
    func image(for kind: CursorKind) -> NSImage {
        if let data = theme.assets[kind.id]?.png, let image = NSImage(data: data) { return image }
        return nativeImages[kind.id]!.image
    }
    func asset(for kind: CursorKind) -> CursorAsset {
        if let asset = theme.assets[kind.id] { return asset }
        let cursor = nativeImages[kind.id]!
        return CursorAsset(width: max(cursor.image.size.width, cursor.image.size.height), x: cursor.hotSpot.x / cursor.image.size.width, y: cursor.hotSpot.y / cursor.image.size.height)
    }
    func snapshot(for kind: CursorKind) -> NSDictionary? {
        let asset = self.asset(for: kind), source = image(for: kind)
        guard let png = cursorRaster(source, tint: theme.tint ? theme.color : nil) else { return nil }
        let longest = min(64, max(16, asset.width))
        let w = longest * source.size.width / max(source.size.width, source.size.height)
        let h = longest * source.size.height / max(source.size.width, source.size.height)
        return ["images": [png], "width": w, "height": h, "x": min(w - 0.5, max(0, asset.x * w)), "y": min(h - 0.5, max(0, asset.y * h)), "frames": 1, "duration": 0.0]
    }
    // Persist originals before changing WindowServer, so the next launch can recover after a crash.
    func persistRecovery() {
        if originals.isEmpty { defaults.removeObject(forKey: "cursorRecovery.v1") }
        else if let data = try? PropertyListSerialization.data(fromPropertyList: originals, format: .binary, options: 0) { defaults.set(data, forKey: "cursorRecovery.v1") }
        defaults.synchronize()
    }
    @discardableResult func restore() -> Bool {
        var failed: [String: NSDictionary] = [:]
        for (key, value) in originals {
            if LTCursorRegister(key, value as! [AnyHashable: Any]) != 0 { failed[key] = value }
        }
        originals = failed; persistRecovery(); active = !failed.isEmpty
        return failed.isEmpty
    }
    func apply(persistTheme: Bool = true) -> String {
        guard LTCursorAvailable() else { return "此系统不支持鼠标替换接口，拖影仍可使用。" }
        guard restore() else { return "原鼠标恢复失败，请先重试“恢复原鼠标”。" }
        // AppKit lazily registers some cursor resources on first use.
        for kind in CursorKind.all { kind.native().set() }
        NSCursor.arrow.set()
        var plan: [(String, NSDictionary)] = [], missing: [String] = []
        for kind in CursorKind.all where theme.assets[kind.id] != nil || theme.tint {
            guard let replacement = snapshot(for: kind) else { continue }
            var count = 0
            for key in kind.keys {
                if let original = LTCursorSnapshot(key), LTCursorCanRestore(original) {
                    originals[key] = original as NSDictionary; plan.append((key, replacement)); count += 1
                }
            }
            if count == 0 { missing.append(kind.title) }
        }
        guard !plan.isEmpty else { return missing.isEmpty ? "请先导入图片，或开启统一染色。" : "当前系统未提供这些状态：" + missing.joined(separator: "、") }
        persistRecovery()
        for (key, snapshot) in plan {
            if LTCursorRegister(key, snapshot as! [AnyHashable: Any]) != 0 {
                let recovered = restore()
                return recovered ? "应用失败，已恢复原鼠标。" : "应用失败，部分状态未恢复，请点击恢复原鼠标重试。"
            }
        }
        active = true; if persistTheme { save() }
        return "已应用 \(plan.count) 个系统状态" + (missing.isEmpty ? "。移到其他窗口试试看。" : "；未支持：" + missing.joined(separator: "、"))
    }
}

final class CursorCanvas: NSView {
    var cursorImage: NSImage?
    var hotspot = CGPoint(x: 0.08, y: 0.08)
    var onHotspot: ((CGPoint) -> Void)?
    override var isFlipped: Bool { true }
    var imageRect: CGRect {
        let size = cursorImage?.size ?? CGSize(width: 1, height: 1)
        let scale = min((bounds.width - 64) / size.width, (bounds.height - 44) / size.height)
        return CGRect(x: (bounds.width - size.width * scale) / 2, y: (bounds.height - size.height * scale) / 2, width: size.width * scale, height: size.height * scale)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(hex: 0xE9E3EC).setFill(); bounds.fill()
        for x in stride(from: 0, to: Int(bounds.width), by: 14) { for y in stride(from: 0, to: Int(bounds.height), by: 14) where (x/14+y/14)%2 == 0 { NSColor.white.withAlphaComponent(0.5).setFill(); NSRect(x:x,y:y,width:14,height:14).fill() } }
        cursorImage?.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        let p = CGPoint(x: imageRect.minX + hotspot.x * imageRect.width, y: imageRect.minY + hotspot.y * imageRect.height)
        let cross = NSBezierPath(); cross.move(to: NSPoint(x:p.x-9,y:p.y)); cross.line(to: NSPoint(x:p.x+9,y:p.y)); cross.move(to:NSPoint(x:p.x,y:p.y-9)); cross.line(to:NSPoint(x:p.x,y:p.y+9))
        NSColor.white.setStroke(); cross.lineWidth = 3; cross.stroke(); NSColor.systemPink.setStroke(); cross.lineWidth = 1; cross.stroke()
    }
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from:nil), rect = imageRect
        guard rect.contains(p) else { return }
        hotspot = CGPoint(x: min(1,max(0,(p.x-rect.minX)/rect.width)), y: min(1,max(0,(p.y-rect.minY)/rect.height)))
        onHotspot?(hotspot); needsDisplay = true
    }
}
final class CursorWindowController: NSObject {
    let manager = CursorManager()
    var window: NSWindow!
    var picker: NSPopUpButton!
    var canvas: CursorCanvas!
    var color: NSColorWell!
    var tint: NSButton!
    var size: NSSlider!
    var sizeLabel: NSTextField!
    var note: NSTextField!
    var status: NSTextField!
    var selected: CursorKind { CursorKind.all[picker.indexOfSelectedItem] }
    override init() { super.init(); _ = manager.restore() }
    @objc func show() {
        if window == nil { build() }
        refresh(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func build() {
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:690,height:590),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "鼠标外观 · Luma Trail"; window.isReleasedWhenClosed = false; window.center()
        let surface = Surface(frame:NSRect(x:0,y:0,width:690,height:590)); window.contentView = surface
        func put(_ v:NSView,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat) { v.frame = NSRect(x:x,y:y,width:w,height:h); surface.addSubview(v) }
        func button(_ title:String,_ action:Selector,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat) { let b = NSButton(title:title,target:self,action:action); b.bezelStyle = .rounded; put(b,x,y,w,30) }
        put(label("让鼠标也有自己的风格",23,.semibold),28,24,600,32)
        put(label("为每种状态选择图片，或给系统鼠标换个颜色。",12),28,65,610,24)
        picker = NSPopUpButton(); picker.addItems(withTitles:CursorKind.all.map(\.title)); picker.target = self; picker.action = #selector(selectionChanged); put(picker,28,109,250,32)
        canvas = CursorCanvas(); put(canvas,28,154,250,234)
        canvas.onHotspot = { [weak self] p in guard let self else {return}; var a = self.manager.asset(for:self.selected); a.x = p.x; a.y = p.y; self.manager.theme.assets[self.selected.id] = a; self.changed(); self.refresh() }
        put(label("点击预览设置热点（真正的点击位置）",11),28,398,270,22)
        note = label("",11); put(note,28,426,280,42); note.maximumNumberOfLines = 2
        button("导入当前状态图片…",#selector(importResource),314,109,220)
        button("清除当前状态设置",#selector(clearResource),314,150,220)
        put(label("支持透明 PNG、JPEG、TIFF，单张 ≤ 10 MB。",11),314,190,350,20)
        put(label("未设置的保持原样；系统彩色等待球暂不支持。",11),314,213,350,20)
        tint = NSButton(checkboxWithTitle:"统一染色（关闭则保留图片原色）",target:self,action:#selector(colorChanged)); put(tint,314,259,350,25)
        color = NSColorWell(); color.target = self; color.action = #selector(colorChanged); put(color,316,299,60,32)
        put(label("鼠标颜色",12),391,305,130,22)
        put(label("当前状态大小",12),314,357,150,22)
        size = NSSlider(value:32,minValue:16,maxValue:64,target:self,action:#selector(sizeChanged)); size.isContinuous = true; size.setAccessibilityLabel("鼠标大小"); put(size,314,387,270,26)
        sizeLabel = label("",12); put(sizeLabel,591,391,70,22)
        status = label("修改后点击应用。退出应用时自动恢复原鼠标。",11); status.maximumNumberOfLines = 3; put(status,28,475,632,48)
        button("恢复原鼠标",#selector(restore),28,538,150)
        button("应用鼠标外观",#selector(apply),483,538,178)
    }
    func refresh() {
        let a = manager.asset(for:selected)
        let image = manager.image(for:selected)
        canvas.cursorImage = cursorRaster(image,tint:manager.theme.tint ? manager.theme.color : nil).flatMap(NSImage.init(data:))
        canvas.hotspot = CGPoint(x:a.x,y:a.y); canvas.needsDisplay = true
        tint.state = manager.theme.tint ? .on : .off; color.color = manager.theme.color
        size.doubleValue = min(64,max(16,a.width)); sizeLabel.stringValue = String(format:"%.0f pt",size.doubleValue)
        note.stringValue = (a.png == nil ? "当前：系统形状" : "当前：自定义图片") + String(format:"\n热点：左侧 %.0f%% · 顶部 %.0f%%",a.x*100,a.y*100)
    }
    func changed() { manager.save(); status.stringValue = "修改已保存，点击“应用鼠标外观”生效。" }
    @objc func selectionChanged() { refresh() }
    @objc func colorChanged() {
        let c = color.color.usingColorSpace(.sRGB) ?? .systemPink
        manager.theme.tint = tint.state == .on; manager.theme.red = c.redComponent; manager.theme.green = c.greenComponent; manager.theme.blue = c.blueComponent
        changed(); refresh()
    }
    @objc func sizeChanged() { var a = manager.asset(for:selected); a.width = size.doubleValue; manager.theme.assets[selected.id] = a; changed(); refresh() }
    @objc func clearResource() { manager.theme.assets.removeValue(forKey:selected.id); changed(); refresh() }
    @objc func apply() { status.stringValue = manager.apply() }
    @objc func restore() { status.stringValue = manager.restore() ? "已恢复原鼠标。上传的图片和颜色设置仍保留。" : "恢复失败，请重试；若仍失败，请注销后重新登录。" }
    @objc func importResource() {
        let target = selected.id
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png,.jpeg,.tiff]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.message = "给“\(selected.title)”选择静态鼠标图片，建议透明 PNG。"; panel.prompt = "导入鼠标"
        panel.beginSheetModal(for:window) { [weak self] result in
            guard let self, result == .OK, let url = panel.url else {return}
            do {
                let metadata = try url.resourceValues(forKeys:[.fileSizeKey])
                guard (metadata.fileSize ?? Int.max) <= 10_000_000 else { throw CocoaError(.fileReadTooLarge) }
                let data = try Data(contentsOf:url)
                guard let source = CGImageSourceCreateWithData(data as CFData,nil), CGImageSourceGetCount(source) == 1,
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:512,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary),
                      let png = cursorRaster(NSImage(cgImage:thumbnail,size:NSSize(width:thumbnail.width,height:thumbnail.height)),tint:nil,maxPixels:256) else { throw CocoaError(.fileReadCorruptFile) }
                self.manager.theme.assets[target] = CursorAsset(png:png,width:32,x:0.08,y:0.08)
                self.changed(); self.refresh()
                self.status.stringValue = "图片已导入。请点击预览设置热点，再应用鼠标外观。"
            } catch { self.status.stringValue = "导入失败：请选择 10 MB 内的静态 PNG、JPEG 或 TIFF 图片。" }
        }
    }
}

func runCursorTests() {
    let image = NSImage(size:NSSize(width:40,height:20),flipped:false) { rect in NSColor.blue.setFill(); rect.insetBy(dx:3,dy:3).fill(); return true }
    let data = cursorRaster(image,tint:.systemPink)!
    let rep = NSBitmapImageRep(data:data)!
    precondition(rep.pixelsWide == 128 && rep.pixelsHigh == 64)
    precondition(rep.colorAt(x:0,y:0)!.alphaComponent == 0)
    let middle = rep.colorAt(x:64,y:32)!.usingColorSpace(.sRGB)!
    precondition(middle.redComponent > 0.8 && middle.blueComponent > 0.2)
    var theme = CursorTheme(); theme.assets["link"] = CursorAsset(png:data,width:45,x:0.4,y:0.2)
    let decoded = try! JSONDecoder().decode(CursorTheme.self,from:JSONEncoder().encode(theme))
    precondition(decoded.assets["link"]?.png == data && decoded.assets["link"]?.width == 45 && decoded.assets["arrow"] == nil)
    print("Cursor tests passed: alpha, aspect ratio, tint, per-state persistence.")
}
func cursorProbe() {
    _ = NSApplication.shared
    print("Cursor API available: \(LTCursorAvailable())")
    for kind in CursorKind.all {
        _ = kind.native().image
        for key in kind.keys {
            if let snapshot = LTCursorSnapshot(key) { print("\(key): \(snapshot["width"]!) × \(snapshot["height"]!), frames \(snapshot["frames"]!)") }
            else { print("\(key): unavailable") }
        }
    }
}
func cursorIntegrationTest() {
    _ = NSApplication.shared
    let manager = CursorManager()
    guard manager.originals.isEmpty else { print("SKIP: an existing theme is active; restore it first."); return }
    for kind in CursorKind.all { kind.native().set() }; NSCursor.arrow.set()
    let keys = CursorKind.all.flatMap(\.keys)
    let before = keys.compactMap { key -> (String, NSDictionary)? in LTCursorSnapshot(key).map { (key,$0 as NSDictionary) } }
    print("Captured originals: \(before.count)")
    precondition(!before.isEmpty)
    manager.theme = CursorTheme(); manager.theme.assets["arrow"] = CursorAsset(width:43,x:0.25,y:0.3)
    manager.theme.tint = true
    // Verify every supported state and restore before reporting failures.
    manager.theme.tint = false
    let custom = NSImage(size:NSSize(width:32,height:32),flipped:false) { rect in NSColor.systemPink.setFill(); NSBezierPath(ovalIn:rect.insetBy(dx:4,dy:4)).fill(); return true }
    for kind in CursorKind.all { manager.theme.assets[kind.id] = CursorAsset(png:cursorRaster(custom,tint:nil),width:43,x:0.25,y:0.3) }
    defer { _ = manager.restore() }
    print(manager.apply(persistTheme:false))
    guard manager.active else { print("FAIL: not applied"); return }
    var errors: [String] = []
    for (key,_) in before {
        guard let current = LTCursorSnapshot(key) else { errors.append("Missing " + key); continue }
        if (current["width"] as! NSNumber).doubleValue != 43 { errors.append("Size " + key) }
        if abs((current["x"] as! NSNumber).doubleValue - 10.75) > 0.1 { errors.append("Hotspot " + key) }
    }
    let restored = manager.restore()
    for (key,snapshot) in before {
        guard let current = LTCursorSnapshot(key) else { errors.append("Restore missing " + key); continue }
        for field in ["width","height","x","y","frames","duration","images"] {
            if !(current[field] as! NSObject).isEqual(snapshot[field]) { errors.append("Restore mismatch " + key + " " + field) }
        }
    }
    print("Restored: \(restored); \(before.count) states; errors: \(errors)")
    if !restored || !errors.isEmpty { exit(1) }
}
