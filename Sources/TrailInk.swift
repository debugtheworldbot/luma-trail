import AppKit

/// Opaque, rounded paint with local specular reflections; no glitter or outer glow.
enum TrailInk {
    static func drawTrail(_ particles: [Particle], in ctx: CGContext, origin: CGPoint, at time: Double) {
        var runs: [[Particle]] = []
        for p in particles where p.theme == .splatoon && p.trailStart != nil {
            if let last = runs.last?.last, last.color == p.color,
               p.trailStart == CGPoint(x: last.x, y: last.y) {
                runs[runs.count - 1].append(p)
            } else {
                runs.append([p])
            }
        }
        ctx.saveGState()
        ctx.translateBy(x: -origin.x, y: -origin.y)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for run in runs {
            guard let newest = run.last else { continue }
            let body = CGMutablePath(), sheen = CGMutablePath(), shade = CGMutablePath()
            for (index, p) in run.enumerated() {
                guard let start = p.trailStart else { continue }
                let end = CGPoint(x: p.x, y: p.y)
                let age = max(0, time - p.born)
                let width = p.size * (0.94 + 0.07 * sin(p.phase) + 0.035 * sin(p.phase * 2.7))
                let line = CGMutablePath()
                line.move(to: start); line.addLine(to: end)
                body.addPath(line.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1))
                let shine = CGMutablePath()
                shine.move(to: CGPoint(x: start.x, y: start.y + width * 0.23))
                shine.addLine(to: CGPoint(x: end.x, y: end.y + width * 0.23))
                sheen.addPath(shine.copy(strokingWithWidth: width * 0.12, lineCap: .round, lineJoin: .round, miterLimit: 1))
                let lowerEdge = CGMutablePath()
                lowerEdge.move(to: CGPoint(x: start.x, y: start.y - width * 0.3))
                lowerEdge.addLine(to: CGPoint(x: end.x, y: end.y - width * 0.3))
                shade.addPath(lowerEdge.copy(strokingWithWidth: width * 0.17, lineCap: .round, lineJoin: .round, miterLimit: 1))
                // Sparse edge details stay attached to a continuous body, including during fast moves.
                if Int(p.born * 5) != Int((p.trailBornStart ?? p.born) * 5), sin(p.phase * 7) > -0.3 {
                    let length = min(p.size * 0.65, max(0, age - 0.15) * (11 + 5 * sin(p.phase * 3)))
                    let drip = CGMutablePath()
                    drip.move(to: end)
                    drip.addQuadCurve(to: CGPoint(x: p.x + 1, y: p.y - width * 0.48 - length),
                                      control: CGPoint(x: p.x - 2, y: p.y - width * 0.4))
                    body.addPath(drip.copy(strokingWithWidth: max(1.5, width * 0.11), lineCap: .round, lineJoin: .round, miterLimit: 1))
                    if index % 3 == 0 {
                        body.addEllipse(in: CGRect(x: p.x + width * 0.25, y: p.y + width * 0.68, width: 2, height: 2))
                    }
                }
            }
            let color = TrailTheme.splatoon.colors[newest.color]
            let progress = max(0, min(1, (time - newest.born) / newest.life))
            // Composite each connected color as one surface, so overlapping samples have no seams.
            ctx.saveGState()
            ctx.setAlpha(newest.alpha * (1 - pow(progress, 4)))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setFillColor(color.cgColor)
            ctx.addPath(body); ctx.fillPath()
            ctx.addPath(body); ctx.clip()
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor)
            ctx.addPath(shade); ctx.fillPath()
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
            ctx.addPath(sheen); ctx.fillPath()
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    static func draw(_ ctx: CGContext, color: NSColor, phase: Double, age: Double) {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 0)
        let path = CGMutablePath()
        let count = 48
        var points: [CGPoint] = []
        for i in 0..<count {
            let a = Double(i) * 2 * .pi / Double(count)
            let radius = 32 + 8 * sin(a * 5 + phase) + 5 * cos(a * 3 - phase) + 3 * sin(a * 7 + phase)
            points.append(CGPoint(x: cos(a) * radius, y: sin(a) * radius * 0.83))
        }
        let first = points[0], last = points[count - 1]
        path.move(to: CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
        for i in 0..<count {
            let next = points[(i + 1) % count]
            path.addQuadCurve(to: CGPoint(x: (points[i].x + next.x) / 2, y: (points[i].y + next.y) / 2), control: points[i])
        }
        path.closeSubpath()
        // A minority of splats grow a narrow hanging drip. Keep all geometry inside ±64.
        if phase < 2.1 {
            let length = min(27, max(0, age - 0.12) * 23)
            let x = 8 * sin(phase * 3)
            path.move(to: CGPoint(x: x - 5, y: -15))
            path.addCurve(to: CGPoint(x: x - 3.5, y: -27 - length),
                          control1: CGPoint(x: x - 2, y: -23), control2: CGPoint(x: x - 2, y: -23 - length))
            path.addCurve(to: CGPoint(x: x + 3.5, y: -27 - length),
                          control1: CGPoint(x: x - 6, y: -35 - length), control2: CGPoint(x: x + 6, y: -35 - length))
            path.addCurve(to: CGPoint(x: x + 5, y: -15),
                          control1: CGPoint(x: x + 2, y: -23 - length), control2: CGPoint(x: x + 2, y: -23))
            path.closeSubpath()
        }
        for i in 0..<3 {
            let a = phase + Double(i) * 2.1
            let radius = 47.0 + Double(i) * 2
            let size = 3.5 + Double(i) * 1.1
            path.addEllipse(in: CGRect(x: cos(a) * radius - size / 2, y: sin(a) * radius * 0.8 - size / 2, width: size, height: size))
        }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let dark = color.blended(withFraction: 0.27, of: .black)!
        let light = color.blended(withFraction: 0.18, of: .white)!
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [light.cgColor, color.cgColor, dark.cgColor] as CFArray, locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: -14, y: 40), end: CGPoint(x: 14, y: -58), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.setLineCap(.round)
        ctx.setLineWidth(3.2)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.76).cgColor)
        ctx.move(to: CGPoint(x: -23, y: 12))
        ctx.addCurve(to: CGPoint(x: -5, y: 23), control1: CGPoint(x: -22, y: 21), control2: CGPoint(x: -14, y: 25))
        ctx.strokePath()
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.86).cgColor)
        ctx.fillEllipse(in: CGRect(x: 8, y: 19, width: 5, height: 3))
        ctx.setFillColor(light.withAlphaComponent(0.6).cgColor)
        ctx.fillEllipse(in: CGRect(x: 3, y: -19, width: 18, height: 5))
        ctx.restoreGState()
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
