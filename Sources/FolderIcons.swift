import AppKit
import UniformTypeIdentifiers

// Raw values follow Finder's tag color numbers stored in _kMDItemUserTags.
enum FinderColor: Int, CaseIterable {
    case gray = 1, green, purple, blue, yellow, red, orange
    static let displayOrder: [FinderColor] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
    var key: String { ["", "gray", "green", "purple", "blue", "yellow", "red", "orange"][rawValue] }
    var title: String { ["", "灰色", "绿色", "紫色", "蓝色", "黄色", "红色", "橙色"][rawValue] }
    var tint: NSColor { NSColor(hex: [0, 0x9A9A9E, 0x5CB85C, 0xA56BD1, 0x3E8EDE, 0xF2C94C, 0xE5534B, 0xF0963A][rawValue]) }
}

struct FolderIconOptions: Codable, Equatable {
    var root: String?
    var subfolders = true
    var splitEmpty = false
    var includeRoot = false
    static func load() -> FolderIconOptions {
        UserDefaults.standard.data(forKey: "folderIcons.v1").flatMap { try? JSONDecoder().decode(FolderIconOptions.self, from: $0) } ?? FolderIconOptions()
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "folderIcons.v1") } }
}

// Slots never fall back to another color or state; a missing slot means native.
// Folders without a colored tag use the "none" slot.
func folderSlot(_ color: FinderColor?, empty: Bool, split: Bool) -> String {
    let key = color?.key ?? "none"
    return split ? key + (empty ? ".empty" : ".full") : key
}
func folderSlotTitle(_ slot: String) -> String {
    let parts = slot.split(separator: ".").map(String.init)
    let color = parts[0] == "none" ? "无标签" : FinderColor.allCases.first { $0.key == parts[0] }?.title ?? parts[0]
    return parts.count == 1 ? color + "图标" : color + (parts[1] == "empty" ? " · 空文件夹图标" : " · 有内容图标")
}

final class FolderIconLibrary {
    let directory: URL
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Luma Trail/FolderIcons", isDirectory: true)) {
        self.directory = directory
    }
    func file(_ slot: String) -> URL { directory.appendingPathComponent(slot + ".png") }
    var configured: Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".png") }.map { String($0.dropLast(4)) })
    }
    func image(_ slot: String) -> NSImage? { NSImage(contentsOf: file(slot)) }
    // Copy into a square 1024 PNG so later edits to the original never matter.
    func importImage(from url: URL, slot: String) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 20_000_000, let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { throw CocoaError(.fileReadCorruptFile) }
        let scale = 1024 / max(image.size.width, image.size.height)
        let w = image.size.width * scale, h = image.size.height * scale
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        image.draw(in: NSRect(x: (1024 - w) / 2, y: (1024 - h) / 2, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: file(slot), options: .atomic)
    }
    func remove(_ slot: String) { try? FileManager.default.removeItem(at: file(slot)) }
}

enum FolderInspector {
    static func xattr(_ path: String, _ name: String) -> Data? {
        let size = getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, XATTR_NOFOLLOW) }
        return read > 0 ? data.prefix(read) : nil
    }
    // Either the kHasCustomIcon Finder flag or an Icon\r file counts, whoever set it.
    static func hasCustomIcon(_ url: URL) -> Bool {
        if let info = xattr(url.path, "com.apple.FinderInfo"), info.count >= 10,
           (UInt16(info[info.startIndex + 8]) << 8 | UInt16(info[info.startIndex + 9])) & 0x0400 != 0 { return true }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("Icon\r").path)
    }
    // The first colored tag in Finder order wins; custom tag names count by color.
    static func finderColor(_ url: URL) -> FinderColor? {
        if let data = xattr(url.path, "com.apple.metadata:_kMDItemUserTags"),
           let tags = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            for tag in tags {
                if let number = tag.split(separator: "\n").last.flatMap({ Int($0) }), tag.contains("\n"), let color = FinderColor(rawValue: number) { return color }
            }
            return nil
        }
        return (try? url.resourceValues(forKeys: [.labelNumberKey]).labelNumber).flatMap { FinderColor(rawValue: $0) }
    }
    // Finder-visible children: hidden and dot files (.DS_Store, .git…) and Icon\r are ignored.
    static func visibleChildren(_ url: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isHiddenKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .volumeIdentifierKey]
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
            .filter { child in
                let name = child.lastPathComponent
                return !name.hasPrefix(".") && name != "Icon\r" && (try? child.resourceValues(forKeys: [.isHiddenKey]).isHidden) != true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    static var defaultExcluded: [String] {
        ["/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/private", "/etc", "/var", "/tmp", "/opt", "/cores", "/dev",
         FileManager.default.homeDirectoryForCurrentUser.path + "/Library"]
    }
    static func excluded(_ path: String, prefixes: [String]) -> Bool {
        path == "/" || path == "/Volumes" || prefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
    static func rootProblem(_ url: URL) -> String? {
        let path = url.resolvingSymlinksInPath().path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return "所选文件夹不存在，请重新选择。" }
        if excluded(path, prefixes: defaultExcluded) { return "为了安全，不能处理系统目录或资源库文件夹。" }
        return nil
    }
}

