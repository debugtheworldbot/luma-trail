import AppKit

enum TrailTheme: Int, CaseIterable {
    case stardust, hearts, flowers, custom
    var title: String { ["仙女星尘", "蜜桃爱心", "奶油小花", "我的图片"][rawValue] }
    var subtitle: String { ["粉钻 · 亮片 · 轻盈散开", "柔软 · 飘落 · 蜜桃粉", "花瓣 · 旋转 · 奶油黄", "用自己的小图案装饰鼠标"][rawValue] }
    var symbol: String { ["sparkles", "heart.fill", "camera.macro", "photo"][rawValue] }
    var colors: [NSColor] {
        switch self {
        case .stardust: return [NSColor(hex: 0xF24CB8), NSColor(hex: 0xFF85AC), NSColor(hex: 0xF8AAD9), NSColor(hex: 0xF77791)]
        case .hearts: return [NSColor(hex: 0xF39AB8), NSColor(hex: 0xFFBFAD), NSColor(hex: 0xF8CFDC), NSColor(hex: 0xD99CCB)]
        case .flowers: return [NSColor(hex: 0xFFF0C1), NSColor(hex: 0xFFCFE0), NSColor(hex: 0xD3BDEB), .white]
        case .custom: return [.white]
        }
    }
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

final class TrailSettings {
    private let defaults: UserDefaults?
    var theme: TrailTheme = .stardust
    var size: Double = 19
    var density: Double = 0.8
    var lifetime: Double = 1.25
    var opacity: Double = 0.88
    var twinkleSpeed: Double = 1.8
    var clickBurst = true
    var enabled = true
    var customData: Data?
    init(persistent: Bool = true) {
        defaults = persistent ? .standard : nil
        guard let d = defaults else { return }
        theme = TrailTheme(rawValue: d.integer(forKey: "theme")) ?? .stardust
        func value(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            guard d.object(forKey: key) != nil else { return fallback }
            let v = d.double(forKey: key)
            return v.isFinite ? min(range.upperBound, max(range.lowerBound, v)) : fallback
        }
        size = value("size", 19, 8...42)
        density = value("density", 0.8, 0.25...1.8)
        lifetime = value("lifetime", 1.25, 0.4...2.5)
        opacity = value("opacity", 0.88, 0.25...1)
        twinkleSpeed = value("twinkleSpeed", 1.8, 0.2...4)
        clickBurst = d.object(forKey: "clickBurst") == nil ? true : d.bool(forKey: "clickBurst")
        enabled = d.object(forKey: "enabled") == nil ? true : d.bool(forKey: "enabled")
        customData = d.data(forKey: "customImage")
        if theme == .custom && customData == nil { theme = .stardust }
    }
    func save() {
        guard let d = defaults else { return }
        d.set(theme.rawValue, forKey: "theme"); d.set(size, forKey: "size")
        d.set(density, forKey: "density"); d.set(lifetime, forKey: "lifetime")
        d.set(opacity, forKey: "opacity"); d.set(clickBurst, forKey: "clickBurst")
        d.set(twinkleSpeed, forKey: "twinkleSpeed")
        d.set(enabled, forKey: "enabled"); d.set(customData, forKey: "customImage")
    }
}

struct Particle {
    var x: Double, y: Double, vx: Double, vy: Double
    var born: Double, life: Double, size: Double, angle: Double, spin: Double, phase: Double
    var color: Int
    var theme: TrailTheme
    var alpha: Double
}

/// Distance-spaced emission with a time-based ceiling, bounded memory, and no cursor warping.
final class ParticleSystem {
    var particles: [Particle] = []
    private var previous: CGPoint?
    private var lastTime: Double?
    private var distanceRemainder = 0.0
    private var emissionBudget = 0.0
    private var seed: UInt64 = 0x57A41234
    let limit = 240
    func random() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 11) / Double(UInt64.max >> 11)
    }
    func reset() {
        particles.removeAll(keepingCapacity: true); previous = nil; lastTime = nil
        distanceRemainder = 0; emissionBudget = 0
    }
    func tick(at time: Double, cursor: CGPoint?, settings: TrailSettings) {
        let rawDT = max(0, time - (lastTime ?? time))
        let dt = min(0.05, rawDT)
        lastTime = time
        particles.removeAll { time - $0.born >= $0.life }
        for i in particles.indices {
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            if particles[i].theme == .stardust {
                // Loose glitter expands and eases to a stop, without sagging into a falling tail.
                particles[i].vx *= exp(-2.1 * dt)
                particles[i].vy *= exp(-2.1 * dt)
            } else {
                particles[i].vy -= (particles[i].theme == .stardust ? 14 : 27) * dt
                particles[i].vx *= exp(-1.6 * dt)
            }
            particles[i].angle += particles[i].spin * dt
        }
        guard let cursor else {
            previous = nil; distanceRemainder = 0
            return
        }
        guard let start = previous else { previous = cursor; return }
        previous = cursor
        let dx = Double(cursor.x - start.x), dy = Double(cursor.y - start.y)
        let distance = hypot(dx, dy)
        // Screen changes, wake, and pointer teleport should not paint a long connecting streak.
        guard rawDT < 0.3, distance < 600 else {
            distanceRemainder = 0; emissionBudget = 0
            return
        }
        emissionBudget = min(8, emissionBudget + dt * 90 * settings.density)
        guard distance > 0.2 else { return }
        let spacing = (settings.theme == .stardust ? 17.0 : 11.0) / settings.density
        let total = distance + distanceRemainder
        let count = min(12, min(Int(total / spacing), Int(emissionBudget)))
        distanceRemainder = total.truncatingRemainder(dividingBy: spacing)
        guard count > 0 else { return }
        emissionBudget -= Double(count)
        for i in 0..<count {
            let t = (Double(i) + random()) / Double(count)
            spawn(x: Double(start.x) + dx * t, y: Double(start.y) + dy * t,
                  at: time, settings: settings, burst: false)
        }
    }
    func burst(at point: CGPoint, time: Double, settings: TrailSettings) {
        for _ in 0..<12 { spawn(x: Double(point.x), y: Double(point.y), at: time, settings: settings, burst: true) }
    }
    private func spawn(x: Double, y: Double, at time: Double, settings s: TrailSettings, burst: Bool) {
        let direction = random() * 2 * .pi
        let speed = burst ? 35 + random() * 65 : (s.theme == .stardust ? 30 + random() * 80 : 5 + random() * 22)
        particles.append(Particle(x: x + (random() - 0.5) * 8, y: y + (random() - 0.5) * 8,
            vx: cos(direction) * speed, vy: sin(direction) * speed + (burst ? 8 : 6),
            born: time, life: s.lifetime * (0.65 + random() * 0.65),
            size: s.size * (0.35 + random() * 0.85), angle: (random() - 0.5) * 0.9,
            spin: (random() - 0.5) * (s.theme == .flowers ? 2.4 : 0.65),
            phase: random() * 2 * .pi, color: Int(random() * Double(s.theme.colors.count)), theme: s.theme, alpha: s.opacity))
        if particles.count > limit { particles.removeFirst(particles.count - limit) }
    }
    var bounds: CGRect {
        particles.reduce(CGRect.null) { result, p in
            result.union(CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2))
        }
    }
}

