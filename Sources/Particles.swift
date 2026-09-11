import AppKit

enum TrailTheme: Int, CaseIterable {
    // Raw values 4 and 6 are retired; preserve all remaining saved selections.
    case stardust = 0, hearts = 1, flowers = 2, custom = 3, puppy = 5, bunny = 7, rainbow = 8, butterflies = 9, bubbles = 10, clover = 11, snowflakes = 12, mixed = 13
    var title: String {
        switch self {
        case .stardust: return "仙女星尘"
        case .hearts: return "蜜桃爱心"
        case .flowers: return "奶油小花"
        case .custom: return "我的图片"
        case .puppy: return "奶咖脚印"
        case .bunny: return "棉花小兔"
        case .rainbow: return "梦幻彩虹"
        case .butterflies: return "柔光蝴蝶"
        case .bubbles: return "透彩气泡"
        case .clover: return "幸运四叶草"
        case .snowflakes: return "初雪轻舞"
        case .mixed: return "缤纷混合"
        }
    }
    var subtitle: String {
        switch self {
        case .stardust: return "粉钻 · 亮片 · 轻盈散开"
        case .hearts: return "柔软 · 飘落 · 蜜桃粉"
        case .flowers: return "花瓣 · 旋转 · 奶油黄"
        case .custom: return "用自己的小图案装饰鼠标"
        case .puppy: return "圆圆脚印 · 奶咖小狗"
        case .bunny: return "长耳朵 · 腮红 · 小兔子"
        case .rainbow: return "柔光 · 七色丝带 · 缓缓消散"
        case .butterflies: return "薄翼 · 振翅 · 薄荷与粉紫"
        case .bubbles: return "透明 · 虹彩边缘 · 轻轻上浮"
        case .clover: return "白色心形叶 · 绿色光晕 · 幸运飘落"
        case .snowflakes: return "细小雪晶 · 四散 · 轻盈消散"
        case .mixed: return "全部图案等概率随机 · 含已导入图片"
        }
    }
    var symbol: String {
        switch self {
        case .stardust: return "sparkles"
        case .hearts: return "heart.fill"
        case .flowers: return "camera.macro"
        case .custom: return "photo"
        case .puppy: return "pawprint.fill"
        case .bunny: return "hare.fill"
        case .rainbow: return "rainbow"
        case .butterflies: return "leaf"
        case .bubbles: return "bubbles.and.sparkles"
        case .clover: return "leaf.fill"
        case .snowflakes: return "snowflake"
        case .mixed: return "shuffle"
        }
    }
    static var displayOrder: [TrailTheme] { [.stardust, .hearts, .flowers, .puppy, .bunny, .rainbow, .butterflies, .bubbles, .clover, .snowflakes, .mixed, .custom] }
    var colors: [NSColor] {
        switch self {
        case .stardust: return [NSColor(hex: 0xF24CB8), NSColor(hex: 0xFF85AC), NSColor(hex: 0xF8AAD9), NSColor(hex: 0xF77791)]
        case .hearts: return [NSColor(hex: 0xF39AB8), NSColor(hex: 0xFFBFAD), NSColor(hex: 0xF8CFDC), NSColor(hex: 0xD99CCB)]
        case .flowers: return [NSColor(hex: 0xFFF0C1), NSColor(hex: 0xFFCFE0), NSColor(hex: 0xD3BDEB), .white]
        case .puppy: return [NSColor(hex: 0xB78668), NSColor(hex: 0xC99E7D), NSColor(hex: 0xA78076)]
        case .bunny: return [NSColor(hex: 0xFFF5F4), NSColor(hex: 0xF7DBE7), NSColor(hex: 0xE9DEF9)]
        case .rainbow: return [0xFFA9BC, 0xFFD0AC, 0xFFF0AF, 0xC7E9B6, 0xAFE2EA, 0xBFC6F1, 0xDFB7ED].map { NSColor(hex: $0) }
        case .custom, .mixed: return [.white]
        case .butterflies: return [0xA1D98F, 0xE9AED3, 0xC4B3ED].map { NSColor(hex: $0) }
        case .bubbles: return [0xA6D8BE, 0xEFB5D0, 0xACCFEF].map { NSColor(hex: $0) }
        case .clover: return [0x83C86A, 0xA0DA7D, 0x63B67C].map { NSColor(hex: $0) }
        case .snowflakes: return [.white]
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
    var trailStart: CGPoint? = nil
    var trailControl1: CGPoint? = nil
    var trailControl2: CGPoint? = nil
    var trailBornStart: Double? = nil
}

/// Distance-spaced emission with a time-based ceiling, bounded memory, and no cursor warping.
final class ParticleSystem {
    var particles: [Particle] = []
    private var previous: CGPoint?
    private var lastTime: Double?
    private var distanceRemainder = 0.0
    private var emissionBudget = 0.0
    private var rainbowAngle: Double?
    private var rainbowTangent: CGPoint?
    private var seed: UInt64 = 0x57A41234
    let limit = 240
    func random() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 11) / 9_007_199_254_740_992.0
    }
    func reset() {
        particles.removeAll(keepingCapacity: true); previous = nil; lastTime = nil
        distanceRemainder = 0; emissionBudget = 0
        rainbowAngle = nil; rainbowTangent = nil
    }
    func tick(at time: Double, cursor: CGPoint?, settings: TrailSettings) {
        let rawDT = max(0, time - (lastTime ?? time))
        let dt = min(0.05, rawDT)
        lastTime = time
        particles.removeAll { time - $0.born >= $0.life }
        for i in particles.indices {
            if particles[i].trailStart != nil { continue }
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            if particles[i].theme == .stardust || particles[i].theme == .snowflakes {
                // Loose glitter expands and eases to a stop, without sagging into a falling tail.
                particles[i].vx *= exp(-2.1 * dt)
                particles[i].vy *= exp(-2.1 * dt)
            } else if [.butterflies, .bubbles, .clover].contains(particles[i].theme) {
                let age = time - particles[i].born
                let theme = particles[i].theme
                let targetY: Double = theme == .bubbles ? 22 : theme == .butterflies ? 12 : -12
                particles[i].vy += (targetY - particles[i].vy) * (1 - exp(-2 * dt))
                particles[i].vx *= exp(-1.6 * dt)
                particles[i].x += sin(age * (theme == .butterflies ? 7 : 3) + particles[i].phase) * 12 * dt
            } else {
                particles[i].vy -= 27 * dt
                particles[i].vx *= exp(-1.6 * dt)
            }
            particles[i].angle += particles[i].spin * dt
        }
        guard let cursor else {
            previous = nil; distanceRemainder = 0; rainbowTangent = nil
            return
        }
        guard let start = previous else { previous = cursor; return }
        previous = cursor
        let dx = Double(cursor.x - start.x), dy = Double(cursor.y - start.y)
        let distance = hypot(dx, dy)
        // Screen changes, wake, and pointer teleport should not paint a long connecting streak.
        guard rawDT < 0.3, distance < 600 else {
            distanceRemainder = 0; emissionBudget = 0; rainbowTangent = nil
            return
        }
        if settings.theme == .rainbow {
            guard distance > 0.2 else { previous = start; return }
            let width = settings.size * 2.8
            var direction = atan2(dy, dx)
            // Opposite travel directions use the same color order on the first stroke.
            if direction > .pi / 2 { direction -= .pi }
            if direction < -.pi / 2 { direction += .pi }
            let startAngle = rainbowAngle ?? direction
            var delta = direction - startAngle
            while delta > .pi / 2 { delta -= .pi }
            while delta < -.pi / 2 { delta += .pi }
            let angle = startAngle + delta * (1 - exp(-distance / max(1, width * 0.5)))
            let tangent = CGPoint(x: dx / distance, y: dy / distance)
            let oldTangent = rawDT < 0.05 ? (rainbowTangent ?? tangent) : tangent
            let handle = min(distance / 3, width * 0.22)
            // Freeze geometry, timestamps and brush orientation at emission. Expiry must not
            // re-seed the surviving trail from its new oldest segment on each redraw.
            particles.append(Particle(x: Double(cursor.x), y: Double(cursor.y), vx: 0, vy: 0,
                born: time, life: settings.lifetime, size: width, angle: angle, spin: 0,
                phase: startAngle, color: 0, theme: .rainbow, alpha: settings.opacity, trailStart: start,
                trailControl1: CGPoint(x: start.x + oldTangent.x * handle, y: start.y + oldTangent.y * handle),
                trailControl2: CGPoint(x: cursor.x - tangent.x * handle, y: cursor.y - tangent.y * handle),
                trailBornStart: time - dt))
            rainbowAngle = angle; rainbowTangent = tangent
            if particles.count > limit { particles.removeFirst(particles.count - limit) }
            return
        }
        emissionBudget = min(8, emissionBudget + dt * 90 * settings.density)
        guard distance > 0.2 else { return }
        let spacing = (settings.theme == .snowflakes ? 8.0 : settings.theme == .stardust ? 17.0 : 11.0) / settings.density
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
        // Resolve once per particle so color, size and motion use the same motif.
        let choices = TrailTheme.allCases.filter { $0 != .mixed && ($0 != .custom || s.customData != nil) }
        let theme = s.theme == .mixed ? choices[Int(random() * Double(choices.count))] : s.theme
        let direction = random() * 2 * .pi
        let speed = burst ? 35 + random() * 65 : ((theme == .stardust || theme == .snowflakes) ? 30 + random() * 80 : 5 + random() * 22)
        particles.append(Particle(x: x + (random() - 0.5) * 8, y: y + (random() - 0.5) * 8,
            vx: cos(direction) * speed, vy: sin(direction) * speed + (burst ? 8 : 6),
            born: time, life: s.lifetime * (0.65 + random() * 0.65),
            size: s.size * (theme == .snowflakes ? 0.38 + random() * 0.37 : [TrailTheme.butterflies, .bubbles, .clover].contains(theme) ? 0.8 + random() * 0.6 : 0.35 + random() * 0.85), angle: (random() - 0.5) * 0.9,
            spin: (random() - 0.5) * ([TrailTheme.flowers, .clover, .snowflakes].contains(theme) ? 2.4 : 0.65),
            phase: random() * 2 * .pi, color: Int(random() * Double(theme.colors.count)), theme: theme, alpha: s.opacity))
        if particles.count > limit { particles.removeFirst(particles.count - limit) }
    }
    var bounds: CGRect {
        particles.reduce(CGRect.null) { result, p in
            let end = CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2)
            let start = p.trailStart.map { CGRect(x: $0.x - p.size, y: $0.y - p.size, width: p.size * 2, height: p.size * 2) } ?? end
            return result.union(end).union(start)
        }
    }
}