enum FolderAction: Equatable {
    case apply(String), keepCustom, noTag, noIcon, failed(String)
    var resultText: String {
        switch self {
        case .apply(let slot): return folderSlotTitle(slot)
        case .keepCustom: return "保留"
        case .noTag, .noIcon: return "保持原生"
        case .failed(let reason): return "无法处理：" + reason
        }
    }
}
enum FolderOutcome: Equatable {
    case applied, kept, native, failed(String), skipped
    var text: String {
        switch self {
        case .applied: return "已修改"
        case .kept: return "已保留"
        case .native: return "保持原生"
        case .failed(let reason): return "无法处理：" + reason
        case .skipped: return "未执行（已停止）"
        }
    }
}
struct FolderItem {
    let url: URL
    let name: String
    var color: FinderColor?
    var empty: Bool?
    var action: FolderAction
    var identity: NSObject?
    var outcome: FolderOutcome?
    func stateText(split: Bool) -> String {
        if action == .keepCustom { return "已有自定义图标" }
        guard empty != nil else { return "—" }
        let base = "原生 + " + (color?.title ?? "无标签")
        return split ? base + (empty! ? " · 空" : " · 有内容") : base
    }
}

final class CancelToken {
    private let lock = NSLock(); private var flag = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func cancel() { lock.lock(); flag = true; lock.unlock() }
}

// Scanning is pure Foundation and may run off the main thread; applying stays on main.
final class FolderIconEngine {
    let library: FolderIconLibrary
    var excludedPrefixes = FolderInspector.defaultExcluded
    init(library: FolderIconLibrary) { self.library = library }