final class ParticlePainter {
    private var textures: [String: CGImage] = [:]
    var custom: CGImage?
    init() {
        for theme in TrailTheme.allCases where theme != .custom {
            for color in theme.colors.indices { textures["\(theme.rawValue)-\(color)"] = Self.texture(theme: theme, color: theme.colors[color]) }
        }
    }
    func loadCustom(_ data: Data?) {
        custom = data.flatMap { NSImage(data: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    }
    static func texture(theme: TrailTheme, color: NSColor) -> CGImage {
        let ctx = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 64, y: 64)
        ctx.setShadow(offset: .zero, blur: theme == .stardust ? 5 : 3, color: color.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor(color.cgColor)
        switch theme {
        case .stardust, .custom:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 49))
            path.addCurve(to: CGPoint(x: 49, y: 0), control1: CGPoint(x: 13, y: 13), control2: CGPoint(x: 13, y: 13))
            path.addCurve(to: CGPoint(x: 0, y: -49), control1: CGPoint(x: 13, y: -13), control2: CGPoint(x: 13, y: -13))
            path.addCurve(to: CGPoint(x: -49, y: 0), control1: CGPoint(x: -13, y: -13), control2: CGPoint(x: -13, y: -13))
            path.addCurve(to: CGPoint(x: 0, y: 49), control1: CGPoint(x: -13, y: 13), control2: CGPoint(x: -13, y: 13))
            ctx.addPath(path); ctx.fillPath()
        case .hearts:
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: -41))
            p.addCurve(to: CGPoint(x: 0, y: 28), control1: CGPoint(x: -86, y: 12), control2: CGPoint(x: -32, y: 71))
            p.addCurve(to: CGPoint(x: 0, y: -41), control1: CGPoint(x: 32, y: 71), control2: CGPoint(x: 86, y: 12))
            ctx.addPath(p); ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
            ctx.fillEllipse(in: CGRect(x: -26, y: 14, width: 10, height: 15))
        case .flowers:
            for i in 0..<6 {
                ctx.saveGState(); ctx.rotate(by: CGFloat(i) * .pi / 3)
                ctx.fillEllipse(in: CGRect(x: -16, y: 7, width: 32, height: 44)); ctx.restoreGState()
            }
            ctx.setShadow(offset: .zero, blur: 0)
            ctx.setFillColor(NSColor(hex: 0xEAB963).cgColor)
            ctx.fillEllipse(in: CGRect(x: -12, y: -12, width: 24, height: 24))
        }
        return ctx.makeImage()!
    }
    func draw(_ particles: [Particle], in ctx: CGContext, origin: CGPoint = .zero, at time: Double, twinkleSpeed: Double) {
        ctx.interpolationQuality = .high
        for p in particles {
            let progress = max(0, min(1, (time - p.born) / p.life))
            let fade = pow(1 - progress, 0.85) * min(1, (time - p.born) / 0.035)
            // Independent phases make each element shimmer instead of blinking the whole trail at once.
            let wave = (sin((time - p.born) * 2 * .pi * twinkleSpeed + p.phase) + 1) / 2
            let twinkle = 0.18 + 0.82 * wave
            let size = p.size * (1 - progress * 0.55) * (p.theme == .stardust ? 0.72 + 0.28 * wave : 1)
            guard let texture = p.theme == .custom ? custom : textures["\(p.theme.rawValue)-\(p.color)"] else { continue }
            ctx.saveGState()
            ctx.translateBy(x: p.x - Double(origin.x), y: p.y - Double(origin.y))
            ctx.rotate(by: p.angle); ctx.setAlpha(max(0, fade * twinkle * p.alpha))
            ctx.draw(texture, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
            ctx.restoreGState()
        }
    }
}