final class ParticlePainter {
    private var textures: [String: CGImage] = [:]
    var custom: CGImage?
    init() {
        for theme in TrailTheme.allCases where theme != .custom && theme != .mixed {
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
        case .butterflies:
            ctx.setShadow(offset: .zero, blur: 8, color: color.withAlphaComponent(0.55).cgColor)
            for side in [-1.0, 1.0] {
                ctx.saveGState(); ctx.scaleBy(x: side, y: 1)
                let wing = CGMutablePath()
                wing.move(to: CGPoint(x: 2, y: 0))
                wing.addCurve(to: CGPoint(x: 48, y: 43), control1: CGPoint(x: 12, y: 40), control2: CGPoint(x: 48, y: 58))
                wing.addCurve(to: CGPoint(x: 9, y: -5), control1: CGPoint(x: 56, y: 10), control2: CGPoint(x: 30, y: 0))
                wing.addCurve(to: CGPoint(x: 33, y: -37), control1: CGPoint(x: 52, y: -6), control2: CGPoint(x: 48, y: -39))
                wing.addCurve(to: CGPoint(x: 2, y: 0), control1: CGPoint(x: 12, y: -48), control2: CGPoint(x: 5, y: -21))
                wing.closeSubpath()
                ctx.addPath(wing); ctx.fillPath()
                ctx.saveGState(); ctx.addPath(wing); ctx.clip()
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [NSColor.white.withAlphaComponent(0.9).cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 20, y: 6), startRadius: 0, endCenter: CGPoint(x: 20, y: 6), endRadius: 42, options: [])
                ctx.restoreGState(); ctx.restoreGState()
            }
            ctx.setFillColor(color.blended(withFraction: 0.25, of: .white)!.cgColor)
            ctx.fillEllipse(in: CGRect(x: -3, y: -18, width: 6, height: 42))
        case .bubbles:
            ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.45).cgColor)
            ctx.setFillColor(color.withAlphaComponent(0.035).cgColor)
            ctx.fillEllipse(in: CGRect(x: -44, y: -44, width: 88, height: 88))
            ctx.setLineWidth(3.5); ctx.setLineCap(.round)
            let tints = [color, NSColor(hex: 0xF6BFD8), NSColor(hex: 0xBEE9CD), NSColor(hex: 0xBBDDF4)]
            for i in 0..<4 {
                ctx.setStrokeColor(tints[i].withAlphaComponent(0.85).cgColor)
                ctx.addArc(center: .zero, radius: 44, startAngle: Double(i) * .pi / 2, endAngle: Double(i + 1) * .pi / 2, clockwise: false); ctx.strokePath()
            }
            ctx.setShadow(offset: .zero, blur: 0)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor); ctx.setLineWidth(4)
            ctx.addArc(center: .zero, radius: 36, startAngle: 1.8, endAngle: 2.6, clockwise: false); ctx.strokePath()
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 22, y: -28, width: 5, height: 5))
        case .clover:
            // A white clover suspended in a soft green halo, including on light desktops.
            ctx.setShadow(offset: .zero, blur: 0)
            let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                color.withAlphaComponent(0.65).cgColor,
                color.withAlphaComponent(0.38).cgColor,
                color.withAlphaComponent(0.12).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray, locations: [0, 0.45, 0.72, 1])!
            ctx.drawRadialGradient(halo, startCenter: CGPoint(x: 0, y: 4), startRadius: 0,
                                   endCenter: CGPoint(x: 0, y: 4), endRadius: 59, options: [])
            ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.6).cgColor)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(2); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 0, y: 5))
            ctx.addCurve(to: CGPoint(x: 9, y: -49), control1: CGPoint(x: -4, y: -17), control2: CGPoint(x: 5, y: -31))
            ctx.strokePath()
            ctx.translateBy(x: 0, y: 6)
            ctx.rotate(by: .pi / 4 + 0.12)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.setShadow(offset: .zero, blur: 4, color: NSColor.white.withAlphaComponent(0.65).cgColor)
            for i in 0..<4 {
                ctx.saveGState(); ctx.rotate(by: Double(i) * .pi / 2)
                let leaf = CGMutablePath(); leaf.move(to: CGPoint(x: 0, y: 3))
                leaf.addCurve(to: CGPoint(x: 0, y: 33), control1: CGPoint(x: -32, y: 16), control2: CGPoint(x: -18, y: 51))
                leaf.addCurve(to: CGPoint(x: 0, y: 3), control1: CGPoint(x: 18, y: 51), control2: CGPoint(x: 32, y: 16))
                leaf.closeSubpath(); ctx.addPath(leaf); ctx.fillPath()
                ctx.restoreGState()
            }
        case .snowflakes:
            ctx.setShadow(offset: .zero, blur: 5, color: NSColor(hex: 0xA6CDE9).withAlphaComponent(0.8).cgColor)
            ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(4); ctx.setLineCap(.round)
            for i in 0..<6 {
                ctx.saveGState(); ctx.rotate(by: Double(i) * .pi / 3)
                ctx.move(to: .zero); ctx.addLine(to: CGPoint(x: 0, y: 48))
                for y in [23.0, 36.0] {
                    ctx.move(to: CGPoint(x: -10, y: y + 8)); ctx.addLine(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: 10, y: y + 8))
                }
                ctx.strokePath(); ctx.restoreGState()
            }
        case .rainbow:
            ctx.setShadow(offset: .zero, blur: 3, color: NSColor.white.withAlphaComponent(0.3).cgColor)
            for (index, tint) in TrailTheme.rainbow.colors.enumerated() {
                ctx.setStrokeColor(tint.cgColor); ctx.setLineWidth(7); ctx.setLineCap(.round)
                ctx.addArc(center: CGPoint(x: 0, y: -30), radius: CGFloat(57 - index * 7), startAngle: 0, endAngle: .pi, clockwise: false)
                ctx.strokePath()
            }
        case .stardust, .custom, .mixed:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 49))
            path.addCurve(to: CGPoint(x: 49, y: 0), control1: CGPoint(x: 13, y: 13), control2: CGPoint(x: 13, y: 13))
            path.addCurve(to: CGPoint(x: 0, y: -49), control1: CGPoint(x: 13, y: -13), control2: CGPoint(x: 13, y: -13))
            path.addCurve(to: CGPoint(x: -49, y: 0), control1: CGPoint(x: -13, y: -13), control2: CGPoint(x: -13, y: -13))
            path.addCurve(to: CGPoint(x: 0, y: 49), control1: CGPoint(x: -13, y: 13), control2: CGPoint(x: -13, y: 13))
            ctx.addPath(path); ctx.fillPath()
        case .puppy:
            ctx.setShadow(offset: .zero, blur: 1.5, color: color.withAlphaComponent(0.3).cgColor)
            for (x, y, angle) in [(-32.0, 17.0, 0.42), (-13.0, 35.0, 0.16), (13.0, 35.0, -0.16), (32.0, 17.0, -0.42)] {
                ctx.saveGState(); ctx.translateBy(x:x,y:y); ctx.rotate(by:angle)
                ctx.fillEllipse(in:CGRect(x:-10,y:-12,width:20,height:22)); ctx.restoreGState()
            }
            let pad = CGMutablePath()
            pad.move(to:CGPoint(x:-29,y:-27))
            pad.addCurve(to:CGPoint(x:0,y:12),control1:CGPoint(x:-35,y:-9),control2:CGPoint(x:-17,y:15))
            pad.addCurve(to:CGPoint(x:29,y:-27),control1:CGPoint(x:17,y:15),control2:CGPoint(x:35,y:-9))
            pad.addCurve(to:CGPoint(x:-29,y:-27),control1:CGPoint(x:16,y:-40),control2:CGPoint(x:-16,y:-40))
            pad.closeSubpath(); ctx.addPath(pad); ctx.fillPath()
        case .bunny:
            ctx.setShadow(offset:.zero,blur:2,color:NSColor(hex:0xB995BD).withAlphaComponent(0.35).cgColor)
            for x in [-17.0,17.0] { ctx.fillEllipse(in:CGRect(x:x-10,y:9,width:20,height:45)) }
            ctx.fillEllipse(in:CGRect(x:-36,y:-38,width:72,height:67))
            ctx.setShadow(offset:.zero,blur:0); ctx.setFillColor(NSColor(hex:0xEDABC5).cgColor)
            for x in [-17.0,17.0] { ctx.fillEllipse(in:CGRect(x:x-4,y:22,width:8,height:25)) }
            for x in [-23.0,23.0] { ctx.fillEllipse(in:CGRect(x:x-7,y:-18,width:14,height:8)) }
            ctx.setFillColor(NSColor(hex:0x78586F).cgColor)
            for x in [-12.0,12.0] { ctx.fillEllipse(in:CGRect(x:x-3,y:-8,width:6,height:8)) }
            ctx.fillEllipse(in:CGRect(x:-3,y:-17,width:6,height:4))
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
    /// Bounded cubic interpolation rounds sampled corners while leaving the cursor endpoint exact.
    static func rainbowRuns(_ particles: [Particle]) -> [[Particle]] {
        var runs: [[Particle]] = []
        for p in particles where p.trailStart != nil {
            if let end = runs.last?.last, p.trailStart == CGPoint(x: end.x, y: end.y) {
                runs[runs.count - 1].append(p)
            } else { runs.append([p]) }
        }
        return runs.map { run in
            var samples: [Particle] = []
            for p in run {
                let a = p.trailStart!, b = CGPoint(x: p.x, y: p.y)
                let length = hypot(b.x - a.x, b.y - a.y)
                let c1 = p.trailControl1 ?? CGPoint(x: a.x + (b.x - a.x) / 3, y: a.y + (b.y - a.y) / 3)
                let c2 = p.trailControl2 ?? CGPoint(x: b.x - (b.x - a.x) / 3, y: b.y - (b.y - a.y) / 3)
                let steps = min(32, max(1, Int(ceil(length / 4))))
                var previous = a
                for step in 1...steps {
                    let t = Double(step) / Double(steps), u = 1 - t
                    let end = CGPoint(x: u*u*u*a.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*b.x,
                                      y: u*u*u*a.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*b.y)
                    var sample = p
                    sample.trailStart = previous; sample.x = end.x; sample.y = end.y
                    sample.angle = p.phase + (p.angle - p.phase) * t
                    let birth = p.trailBornStart ?? p.born
                    sample.born = birth + (p.born - birth) * t
                    if hypot(end.x - previous.x, end.y - previous.y) > 0.001 { samples.append(sample) }
                    previous = end
                }
            }
            return samples
        }
    }
    static func rainbowFade(_ particle: Particle, at time: Double) -> Double {
        let progress = max(0, min(1, (time - particle.born) / particle.life))
        // Smoothstep has zero slope at both ends, avoiding a sudden pop or final cutoff.
        return 1 - progress * progress * (3 - 2 * progress)
    }
    private lazy var rainbowBrush: CGImage = {
        let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let palette = TrailTheme.rainbow.colors.map { $0.cgColor }
        let rainbow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: palette as CFArray, locations: nil)!
        context.drawLinearGradient(rainbow, start: CGPoint(x: 64, y: 24), end: CGPoint(x: 64, y: 104),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.setBlendMode(.destinationIn)
        let maskColors = [1.0, 0.8, 0.32, 0.04, 0.0].map { NSColor.white.withAlphaComponent($0).cgColor }
        let mask = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: maskColors as CFArray,
                              locations: [0, 0.25, 0.55, 0.8, 1])!
        context.drawRadialGradient(mask, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
                                   endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [.drawsAfterEndLocation])
        return context.makeImage()!
    }()
    private func drawRainbow(_ particles: [Particle], in ctx: CGContext, origin: CGPoint, at time: Double) {
        for run in Self.rainbowRuns(particles) {
            guard let first = run.first, let tail = first.trailStart, let last = run.last else { continue }
            // Soft circular stamps use source-over: transparent edges never erase an earlier stroke.
            // Distance-weighted coverage keeps slow sampling from making the brush darker.
            for p in run {
                let start = p.trailStart!, dx = p.x - start.x, dy = p.y - start.y
                let length = hypot(dx, dy)
                let spacing = max(0.5, p.size * 0.07)
                let count = max(1, Int(ceil(length / spacing)))
                let coverage = 1 - exp(-3.2 * length / Double(count) / p.size)
                for index in 0..<count {
                    let t = (Double(index) + 0.5) / Double(count)
                    ctx.saveGState()
                    ctx.setBlendMode(.normal)
                    ctx.translateBy(x: start.x + dx * t - origin.x, y: start.y + dy * t - origin.y)
                    ctx.rotate(by: p.angle)
                    ctx.setAlpha(Self.rainbowFade(p, at: time) * p.alpha * coverage)
                    let radius = p.size * 0.9
                    ctx.draw(rainbowBrush, in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
                    ctx.restoreGState()
                }
            }
            let arcLength = run.reduce(0.0) { $0 + hypot($1.x - $1.trailStart!.x, $1.y - $1.trailStart!.y) }
            for (point, p) in [(tail, first), (CGPoint(x: last.x, y: last.y), last)] {
                ctx.saveGState()
                ctx.setAlpha(Self.rainbowFade(p, at: time) * p.alpha * min(1, arcLength / p.size))
                let colors = [NSColor(hex: 0xFFF8EA).withAlphaComponent(0.35),
                              NSColor(hex: 0xF3CDEB).withAlphaComponent(0.2),
                              NSColor(hex: 0xCCCBFF).withAlphaComponent(0.06),
                              NSColor(hex: 0xCCCBFF).withAlphaComponent(0)].map { $0.cgColor }
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.25, 0.55, 1])!
                let center = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: p.size * 0.9, options: [])
                ctx.restoreGState()
            }
        }
    }
    func draw(_ particles: [Particle], in ctx: CGContext, origin: CGPoint = .zero, at time: Double, twinkleSpeed: Double) {
        ctx.interpolationQuality = .high
        drawRainbow(particles, in: ctx, origin: origin, at: time)
        for p in particles where p.trailStart == nil {
            let progress = max(0, min(1, (time - p.born) / p.life))
            let fade = pow(1 - progress, 0.85) * min(1, (time - p.born) / 0.035)
            // Independent phases make each element shimmer instead of blinking the whole trail at once.
            let wave = (sin((time - p.born) * 2 * .pi * twinkleSpeed + p.phase) + 1) / 2
            let gentle = [TrailTheme.butterflies, .bubbles, .clover, .snowflakes].contains(p.theme)
            let twinkle = gentle ? 0.85 + 0.15 * wave : 0.18 + 0.82 * wave
            let size = p.size * (1 - progress * 0.55) * (p.theme == .stardust ? 0.72 + 0.28 * wave : 1)
            guard let texture = p.theme == .custom ? custom : textures["\(p.theme.rawValue)-\(p.color)"] else { continue }
            ctx.saveGState()
            ctx.translateBy(x: p.x - Double(origin.x), y: p.y - Double(origin.y))
            ctx.rotate(by: p.angle); ctx.setAlpha(max(0, fade * twinkle * p.alpha))
            if p.theme == .butterflies {
                ctx.scaleBy(x: 0.5 + 0.5 * abs(cos((time - p.born) * 9 + p.phase)), y: 1)
            }
            ctx.draw(texture, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
            ctx.restoreGState()
        }
    }
}

