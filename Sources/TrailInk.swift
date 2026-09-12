import AppKit

/// Paint impacts merge into a single coverage mask before surface lighting is applied.
enum TrailInk {
    private static let surface: [(Double, Double)] = (0..<(128 * 128)).map { index in
        let x = Double(index % 128) * 2 * .pi / 128, y = Double(index / 128) * 2 * .pi / 128
        let ripple = sin(x * 4 + sin(y * 3) * 2) * cos(y * 4 + sin(x * 2))
        let broad = sin(x + y) * sin(y - x)
        return (ripple * 0.024 + broad * 0.025, pow(max(0, ripple), 12) * 0.075)
    }

    static func noise(_ value: Double) -> Double {
        let n = sin(value * 127.1 + 311.7) * 43758.5453
        return n - floor(n)
    }

    static func impact(center: CGPoint, radius: Double, seed: Double, age: Double) -> CGPath {
        let shape = CGMutablePath()
        var points: [CGPoint] = []
        let lobes = 7 + Int(noise(seed + 8) * 5)
        for i in 0..<64 {
            let angle = Double(i) * 2 * .pi / 64
            let lobe = pow(max(0, sin(angle * Double(lobes) + seed)), 4)
            let r = radius * (0.79 + 0.15 * sin(angle * 3 + seed * 2) + 0.18 * lobe)
            points.append(CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r * 0.92))
        }
        let first = points[0], last = points[63]
        shape.move(to: CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
        for i in points.indices {
            let next = points[(i + 1) % points.count]
            shape.addQuadCurve(to: CGPoint(x: (points[i].x + next.x) / 2, y: (points[i].y + next.y) / 2), control: points[i])
        }
        shape.closeSubpath()
        // Small satellite impacts use the same material as the paint coverage.
        for i in 0..<(noise(seed + 31) < 0.38 ? 2 : 0) {
            let n = seed + Double(i) * 3.71
            let angle = noise(n) * .pi * 2
            let reach = radius * (1.12 + noise(n + 1) * 0.45)
            let r = radius * (0.025 + noise(n + 2) * 0.08)
            shape.addEllipse(in: CGRect(x: center.x + cos(angle) * reach - r,
                                       y: center.y + sin(angle) * reach - r, width: r * 2, height: r * 2))
        }
        if noise(seed + 17) < 0.24 {
            let x = center.x + (noise(seed + 19) - 0.5) * radius * 0.65
            let bottom = center.y - radius * 0.67
            let length = radius * (0.18 + noise(seed + 20) * 0.52) * min(1, max(0, age - 0.08) / 0.8)
            let w = radius * (0.055 + noise(seed + 21) * 0.045)
            let drip = CGMutablePath()
            drip.move(to: CGPoint(x: x, y: bottom + radius * 0.3))
            drip.addCurve(to: CGPoint(x: x + w * 0.5, y: bottom - length),
                          control1: CGPoint(x: x - w, y: bottom), control2: CGPoint(x: x + w * 0.4, y: bottom - length * 0.8))
            shape.addPath(drip.copy(strokingWithWidth: w * 2, lineCap: .round, lineJoin: .round, miterLimit: 1))
        }
        return shape
    }