func runParticleTests() {
    let s = TrailSettings(persistent: false), model = ParticleSystem()
    model.tick(at: 0, cursor: .zero, settings: s)
    for i in 1...60 { model.tick(at: Double(i) / 60, cursor: CGPoint(x: i * 3, y: 80), settings: s) }
    precondition(!model.particles.isEmpty, "Movement must emit")
    precondition(model.particles.count <= model.limit, "Bounded particle storage")
    model.tick(at: 10, cursor: CGPoint(x: 180, y: 80), settings: s)
    precondition(model.particles.isEmpty, "All particles expire after idle / sleep")
    model.tick(at: 10.01, cursor: CGPoint(x: 5000, y: 80), settings: s)
    precondition(model.particles.isEmpty, "Teleport must not create a streak")
    for _ in 0..<100 { model.burst(at: .zero, time: 11, settings: s) }
    precondition(model.particles.count == model.limit, "Click bursts must also respect the cap")
    model.reset()
    precondition(model.particles.isEmpty && model.bounds.isNull, "Pause must clear state")
    for i in 0...120 { model.tick(at: Double(i) / 60, cursor: CGPoint(x: 50, y: 50), settings: s) }
    precondition(model.particles.isEmpty, "Stationary pointer must not emit")
    model.reset()
    for i in 0...30 { model.tick(at: Double(i) / 60, cursor: CGPoint(x: i * 4, y: 100), settings: s) }
    let lastBirth = model.particles.map(\.born).max()!
    for i in 31...150 {
        model.tick(at: Double(i) / 60, cursor: CGPoint(x: 120, y: 100), settings: s)
        precondition(model.particles.allSatisfy { $0.born <= lastBirth }, "Stopping must never spawn new particles")
    }
    precondition(model.particles.isEmpty, "Existing trail must fade completely while stopped")
    model.burst(at: CGPoint(x: 120, y: 100), time: 3, settings: s)
    precondition(model.particles.count == 12, "Explicit click burst remains available while stopped")
    print("PASS: movement, expiry, teleport, cap, reset, idle; no stop emission, retained click burst")
}

/// Deterministic visual fixture using the production simulation and painter.
func renderGlitterFixture(to path: String) throws {
    let s = TrailSettings(persistent: false), system = ParticleSystem(), painter = ParticlePainter()
    let ctx = CGContext(data: nil, width: 1000, height: 250, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(NSColor(hex: 0xFFF5FA).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 250))
    var column = 0
    for frame in 0...110 {
        let t = Double(frame) / 60
        system.tick(at: t, cursor: CGPoint(x: min(125, 35 + Double(frame) * 3), y: 125), settings: s)
        if [44, 54, 70, 100].contains(frame) {
            ctx.saveGState(); ctx.translateBy(x: CGFloat(column * 250), y: 0)
            painter.draw(system.particles, in: ctx, at: t, twinkleSpeed: s.twinkleSpeed)
            ctx.setStrokeColor(NSColor(hex: 0xA28B9B).cgColor); ctx.setLineWidth(0.5)
            ctx.strokeEllipse(in: CGRect(x: 123, y: 123, width: 4, height: 4))
            ctx.restoreGState(); column += 1
        }
    }
    let data = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
}