func runParticleTests() {
    precondition(TrailTheme.allCases.map(\.rawValue) == [0, 1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13], "Remaining saved theme IDs must stay stable")
    for retiredID in [4, 6] {
        precondition((TrailTheme(rawValue: retiredID) ?? .stardust) == .stardust, "Retired themes must fall back to stardust")
    }
    precondition(Set(TrailTheme.displayOrder) == Set(TrailTheme.allCases), "Every theme must be selectable")
    for includeCustom in [false, true] {
        let mixedSettings = TrailSettings(persistent: false), mixed = ParticleSystem()
        mixedSettings.theme = .mixed
        if includeCustom {
            mixedSettings.customData = NSBitmapImageRep(cgImage: ParticlePainter.texture(theme: .hearts, color: .white))
                .representation(using: .png, properties: [:])!
        }
        let expected = TrailTheme.allCases.filter { $0 != .mixed && ($0 != .custom || includeCustom) }
        var counts: [TrailTheme: Int] = [:]
        for _ in 0..<2_000 {
            mixed.particles.removeAll(keepingCapacity: true)
            mixed.burst(at: .zero, time: 0, settings: mixedSettings)
            for particle in mixed.particles {
                counts[particle.theme, default: 0] += 1
                precondition(particle.color >= 0 && particle.color < particle.theme.colors.count, "Mixed colors must match the resolved motif")
            }
        }
        precondition(Set(counts.keys) == Set(expected), "Mix must include all available motifs and exclude unavailable images")
        let average = 24_000.0 / Double(expected.count)
        precondition(counts.values.allSatisfy { abs(Double($0) - average) < average * 0.1 }, "Mixed motifs must have approximately equal frequency")
        mixed.reset()
        for frame in 0...120 {
            mixed.tick(at: Double(frame) / 60, cursor: CGPoint(x: frame * 5, y: 100), settings: mixedSettings)
        }
        precondition(Set(mixed.particles.map(\.theme)) == Set(expected), "Movement must emit mixed motifs too")
        precondition(mixed.particles.count <= mixed.limit, "Mixed particles must stay bounded")
        mixed.tick(at: 10, cursor: nil, settings: mixedSettings)
        precondition(mixed.particles.isEmpty, "Mixed motifs must expire")
        precondition(mixedSettings.theme == .mixed, "Emission must preserve the selected mixed setting")
    }
    print("PASS: mixed motif coverage, equal frequency, custom image inclusion, movement and expiry")
    for theme in [TrailTheme.butterflies, .bubbles, .clover, .snowflakes] {
        let settings = TrailSettings(persistent: false), system = ParticleSystem()
        settings.theme = theme
        for frame in 0...60 {
            system.tick(at: Double(frame) / 60, cursor: CGPoint(x: frame * 4, y: 100), settings: settings)
        }
        precondition(!system.particles.isEmpty && system.particles.allSatisfy { $0.theme == theme }, "New themes must emit their selected motif")
        system.particles = [Particle(x: 0, y: 0, vx: 0, vy: 0, born: 1, life: 2, size: 24, angle: 0, spin: 1, phase: 0, color: 0, theme: theme, alpha: 1)]
        for frame in 61...90 { system.tick(at: Double(frame) / 60, cursor: nil, settings: settings) }
        precondition((system.particles[0].y > 0) == (theme == .bubbles || theme == .butterflies), "Floating and falling themes must move in the intended direction")
        system.tick(at: 10, cursor: nil, settings: settings)
        precondition(system.particles.isEmpty, "New motifs must fully expire")
    }
    let snowSettings = TrailSettings(persistent: false), snow = ParticleSystem()
    snowSettings.theme = .snowflakes
    for frame in 0...30 {
        snow.tick(at: Double(frame) / 60, cursor: CGPoint(x: frame * 4, y: 100), settings: snowSettings)
    }
    precondition(snow.particles.count >= 10 && snow.particles.allSatisfy { $0.size < snowSettings.size * 0.8 }, "Snow must emit multiple small flakes")
    precondition(snow.particles.contains { $0.vx < -10 } && snow.particles.contains { $0.vx > 10 } &&
                 snow.particles.contains { $0.vy < -10 } && snow.particles.contains { $0.vy > 10 }, "Snow must scatter in all directions")
    let emitted = snow.particles
    snow.tick(at: 0.55, cursor: nil, settings: snowSettings)
    for (before, after) in zip(emitted, snow.particles) {
        precondition(abs(after.vx) < abs(before.vx) && abs(after.vy) < abs(before.vy), "Scattered snow must slow without falling acceleration")
    }
    snow.tick(at: 10, cursor: nil, settings: snowSettings)
    precondition(snow.particles.isEmpty, "Scattered snow must fully disappear")
    print("PASS: small snowflakes, multiple emission, radial scatter, damping and expiry")
    print("PASS: new theme selection, emission, floating/falling motion and expiry")
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
    s.theme = .rainbow; model.reset()
    for i in 0...60 { model.tick(at: Double(i) / 60, cursor: CGPoint(x: i * 4, y: 80), settings: s) }
    precondition(model.particles.count == 60 && model.particles.allSatisfy { $0.trailStart != nil }, "Rainbow must form connected segments")
    let point = model.particles[0]
    model.tick(at: 1.01, cursor: CGPoint(x: 240, y: 80), settings: s)
    precondition(model.particles[0].x == point.x && model.particles[0].y == point.y, "Rainbow must not drift")
    model.tick(at: 1.02, cursor: CGPoint(x: 5000, y: 80), settings: s)
    precondition(model.particles.count == 60, "Rainbow must not connect teleports")
    model.tick(at: 5, cursor: nil, settings: s)
    precondition(model.particles.isEmpty && model.bounds.isNull, "Rainbow must fade completely")
    precondition(TrailTheme.custom.rawValue == 3 && TrailTheme.bunny.rawValue == 7, "Persisted themes must stay stable")
    let sample = Particle(x: 160, y: 128, vx: 0, vy: 0, born: 0, life: 2, size: 32,
                          angle: 0, spin: 0, phase: 0, color: 0, theme: .rainbow, alpha: 1,
                          trailStart: CGPoint(x: 96, y: 128))
    var turn = sample; turn.trailStart = CGPoint(x: 160, y: 128); turn.x = 180; turn.y = 180
    let smoothed = ParticlePainter.rainbowRuns([sample, turn])
    precondition(smoothed.count == 1 && smoothed[0].last!.x == turn.x && smoothed[0].last!.y == turn.y, "Smoothing must keep the cursor endpoint exact")
    var separate = sample; separate.trailStart = CGPoint(x: 500, y: 500); separate.x = 520; separate.y = 500
    precondition(ParticlePainter.rainbowRuns([sample, separate]).count == 2, "Smoothing must preserve breaks")
    precondition(ParticlePainter.rainbowFade(sample, at: 0) == 1 && ParticlePainter.rainbowFade(sample, at: 1) == 0.5 && ParticlePainter.rainbowFade(sample, at: 2) == 0, "Smooth fade must fully expire")
    let bitmap = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024,
                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ParticlePainter().draw([sample], in: bitmap, at: 0.1, twinkleSpeed: 1)
    let pixels = bitmap.data!.assumingMemoryBound(to: UInt8.self)
    precondition(pixels[128 * 1024 + 80 * 4 + 3] > 0 && pixels[128 * 1024 + 176 * 4 + 3] > 0, "Both endpoints must glow beyond the ribbon")
    precondition(pixels[128 * 1024 + 50 * 4 + 3] == 0, "Glow must stay within invalidation bounds")
    // Repeated reversals must add soft light rather than cut holes or darken the background.
    let jitter = ParticleSystem(), jitterSettings = TrailSettings(persistent: false)
    jitterSettings.theme = .rainbow
    for frame in 0...90 {
        jitter.tick(at: Double(frame) / 60, cursor: CGPoint(x: 128 + sin(Double(frame) * 1.7) * 9,
                    y: 128 + cos(Double(frame) * 1.3) * 7), settings: jitterSettings)
    }
    bitmap.setFillColor(NSColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 1).cgColor)
    bitmap.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
    let baseline = pixels[0]
    ParticlePainter().draw(jitter.particles, in: bitmap, at: 1.51, twinkleSpeed: 1)
    for index in stride(from: 0, to: 256 * 1024, by: 4) {
        precondition(pixels[index] >= baseline && pixels[index + 1] >= baseline && pixels[index + 2] >= baseline,
                     "Circular brush overlap must not introduce dark pixels")
        precondition(pixels[index + 3] == 255, "Round brush must never erase the background")
    }
    let stable = ParticleSystem(), stableSettings = TrailSettings(persistent: false)
    stableSettings.theme = .rainbow; stableSettings.lifetime = 0.6
    for frame in 0...45 {
        let t = Double(frame) / 60
        stable.tick(at: t, cursor: CGPoint(x: 128 + cos(t * 9) * 38, y: 128 + sin(t * 9) * 38), settings: stableSettings)
    }
    let frozen = stable.particles
    let middle = frozen[frozen.count / 2]
    let isolated = ParticlePainter.rainbowRuns([middle]).flatMap { $0 }
    let withPrevious = ParticlePainter.rainbowRuns([frozen[frozen.count / 2 - 1], middle]).flatMap { $0 }
    for (left, right) in zip(isolated, withPrevious.suffix(isolated.count)) {
        precondition(left.x == right.x && left.y == right.y && left.angle == right.angle && left.born == right.born,
                     "Expiry of a neighbor must not alter existing brush samples")
    }
    let stop = CGPoint(x: frozen.last!.x, y: frozen.last!.y)
    for frame in 46...90 {
        stable.tick(at: Double(frame) / 60, cursor: stop, settings: stableSettings)
        for particle in stable.particles {
            let original = frozen.first { $0.born == particle.born }!
            precondition(particle.angle == original.angle && particle.phase == original.phase &&
                         particle.trailControl1 == original.trailControl1 && particle.trailControl2 == original.trailControl2,
                         "Fade-out must preserve the emitted orientation and curve")
        }
    }
    precondition(stable.particles.isEmpty, "Frozen brush samples must still fully expire")
    stable.tick(at: 1.52, cursor: CGPoint(x: stop.x - 8, y: stop.y), settings: stableSettings)
    precondition(stable.particles.last!.phase == frozen.last!.angle, "Restart must retain color orientation after idle")
    print("PASS: frozen brush orientation, neighbor expiry, stop fade, restart continuity")
    print("PASS: circular brush rapid reversals, no dark pixels or erased background")
    print("PASS: smooth rainbow endpoint, separate paths, eased expiry, both halo pixels and bounds")
    print("PASS: rainbow continuity, no drift, teleport, expiry, stable theme values")
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