    /// Lighting is derived from the merged mask, so there are no bead outlines or tube highlights.
    static func paint(_ shape: CGPath, color: NSColor, in ctx: CGContext) {
        var contours: [(CGPath, CGRect)] = []
        var contour = CGMutablePath()
        shape.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint: contour.move(to: element.points[0])
            case .addLineToPoint: contour.addLine(to: element.points[0])
            case .addQuadCurveToPoint: contour.addQuadCurve(to: element.points[1], control: element.points[0])
            case .addCurveToPoint: contour.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
            case .closeSubpath:
                contour.closeSubpath()
                contours.append((contour, contour.boundingBoxOfPath))
                contour = CGMutablePath()
            @unknown default: break
            }
        }
        let extent = shape.boundingBoxOfPath.insetBy(dx: -3, dy: -3).intersection(ctx.boundingBoxOfClipPath)
        guard !extent.isNull, !extent.isEmpty else { return }
        // Fixed world-space tiles keep resolution, pixel phase and texture origin stable.
        // Padding supplies neighboring alpha for normals without exposing tile seams.
        let tileSize = 128.0
        for row in Int(floor(extent.minY / tileSize))...Int(floor(extent.maxY / tileSize)) {
            for column in Int(floor(extent.minX / tileSize))...Int(floor(extent.maxX / tileSize)) {
                let tile = CGRect(x: Double(column) * tileSize, y: Double(row) * tileSize, width: tileSize, height: tileSize)
                let bounds = tile.insetBy(dx: -3, dy: -3)
                let visible = contours.filter { $0.1.intersects(bounds) }
                guard !visible.isEmpty else { continue }
                ctx.saveGState()
                ctx.clip(to: tile)
                paintTile(visible.map { $0.0 }, bounds: bounds, color: color, in: ctx)
                ctx.restoreGState()
            }
        }
    }

    private static func paintTile(_ contours: [CGPath], bounds: CGRect, color: NSColor, in ctx: CGContext) {
        let scale = 1.0
        let width = Int(bounds.width), height = Int(bounds.height)
        guard let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = bitmap.data else { return }
        bitmap.translateBy(x: -bounds.minX, y: -bounds.minY)
        bitmap.setFillColor(NSColor.white.cgColor)
        for contour in contours { bitmap.addPath(contour); bitmap.fillPath() }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let rgb = color.usingColorSpace(.deviceRGB)!
        let base = [Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent)]
        // Alpha remains unchanged while RGB is shaded, permitting in-place normal estimation.
        let step = max(1, Int(scale * 1.2))
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let alpha = Double(pixels[offset + 3]) / 255
                if alpha == 0 { continue }
                func coverage(_ dx: Int, _ dy: Int) -> Double {
                    let xx = max(0, min(width - 1, x + dx)), yy = max(0, min(height - 1, y + dy))
                    return Double(pixels[(yy * width + xx) * 4 + 3]) / 255
                }
                let edge = (coverage(-step, 0) - coverage(step, 0)) * 0.12
                    + (coverage(0, -step) - coverage(0, step)) * 0.2
                let px = bounds.minX + Double(x) + 0.5, py = bounds.maxY - Double(y) - 0.5
                // Low-contrast uneven wet surface, anchored to wall coordinates rather than each shot.
                let surfaceX = ((Int(floor(px)) % 128) + 128) % 128
                let surfaceY = ((Int(floor(py)) % 128) + 128) % 128
                let material = surface[surfaceY * 128 + surfaceX]
                let light = edge + material.0
                let specular = material.1
                for channel in 0..<3 {
                    let value = base[channel] * (0.97 + min(0, light)) + max(0, light) * (1 - base[channel]) + specular
                    pixels[offset + channel] = UInt8(max(0, min(255, value * alpha * 255)))
                }
            }
        }
        if let image = bitmap.makeImage() { ctx.draw(image, in: bounds) }
    }

    static func drawTrail(_ particles: [Particle], in ctx: CGContext, origin: CGPoint, at time: Double) {
        var runs: [[Particle]] = []
        for p in particles where p.theme == .splatoon {
            if let last = runs.last?.last, last.color == p.color {
                runs[runs.count - 1].append(p)
            } else { runs.append([p]) }
        }
        ctx.saveGState()
        ctx.translateBy(x: -origin.x, y: -origin.y)
        for run in runs {
            guard let newest = run.last else { continue }
            let body = CGMutablePath()
            for p in run {
                guard let start = p.trailStart else {
                    body.addPath(impact(center: CGPoint(x: p.x, y: p.y), radius: p.size * 0.32,
                                        seed: p.phase, age: max(0, time - p.born)))
                    continue
                }
                let dx = p.x - start.x, dy = p.y - start.y, distance = hypot(dx, dy)
                guard distance > 0 else { continue }
                let bridge = CGMutablePath()
                bridge.move(to: start); bridge.addLine(to: CGPoint(x: p.x, y: p.y))
                body.addPath(bridge.copy(strokingWithWidth: p.size * 0.58, lineCap: .round, lineJoin: .round, miterLimit: 1))
                let spacing = max(2, p.size * 0.24)
                let first = Int(ceil(p.phase / spacing)), last = Int(floor((p.phase + distance) / spacing))
                if first <= last {
                    for index in first...last {
                        let t = max(0, min(1, (Double(index) * spacing - p.phase) / distance))
                        let seed = Double(index) + Double(p.color) * 103
                        let side = (noise(seed + 4) - 0.5) * p.size * 0.22
                        let center = CGPoint(x: start.x + dx * t - dy / distance * side,
                                             y: start.y + dy * t + dx / distance * side)
                        body.addPath(impact(center: center, radius: p.size * (0.43 + noise(seed + 2) * 0.17),
                                            seed: seed, age: max(0, time - p.born)))
                    }
                }
            }
            let progress = max(0, min(1, (time - newest.born) / newest.life))
            ctx.saveGState()
            ctx.setAlpha(newest.alpha * (1 - pow(progress, 4)))
            paint(body, color: TrailTheme.splatoon.colors[newest.color], in: ctx)
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    static func draw(_ ctx: CGContext, color: NSColor, phase: Double, age: Double) {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 0)
        paint(impact(center: .zero, radius: 35, seed: phase, age: age), color: color, in: ctx)
        ctx.restoreGState()
    }
}