    func evaluate(_ url: URL, listing: Result<[URL], Error>, options: FolderIconOptions, configured: Set<String>) -> (FinderColor?, Bool?, FolderAction) {
        let color = FolderInspector.finderColor(url)
        if FolderInspector.hasCustomIcon(url) { return (color, nil, .keepCustom) }
        guard case .success(let children) = listing else { return (color, nil, .failed("无法读取，可能没有权限")) }
        let empty = children.isEmpty
        let slot = folderSlot(color, empty: empty, split: options.splitEmpty)
        return (color, empty, configured.contains(slot) ? .apply(slot) : color == nil ? .noTag : .noIcon)
    }
    func traversable(_ url: URL, volume: NSObject?) -> Bool {
        guard let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .volumeIdentifierKey]),
              v.isDirectory == true, v.isSymbolicLink != true, v.isPackage != true else { return false }
        if let volume, let other = v.volumeIdentifier as? NSObject, !volume.isEqual(other) { return false }
        return !FolderInspector.excluded(url.path, prefixes: excludedPrefixes)
    }
    func scan(root: URL, options: FolderIconOptions, cancel: CancelToken = CancelToken(), progress: (Int) -> Void = { _ in }) -> [FolderItem] {
        let root = root.standardizedFileURL, configured = library.configured
        let volume = (try? root.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
        // Names are built during traversal; path arithmetic breaks on /var vs /private/var.
        var items: [FolderItem] = [], stack: [(URL, Int, String)] = [(root, 0, "")]
        while let (dir, depth, relative) = stack.popLast(), !cancel.isCancelled {
            let listing = Result { try FolderInspector.visibleChildren(dir) }
            if depth > 0 || options.includeRoot {
                let (color, empty, action) = evaluate(dir, listing: listing, options: options, configured: configured)
                let identity = (try? dir.resourceValues(forKeys: [.fileResourceIdentifierKey]))?.fileResourceIdentifier as? NSObject
                let name = depth == 0 ? root.lastPathComponent + "（当前文件夹）" : relative
                items.append(FolderItem(url: dir, name: name, color: color, empty: empty, action: action, identity: identity))
                if items.count % 200 == 0 { progress(items.count) }
            }
            guard case .success(let children) = listing else {
                if depth == 0 && !options.includeRoot { items.append(FolderItem(url: dir, name: root.lastPathComponent + "（当前文件夹）", action: .failed("无法读取当前文件夹，可能没有权限"))) }
                continue
            }
            if depth == 0 || options.subfolders {
                for child in children.reversed() where traversable(child, volume: volume) { stack.append((child, depth + 1, depth == 0 ? child.lastPathComponent : relative + "/" + child.lastPathComponent)) }
            }
        }
        return items
    }
    func inside(_ url: URL, root: URL, includeRoot: Bool) -> Bool {
        let path = url.resolvingSymlinksInPath().path, base = root.resolvingSymlinksInPath().path
        return path == base ? includeRoot : path.hasPrefix(base + "/")
    }
    // Every folder is re-checked right before writing; any drift from the preview is reported, not applied.
    func execute(_ item: inout FolderItem, root: URL, options: FolderIconOptions, images: inout [String: NSImage]) {
        guard case .apply(let slot) = item.action else {
            switch item.action {
            case .keepCustom: item.outcome = .kept
            case .failed(let reason): item.outcome = .failed(reason)
            default: item.outcome = .native
            }
            return
        }
        func fail(_ reason: String) { item.outcome = .failed(reason) }
        // A fresh URL avoids resource values cached during the scan.
        let url = URL(fileURLWithPath: item.url.path, isDirectory: true)
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileResourceIdentifierKey]),
              values.isDirectory == true else { return fail("预览后已被删除或移动") }
        guard values.isSymbolicLink != true, item.identity.map({ $0.isEqual(values.fileResourceIdentifier) }) ?? true else { return fail("预览后已被移动或替换") }
        guard inside(item.url, root: root, includeRoot: options.includeRoot), !FolderInspector.excluded(item.url.path, prefixes: excludedPrefixes) else { return fail("已不在处理范围内") }
        let listing = Result { try FolderInspector.visibleChildren(item.url) }
        let now = evaluate(item.url, listing: listing, options: options, configured: library.configured).2
        guard now == item.action else { return fail("预览后状态已变化（" + (now == .keepCustom ? "已有自定义图标" : now.resultText) + "）") }
        guard FileManager.default.isWritableFile(atPath: item.url.path) else { return fail("没有写入权限") }
        if images[slot] == nil { images[slot] = library.image(slot) }
        guard let image = images[slot] else { return fail("图标素材已被删除") }
        guard NSWorkspace.shared.setIcon(image, forFile: item.url.path, options: []), FolderInspector.hasCustomIcon(item.url) else { return fail("写入失败，可能没有权限") }
        item.outcome = .applied
    }
    // Kept for a future undo: which folders changed, to which slot, and why others did not.
    func record(_ items: [FolderItem], root: URL) {
        struct Entry: Codable { let path: String; let slot: String?; let result: String }
        struct Record: Codable { let date: Date; let root: String; let items: [Entry] }
        let entries = items.map { item -> Entry in
            var slot: String?; if case .apply(let s) = item.action { slot = s }
            return Entry(path: item.url.path, slot: slot, result: item.outcome?.text ?? "")
        }
        let folder = library.directory.deletingLastPathComponent().appendingPathComponent("FolderIconHistory", isDirectory: true)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"
        guard let data = try? JSONEncoder().encode(Record(date: Date(), root: root.path, items: entries)) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent(formatter.string(from: Date()) + ".json"), options: .atomic)
    }
}

final class SlotWell: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        NSColor.white.withAlphaComponent(0.7).setFill(); path.fill()
        NSColor(hex: 0x9AAAB8).setStroke(); path.stroke()
        let icon = image ?? NSWorkspace.shared.icon(for: .folder)
        icon.draw(in: bounds.insetBy(dx: 4, dy: 4), from: .zero, operation: .sourceOver, fraction: image == nil ? 0.35 : 1, respectFlipped: true, hints: nil)
    }
    override func mouseDown(with event: NSEvent) { onClick?() }
}