func renderCuteThemeSheet(to path: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:480,pixelsHigh:300,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    for (i, theme) in [TrailTheme.puppy, .bunny].enumerated() {
        let x = CGFloat(i * 240)
        NSColor(hex:i % 2 == 0 ? 0xFFF4F8 : 0xF2ECF6).setFill(); NSRect(x:x,y:0,width:240,height:300).fill()
        NSImage(cgImage:ParticlePainter.texture(theme:theme,color:theme.colors[0]),size:NSSize(width:128,height:128)).draw(in:NSRect(x:x+56,y:136,width:128,height:128))
        (theme.title as NSString).draw(at:NSPoint(x:x+65,y:105),withAttributes:[.font:NSFont.systemFont(ofSize:18,weight:.semibold),.foregroundColor:NSColor(hex:0x66536B)])
        for j in 0..<5 {
            let image = NSImage(cgImage:ParticlePainter.texture(theme:theme,color:theme.colors[j % theme.colors.count]),size:NSSize(width:128,height:128))
            image.draw(in:NSRect(x:x+30+CGFloat(j*36),y:44+CGFloat(j%2)*10,width:25,height:25))
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}

/// Render the same rainbow path used by the desktop overlay for visual inspection.
func renderRainbowFixture(to path: String) throws {
    let settings = TrailSettings(persistent: false), system = ParticleSystem(), painter = ParticlePainter()
    settings.theme = .rainbow; settings.size = 28; settings.lifetime = 2.5
    let context = CGContext(data: nil, width: 900, height: 1020, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    for frame in 0...100 {
        let x = 70 + Double(frame) * 7.5
        system.tick(at: Double(frame) / 60, cursor: CGPoint(x: x, y: 170 + sin(Double(frame) / 23) * 78), settings: settings)
    }
    for (row, background) in [0x242130, 0x242130, 0xF9F6F2].enumerated() {
        context.saveGState(); context.translateBy(x: 0, y: CGFloat(row * 340))
        context.setFillColor(NSColor(hex: background).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 900, height: 340))
        if row == 0 {
            for column in 0..<3 {
                let jitter = ParticleSystem()
                for frame in 0...100 {
                    let t = Double(frame)
                    let point = column == 0 ? CGPoint(x: 150 + sin(t * 1.7) * 10, y: 170 + cos(t * 1.3) * 8)
                        : column == 1 ? CGPoint(x: 450 + sin(t * 0.35) * 70, y: 170)
                        : CGPoint(x: 750 + sin(t * 0.24) * 42, y: 170 + sin(t * 0.48) * 32)
                    jitter.tick(at: t / 60, cursor: point, settings: settings)
                }
                painter.draw(jitter.particles, in: context, at: 1.7, twinkleSpeed: settings.twinkleSpeed)
            }
        } else {
            painter.draw(system.particles, in: context, at: 1.7, twinkleSpeed: settings.twinkleSpeed)
        }
        context.restoreGState()
    }
    try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