func renderInkFixture(to path: String) throws {
    let ctx = CGContext(data: nil, width: 960, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let painter = ParticlePainter()
    for row in 0..<2 {
        ctx.setFillColor(NSColor(hex: row == 0 ? 0x252333 : 0xF4F2EE).cgColor)
        ctx.fill(CGRect(x: 0, y: row * 240, width: 960, height: 240))
        for i in 0..<6 {
            ctx.saveGState()
            ctx.translateBy(x: Double(i) * 150 + 100, y: Double(row) * 240 + 158)
            TrailInk.draw(ctx, color: TrailTheme.splatoon.colors[i], phase: Double(i) * 0.8, age: 0.9)
            ctx.restoreGState()
        }
        let settings = TrailSettings(persistent: false), system = ParticleSystem()
        settings.theme = .splatoon; settings.size = 30; settings.lifetime = 2.5
        for frame in 0...100 {
            system.tick(at: Double(frame) / 60, cursor: CGPoint(x: 50 + frame * 8, y: row * 240 + 60 + Int(sin(Double(frame) / 12) * 18)), settings: settings)
        }
        painter.draw(system.particles, in: ctx, at: 1.7, twinkleSpeed: 1.8)
    }
    try NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func runInkRenderingTests() {
    let bitmap = CGContext(data: nil, width: 1200, height: 720, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let reference = CGContext(data: nil, width: 1200, height: 720, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let original = CGMutablePath()
    original.addRect(CGRect(x: 70, y: 60, width: 460, height: 350))
    let expanded = CGMutablePath()
    expanded.addRect(CGRect(x: 12, y: 8, width: 1120, height: 690))
    TrailInk.paint(original, color: TrailTheme.splatoon.colors[0], in: reference)
    TrailInk.paint(expanded, color: TrailTheme.splatoon.colors[0], in: bitmap)
    let stablePixels = reference.data!.assumingMemoryBound(to: UInt8.self)
    let expandedPixels = bitmap.data!.assumingMemoryBound(to: UInt8.self)
    // Compare every covered interior pixel, including both sides of tile boundaries.
    var compared = 0
    for y in 0..<720 {
        for x in 0..<1200 {
            let offset = y * reference.bytesPerRow + x * 4
            if stablePixels[offset + 3] == 255 && x > 76 && x < 523 {
                let above = max(0, y - 5) * reference.bytesPerRow + x * 4 + 3
                let below = min(719, y + 5) * reference.bytesPerRow + x * 4 + 3
                if stablePixels[above] == 255 && stablePixels[below] == 255 {
                    for channel in 0..<4 {
                        precondition(stablePixels[offset + channel] == expandedPixels[offset + channel], "Ink highlights must stay fixed as bounds grow or shrink")
                    }
                    compared += 1
                }
            }
        }
    }
    precondition(compared > 100_000, "Stability check must cover a substantial shared ink area")
    print("PASS: fixed ink highlights across changing bounds and tile boundaries")
    let settings = TrailSettings(persistent: false), system = ParticleSystem()
    settings.theme = .splatoon; settings.size = 42; settings.lifetime = 2.5
    for frame in 0...140 {
        let t = Double(frame) / 60
        system.tick(at: t, cursor: CGPoint(x: 70 + Double(frame) * 7.4, y: 360 + sin(Double(frame) / 15) * 280), settings: settings)
    }
    let begin = CFAbsoluteTimeGetCurrent()
    for frame in 0..<8 {
        bitmap.clear(CGRect(x: 0, y: 0, width: 1200, height: 720))
        TrailInk.drawTrail(system.particles, in: bitmap, origin: .zero, at: 2.35 + Double(frame) / 60)
    }
    let milliseconds = (CFAbsoluteTimeGetCurrent() - begin) * 1000 / 8
    precondition(system.bounds.contains(CGPoint(x: system.particles.last!.x, y: system.particles.last!.y)))
    print(String(format: "PASS: large ink surface render, average %.2f ms/frame (offscreen 1200x720)", milliseconds))
}