final class FolderIconWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let library = FolderIconLibrary()
    lazy var engine = FolderIconEngine(library: library)
    var options = FolderIconOptions.load()
    var window: NSWindow!
    var pathLabel: NSTextField!
    var checks: [NSButton] = []
    var iconArea: AquaGroup!
    var status: NSTextField!
    var previewButton: NSButton!
    // Preview / result sheet
    var sheet: NSWindow!
    var sheetTitle: NSTextField!
    var summary: NSTextField!
    var table: NSTableView!
    var progress: NSProgressIndicator!
    var leftButton: NSButton!
    var rightButton: NSButton!
    var items: [FolderItem] = []
    var rows: [Int] = []
    var root: URL?
    var token = CancelToken()
    var phase = "scan"

    @objc func show() {
        if window == nil { build() }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func build() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 700), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.title = "文件夹图标 · Luma Trail"; window.isReleasedWhenClosed = false; window.center()
        window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        let content = Surface(frame: NSRect(x: 0, y: 0, width: 760, height: 700)); window.contentView = content
        let header = AquaTitlebar(frame: NSRect(x: 0, y: 0, width: 760, height: 40)); content.addSubview(header)
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] { window.standardWindowButton(kind)?.isHidden = true }
        for (index, item) in [(0xE85B52, "关闭", #selector(NSWindow.performClose(_:))), (0xEAB936, "最小化", #selector(NSWindow.performMiniaturize(_:)))].enumerated() {
            let button = AquaWindowButton(tint: NSColor(hex: item.0), glyph: index == 0 ? .close : .minimize, title: item.1, target: window, action: item.2)
            button.frame = NSRect(x: 12 + CGFloat(index) * 28, y: 7, width: 28, height: 26); header.addSubview(button)
        }
        let surface = Surface(frame: NSRect(x: 0, y: 40, width: 760, height: 660)); content.addSubview(surface)
        func put(_ v: NSView, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { v.frame = NSRect(x: x, y: y, width: w, height: h); surface.addSubview(v) }
        let muted = NSColor(hex: 0x526D82)
        put(label("文件夹图标", 23, .semibold), 28, 20, 500, 32)
        put(label("按 Finder 标签颜色批量更换图标，已有自定义图标的文件夹始终保留。", 12, .regular, muted), 28, 58, 640, 22)
        put(AquaGroup(), 18, 92, 724, 150)
        put(label("处理文件夹", 12, .semibold), 30, 102, 200, 20)
        pathLabel = label("", 12); pathLabel.lineBreakMode = .byTruncatingMiddle; put(pathLabel, 30, 127, 560, 20)
        let choose = NSButton(title: "选择文件夹…", target: self, action: #selector(chooseRoot)); choose.bezelStyle = .rounded; put(choose, 600, 120, 130, 30)
        let items: [(String, String)] = [("处理子文件夹", "包含所有层级的子文件夹"), ("区分空文件夹", "分别设置空文件夹和有内容的文件夹图标"), ("处理当前文件夹", "同时修改当前选择的文件夹")]
        for (i, item) in items.enumerated() {
            let check = NSButton(checkboxWithTitle: item.0, target: self, action: #selector(optionChanged(_:)))
            check.identifier = NSUserInterfaceItemIdentifier("aquaCheckbox"); check.font = .systemFont(ofSize: 12); check.tag = i
            checks.append(check); put(check, 30 + CGFloat(i) * 240, 156, 230, 24)
            put(label(item.1, 10, .regular, muted), 53 + CGFloat(i) * 240, 180, 210, 16)
        }
        let keep = NSButton(checkboxWithTitle: "保留已有自定义图标", target: nil, action: nil)
        keep.identifier = NSUserInterfaceItemIdentifier("aquaCheckbox"); keep.font = .systemFont(ofSize: 12); keep.state = .on
        put(keep, 30, 207, 200, 24)
        put(label("始终开启：已有自定义图标的文件夹一律跳过", 10, .regular, muted), 234, 211, 400, 16)
        iconArea = AquaGroup(); put(iconArea, 18, 252, 724, 346)
        status = label("", 11, .regular, muted); status.maximumNumberOfLines = 2; put(status, 28, 610, 560, 36)
        previewButton = NSButton(title: "预览", target: self, action: #selector(startPreview)); previewButton.bezelStyle = .rounded
        put(previewButton, 620, 612, 120, 32)
        AquaStyle.install(in: surface)
        keep.isEnabled = false
        refresh()
    }
    func refresh() {
        pathLabel.stringValue = options.root ?? "尚未选择"
        checks[0].state = options.subfolders ? .on : .off
        checks[1].state = options.splitEmpty ? .on : .off
        checks[2].state = options.includeRoot ? .on : .off
        previewButton.isEnabled = options.root != nil
        if options.root == nil { status.stringValue = "先选择一个文件夹。未设置图标的颜色保持 macOS 原生图标。" }
        else if !options.subfolders && !options.includeRoot { status.stringValue = "关闭“处理子文件夹”时只处理第一层子文件夹。" }
        else { status.stringValue = "设置好图标后点击“预览”，确认后才会修改。" }
        buildIcons()
    }
    func buildIcons() {
        iconArea.subviews.forEach { $0.removeFromSuperview() }
        let flipped = FlippedView(frame: iconArea.bounds); iconArea.addSubview(flipped)
        func add(_ v: NSView, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { v.frame = NSRect(x: x, y: y, width: w, height: h); flipped.addSubview(v) }
        let muted = NSColor(hex: 0x526D82)
        add(label("图标", 12, .semibold), 12, 10, 60, 20)
        add(label("未设置的组合保持原生图标，不会借用其他颜色或状态的图标。", 10, .regular, muted), 60, 13, 400, 16)
        let columns: [(String?, CGFloat)] = options.splitEmpty ? [(".empty", 112), (".full", 412)] : [(nil, 112)]
        if options.splitEmpty {
            add(label("空文件夹", 11, .medium, muted), 112, 32, 120, 16)
            add(label("有内容", 11, .medium, muted), 412, 32, 120, 16)
        }
        let configured = library.configured
        let colors: [FinderColor?] = FinderColor.displayOrder + [nil]
        for (row, color) in colors.enumerated() {
            let y = 50 + CGFloat(row) * 36
            let dot = ColorDot(frame: .zero); dot.color = color?.tint; add(dot, 14, y + 9, 14, 14)
            add(label(color.map { $0.title + "标签" } ?? "无标签", 12), 34, y + 7, 76, 20)
            for (suffix, x) in columns {
                let slot = folderSlot(color, empty: suffix == ".empty", split: suffix != nil)
                let well = SlotWell(); well.image = configured.contains(slot) ? library.image(slot) : nil
                well.toolTip = "上传" + folderSlotTitle(slot); well.onClick = { [weak self] in self?.upload(slot) }
                add(well, x, y, 32, 32)
                let upload = SlotButton(title: "上传…", target: self, action: #selector(uploadClicked(_:))); upload.slot = slot; upload.bezelStyle = .rounded
                add(upload, x + 44, y + 2, 80, 28)
                let clear = SlotButton(title: "清除", target: self, action: #selector(clearClicked(_:))); clear.slot = slot; clear.bezelStyle = .rounded
                add(clear, x + 128, y + 2, 64, 28)
                add(label(configured.contains(slot) ? "已设置" : "原生", 10, .regular, muted), x + 198, y + 9, 80, 16)
            }
        }
        AquaStyle.install(in: flipped)
        // Cell replacement resets enabled state, so apply it afterwards.
        for case let clear as SlotButton in flipped.subviews where clear.title == "清除" { clear.isEnabled = configured.contains(clear.slot) }
    }
    @objc func optionChanged(_ sender: NSButton) {
        let on = sender.state == .on
        switch sender.tag { case 0: options.subfolders = on; case 1: options.splitEmpty = on; default: options.includeRoot = on }
        options.save(); refresh()
    }
    @objc func chooseRoot() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false; panel.prompt = "选择"; panel.message = "选择要处理的文件夹"
        if let root = options.root { panel.directoryURL = URL(fileURLWithPath: root) }
        panel.beginSheetModal(for: window) { [weak self] result in
            guard let self, result == .OK, let url = panel.url else { return }
            if let problem = FolderInspector.rootProblem(url) { self.status.stringValue = problem; return }
            self.options.root = url.standardizedFileURL.path; self.options.save(); self.refresh()
        }
    }
    @objc func uploadClicked(_ sender: SlotButton) { upload(sender.slot) }
    @objc func clearClicked(_ sender: SlotButton) { library.remove(sender.slot); buildIcons() }
    func upload(_ slot: String) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .icns]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.message = "为“\(folderSlotTitle(slot))”选择图片，透明背景 PNG 或 ICNS 效果最好。"; panel.prompt = "上传"
        panel.beginSheetModal(for: window) { [weak self] result in
            guard let self, result == .OK, let url = panel.url else { return }
            do { try self.library.importImage(from: url, slot: slot); self.status.stringValue = "已设置" + folderSlotTitle(slot) + "。" }
            catch { self.status.stringValue = "上传失败：请选择 20 MB 内的 PNG、JPEG、HEIC、TIFF 或 ICNS 图片。" }
            self.buildIcons()
        }
    }

    // MARK: Preview → confirm → apply → result
    @objc func startPreview() {
        guard let path = options.root else { return }
        let url = URL(fileURLWithPath: path)
        if let problem = FolderInspector.rootProblem(url) { status.stringValue = problem; return }
        root = url; items = []; rows = []; token = CancelToken(); phase = "scan"
        buildSheet()
        sheetTitle.stringValue = "正在扫描…"; summary.stringValue = "正在读取文件夹，尚未修改任何内容。"
        progress.isIndeterminate = true; progress.startAnimation(nil)
        leftButton.title = "取消"; rightButton.isHidden = true
        window.beginSheet(sheet)
        let options = self.options, token = self.token, engine = self.engine
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = engine.scan(root: url, options: options, cancel: token) { count in
                DispatchQueue.main.async { self?.summary.stringValue = "已扫描 \(count) 个文件夹…" }
            }
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.items = found; self.showPlan()
            }
        }
    }
    func buildSheet() {
        sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.appearance = NSAppearance(named: .aqua)
        let surface = Surface(frame: NSRect(x: 0, y: 0, width: 720, height: 560)); sheet.contentView = surface
        func put(_ v: NSView, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { v.frame = NSRect(x: x, y: y, width: w, height: h); surface.addSubview(v) }
        sheetTitle = label("", 18, .semibold); put(sheetTitle, 24, 18, 500, 26)
        summary = label("", 12); summary.maximumNumberOfLines = 6; put(summary, 24, 52, 672, 100)
        table = NSTableView(); table.usesAlternatingRowBackgroundColors = true; table.rowHeight = 20
        for (id, title, width) in [("name", "文件夹", 300.0), ("state", "当前状态", 150.0), ("result", "预计结果", 200.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id)); column.title = title; column.width = width; table.addTableColumn(column)
        }
        table.dataSource = self; table.delegate = self
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        put(scroll, 24, 160, 672, 320)
        progress = NSProgressIndicator(); progress.style = .bar; progress.isHidden = false; put(progress, 24, 492, 672, 12)
        leftButton = NSButton(title: "取消", target: self, action: #selector(leftAction)); leftButton.bezelStyle = .rounded; put(leftButton, 24, 512, 120, 32)
        rightButton = NSButton(title: "确认并应用", target: self, action: #selector(confirm)); rightButton.bezelStyle = .rounded; put(rightButton, 476, 512, 220, 32)
        AquaStyle.install(in: surface)
    }
    func count(_ match: (FolderItem) -> Bool) -> Int { items.filter(match).count }
    func showPlan() {
        phase = "plan"; progress.stopAnimation(nil); progress.isHidden = true
        let apply = count { if case .apply = $0.action { return true }; return false }
        let failed = count { if case .failed = $0.action { return true }; return false }
        sheetTitle.stringValue = "预览"
        var text = "预计修改　\(apply) 个\n已有自定义图标，已保留　\(count { $0.action == .keepCustom }) 个\n未设置图标，保持原生　\(count { $0.action == .noIcon || $0.action == .noTag }) 个\n无法处理　\(failed) 个"
        if items.count > 5000 { text += "\n共 \(items.count) 个文件夹，数量较多，修改可能需要一段时间。" }
        if failed > 0 { text += "\n" + permissionHint }
        summary.stringValue = text
        rows = Array(items.indices)
        reloadTable(result: false)
        leftButton.title = "取消"; rightButton.isHidden = apply == 0
        rightButton.title = "确认并应用（\(apply) 个）"
    }
    let permissionHint = "如提示没有权限，可在“系统设置 › 隐私与安全性 › 文件与文件夹 / 完全磁盘访问权限”中允许 Luma Trail。"
    func reloadTable(result: Bool) {
        table.tableColumns[2].title = result ? "处理结果" : "预计结果"
        table.headerView?.needsDisplay = true; table.reloadData()
    }
    @objc func leftAction() {
        if phase == "apply" { token.cancel(); return }
        token.cancel(); window.endSheet(sheet); sheet = nil
    }
    @objc func confirm() {
        guard let root else { return }
        phase = "apply"; token = CancelToken()
        sheetTitle.stringValue = "正在修改…"; leftButton.title = "停止"; rightButton.isHidden = true
        progress.isHidden = false; progress.isIndeterminate = false; progress.minValue = 0; progress.maxValue = Double(max(1, items.count)); progress.doubleValue = 0
        var images: [String: NSImage] = [:]
        var index = 0
        let options = self.options, token = self.token
        func batch() {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.03
            while index < items.count, ProcessInfo.processInfo.systemUptime < deadline, !token.isCancelled {
                engine.execute(&items[index], root: root, options: options, images: &images); index += 1
            }
            progress.doubleValue = Double(index)
            summary.stringValue = "已处理 \(index) / \(items.count) 个文件夹…"
            if index < items.count && !token.isCancelled { DispatchQueue.main.async(execute: batch); return }
            for i in index..<items.count { items[i].outcome = .skipped }
            finish()
        }
        batch()
    }
    func finish() {
        guard let root else { return }
        phase = "done"; engine.record(items, root: root)
        progress.isHidden = true
        let failed = count { if case .failed = $0.outcome { return true }; return false }
        let skipped = count { $0.outcome == .skipped }
        sheetTitle.stringValue = skipped > 0 ? "已停止" : "处理结果"
        var text = "成功修改　\(count { $0.outcome == .applied }) 个\n保留已有自定义图标　\(count { $0.outcome == .kept }) 个\n未设置对应图标，保持原生　\(count { $0.outcome == .native }) 个\n无法处理　\(failed) 个"
        if skipped > 0 { text += "\n已停止：剩余 \(skipped) 个未处理，已修改的保持不变。" }
        if failed > 0 { text += "\n" + permissionHint }
        summary.stringValue = text
        // Problems first, so reasons are easy to find.
        func rank(_ item: FolderItem) -> Int {
            switch item.outcome { case .failed: return 0; case .applied: return 1; case .skipped: return 3; default: return 2 }
        }
        rows = items.indices.sorted { (rank(items[$0]), $0) < (rank(items[$1]), $1) }
        reloadTable(result: true)
        leftButton.title = "完成"; rightButton.isHidden = true
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[rows[row]], id = tableColumn?.identifier.rawValue ?? ""
        let text = id == "name" ? item.name : id == "state" ? item.stateText(split: options.splitEmpty) : item.outcome?.text ?? item.action.resultText
        let field = label(text, 11); field.lineBreakMode = .byTruncatingMiddle; field.toolTip = id == "name" ? item.url.path : text
        return field
    }
}

final class SlotButton: NSButton { var slot = "" }
final class FlippedView: NSView { override var isFlipped: Bool { true } }
final class ColorDot: NSView {
    // nil draws a hollow dot for "no tag".
    var color: NSColor?
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)); (color ?? .white.withAlphaComponent(0.6)).setFill(); path.fill()
        NSColor.black.withAlphaComponent(0.2).setStroke(); path.stroke()
    }
}

func runFolderIconTests() {
    let fm = FileManager.default
    func check(_ ok: Bool, _ line: Int = #line) { if !ok { print("Folder icon test failed at line \(line)"); exit(1) } }
    let base = fm.temporaryDirectory.appendingPathComponent("luma-folder-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? fm.removeItem(at: base) }
    let root = base.appendingPathComponent("A", isDirectory: true)
    func dir(_ path: String, tags: [String]? = nil) -> URL {
        let url = root.appendingPathComponent(path, isDirectory: true)
        try! fm.createDirectory(at: url, withIntermediateDirectories: true)
        if let tags {
            let data = try! PropertyListSerialization.data(fromPropertyList: tags, format: .binary, options: 0)
            check(data.withUnsafeBytes { setxattr(url.path, "com.apple.metadata:_kMDItemUserTags", $0.baseAddress, data.count, 0, 0) } == 0)
        }
        return url
    }
    let square = NSImage(size: NSSize(width: 64, height: 32), flipped: false) { rect in NSColor.systemPink.setFill(); rect.fill(); return true }
    try! fm.createDirectory(at: root, withIntermediateDirectories: true)
    let work = dir("工作", tags: ["项目\n6", "Blue\n4"]); fm.createFile(atPath: work.appendingPathComponent("a.txt").path, contents: Data())
    let child = dir("工作/子", tags: ["Green\n2"])
    let material = dir("素材", tags: ["Yellow\n5"])
    check(NSWorkspace.shared.setIcon(square, forFile: material.path, options: []))
    let materialIcon = try! Data(contentsOf: material.appendingPathComponent("Icon\r/..namedfork/rsrc"))
    _ = dir("参考", tags: ["Blue\n4"])
    let empty = dir("空的", tags: ["Important", "Red\n6"]); fm.createFile(atPath: empty.appendingPathComponent(".DS_Store").path, contents: Data([1]))
    let plain = dir("无标签"); _ = dir("无标签/.git")
    _ = dir("App.app", tags: ["Red\n6"]); _ = dir(".hidden", tags: ["Red\n6"])
    try! fm.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: work)

    check(FolderInspector.finderColor(work) == .red && FolderInspector.finderColor(empty) == .red && FolderInspector.finderColor(plain) == nil)
    check(FolderInspector.hasCustomIcon(material) && !FolderInspector.hasCustomIcon(work))
    check(try! FolderInspector.visibleChildren(empty).isEmpty && FolderInspector.visibleChildren(plain).isEmpty && !FolderInspector.visibleChildren(work).isEmpty)
    let home = fm.homeDirectoryForCurrentUser.path
    check(FolderInspector.excluded(home + "/Library/Caches", prefixes: FolderInspector.defaultExcluded) && FolderInspector.excluded("/", prefixes: []))
    check(!FolderInspector.excluded(home + "/Documents", prefixes: FolderInspector.defaultExcluded))
    check(folderSlot(.red, empty: true, split: false) == "red" && folderSlot(.red, empty: true, split: true) == "red.empty" && folderSlot(nil, empty: false, split: true) == "none.full")
    check(folderSlotTitle("none") == "无标签图标" && folderSlotTitle("none.empty") == "无标签 · 空文件夹图标")

    let library = FolderIconLibrary(directory: base.appendingPathComponent("Icons", isDirectory: true))
    let source = base.appendingPathComponent("cat.png")
    try! NSBitmapImageRep(data: square.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: source)
    for slot in ["red", "green", "yellow"] { try! library.importImage(from: source, slot: slot) }
    check(library.configured == ["red", "green", "yellow"] && NSBitmapImageRep(data: try! Data(contentsOf: library.file("red")))!.pixelsWide == 1024)
    let engine = FolderIconEngine(library: library); engine.excludedPrefixes = []

    var options = FolderIconOptions(root: root.path)
    func plan(_ items: [FolderItem]) -> [String: FolderAction] { Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.action) }) }
    var items = engine.scan(root: root, options: options)
    check(plan(items) == ["工作": .apply("red"), "工作/子": .apply("green"), "素材": .keepCustom, "参考": .noIcon, "空的": .apply("red"), "无标签": .noTag])
    try! library.importImage(from: source, slot: "none")
    check(plan(engine.scan(root: root, options: options))["无标签"] == .apply("none"))
    library.remove("none")
    options.subfolders = false
    check(plan(engine.scan(root: root, options: options))["工作/子"] == nil)
    options.subfolders = true; options.splitEmpty = true
    try! library.importImage(from: source, slot: "red.empty"); try! library.importImage(from: source, slot: "none.full")
    let split = plan(engine.scan(root: root, options: options))
    check(split["空的"] == .apply("red.empty") && split["工作"] == .noIcon && split["工作/子"] == .noIcon && split["无标签"] == .noTag)
    library.remove("red.empty"); library.remove("none.full"); options.splitEmpty = false
    options.includeRoot = true
    check(plan(engine.scan(root: root, options: options))["A（当前文件夹）"] == .noTag)
    options.includeRoot = false

    // Drift after preview must be reported, never applied.
    try! fm.removeItem(at: empty)
    var images: [String: NSImage] = [:]
    for i in items.indices { engine.execute(&items[i], root: root, options: options, images: &images) }
    let outcomes = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.outcome!) })
    check(outcomes["工作"] == .applied && outcomes["工作/子"] == .applied && outcomes["素材"] == .kept && outcomes["参考"] == .native)
    check(outcomes["空的"] == .failed("预览后已被删除或移动"))
    check(FolderInspector.hasCustomIcon(child) && (try! Data(contentsOf: material.appendingPathComponent("Icon\r/..namedfork/rsrc"))) == materialIcon)
    check(plan(engine.scan(root: root, options: options))["工作"] == .keepCustom)
    check(!FolderInspector.hasCustomIcon(root))
    print("Folder icon tests passed: tags, custom-icon protection, emptiness, no-tag slot, scope, split slots, drift detection.")
}
