import AppKit

extension ParticlePainter {
    func drawComet(_ particles: [Particle], in ctx: CGContext, origin: CGPoint, at time: Double) {
        ctx.saveGState()
        // Source-over only: transparent edges must never punch holes in earlier strokes.
        ctx.setBlendMode(.normal)
        let tints = [0xF7D9A8, 0xF4B7D2, 0xC9C6F7]
        for p in particles where p.theme == .comet {
            guard let start = p.trailStart else { continue }
            let fade = trailPathFade(p, at: time)
            guard fade > 0.001 else { continue }
            let head = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
            let tail = CGPoint(x: start.x - origin.x, y: start.y - origin.y)
            let body = NSColor(hex: tints[p.color % 3])
            let glow = NSColor(hex: tints[(p.color + 2) % 3])
            let headWidth = p.size * 0.18
            let tailWidth = max(0.7, headWidth * 0.22)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: max(3, p.size * 0.28),
                          color: glow.withAlphaComponent(0.42 * fade).cgColor)
            ctx.setFillColor(glow.withAlphaComponent(0.16 * fade).cgColor)
            fillTaperedStreak(ctx, from: tail, to: head, tailWidth: tailWidth * 3.4, headWidth: headWidth * 3.2)
            ctx.setShadow(offset: .zero, blur: 0)
            ctx.setFillColor(body.withAlphaComponent(0.55 * fade).cgColor)
            fillTaperedStreak(ctx, from: tail, to: head, tailWidth: tailWidth, headWidth: headWidth)
            ctx.setFillColor(NSColor(hex: 0xF7D9A8).blended(withFraction: 0.55, of: .white)!
                .withAlphaComponent(0.9 * fade).cgColor)
            fillTaperedStreak(ctx, from: tail, to: head, tailWidth: tailWidth * 0.4, headWidth: headWidth * 0.45)
            let colors = [
                NSColor.white.withAlphaComponent(0.95 * fade).cgColor,
                body.withAlphaComponent(0.62 * fade).cgColor,
                glow.withAlphaComponent(0.18 * fade).cgColor,
                glow.withAlphaComponent(0).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                      locations: [0, 0.28, 0.62, 1])!
            ctx.drawRadialGradient(gradient, startCenter: head, startRadius: 0,
                                   endCenter: head, endRadius: p.size * 0.4, options: [])
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    func drawAurora(_ particles: [Particle], in ctx: CGContext, origin: CGPoint, at time: Double) {
        ctx.saveGState()
        ctx.setBlendMode(.normal)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let ribbonHex = [0xAFE2EA, 0xC4B3ED, 0xFFC6D9]
        for p in particles where p.theme == .aurora {
            guard let start = p.trailStart else { continue }
            let fade = trailPathFade(p, at: time)
            guard fade > 0.001 else { continue }
            let head = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
            let tail = CGPoint(x: start.x - origin.x, y: start.y - origin.y)
            let dx = head.x - tail.x, dy = head.y - tail.y
            let length = hypot(dx, dy)
            let nx: CGFloat, ny: CGFloat
            if length > 0.001 {
                nx = -dy / length
                ny = dx / length
            } else {
                nx = 0
                ny = 1
            }
            let width = p.size * 0.22
            for (index, hex) in ribbonHex.enumerated() {
                let wave = sin(p.phase + time * 2 + Double(index)) * p.size * 0.12
                let shift = CGFloat((Double(index) - 1) * p.size * 0.18 + wave)
                let a = CGPoint(x: tail.x + nx * shift, y: tail.y + ny * shift)
                let b = CGPoint(x: head.x + nx * shift, y: head.y + ny * shift)
                let tint = NSColor(hex: hex)
                ctx.setStrokeColor(tint.withAlphaComponent(0.12 * fade).cgColor)
                ctx.setLineWidth(width * 1.7)
                ctx.move(to: a)
                ctx.addLine(to: b)
                ctx.strokePath()
                ctx.setStrokeColor(tint.withAlphaComponent(0.28 * fade).cgColor)
                ctx.setLineWidth(width)
                ctx.move(to: a)
                ctx.addLine(to: b)
                ctx.strokePath()
            }
        }
        ctx.restoreGState()
    }

    func drawRipples(_ particles: [Particle], in ctx: CGContext, origin: CGPoint, at time: Double) {
        ctx.saveGState()
        ctx.setBlendMode(.normal)
        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        for p in particles where p.theme == .ripples {
            let fade = trailPathFade(p, at: time)
            guard fade > 0.001 else { continue }
            let tint = NSColor(hex: p.color % 2 == 0 ? 0x8EC7E6 : 0xF2C6DE)
            let center = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
            let radius = p.size
            ctx.setStrokeColor(tint.withAlphaComponent(fade).cgColor)
            ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                         width: radius * 2, height: radius * 2))
            let dot = 1.4
            ctx.setFillColor(tint.withAlphaComponent(0.12 * fade).cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2))
        }
        ctx.restoreGState()
    }
}

enum TrailCardArt {
    static func drawComet(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.setBlendMode(.normal)
        let champagne = NSColor(hex: 0xF7D9A8)
        let blush = NSColor(hex: 0xF4B7D2)
        let lavender = NSColor(hex: 0xC9C6F7)
        let head = CGPoint(x: 22, y: 2)
        let tip = CGPoint(x: -50, y: 4)
        let control = CGPoint(x: -8, y: 16)
        ctx.setShadow(offset: .zero, blur: 10, color: lavender.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor(lavender.withAlphaComponent(0.28).cgColor)
        fillCardComet(ctx, from: tip, control: control, to: head, tailWidth: 3, headWidth: 30)
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor(blush.blended(withFraction: 0.25, of: color)!.withAlphaComponent(0.7).cgColor)
        fillCardComet(ctx, from: tip, control: control, to: head, tailWidth: 2, headWidth: 18)
        ctx.setFillColor(champagne.blended(withFraction: 0.2, of: .white)!.cgColor)
        fillCardComet(ctx, from: tip, control: control, to: head, tailWidth: 1.2, headWidth: 8)
        let colors = [
            NSColor.white.cgColor,
            champagne.blended(withFraction: 0.35, of: color)!.cgColor,
            blush.withAlphaComponent(0.55).cgColor,
            lavender.withAlphaComponent(0).cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0, 0.28, 0.6, 1])!
        ctx.drawRadialGradient(gradient, startCenter: head, startRadius: 0,
                               endCenter: head, endRadius: 24, options: [])
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.fillEllipse(in: CGRect(x: 16, y: 0, width: 8, height: 7))
        ctx.restoreGState()
    }

    static func drawAurora(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.setBlendMode(.normal)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let ribbons: [(CGFloat, CGFloat, Int)] = [
            (-18, 12, 0xAFE2EA),
            (0, -14, 0xC4B3ED),
            (18, 12, 0xFFC6D9)
        ]
        for (y, amp, hex) in ribbons {
            let tint = NSColor(hex: hex).blended(withFraction: 0.18, of: color)!
            ctx.setShadow(offset: .zero, blur: 7, color: tint.withAlphaComponent(0.4).cgColor)
            ctx.setStrokeColor(tint.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(16)
            ctx.move(to: CGPoint(x: -50, y: y))
            ctx.addCurve(to: CGPoint(x: 50, y: y), control1: CGPoint(x: -18, y: y + amp),
                         control2: CGPoint(x: 18, y: y - amp))
            ctx.strokePath()
            ctx.setShadow(offset: .zero, blur: 0)
            ctx.setStrokeColor(tint.cgColor)
            ctx.setLineWidth(10)
            ctx.move(to: CGPoint(x: -50, y: y))
            ctx.addCurve(to: CGPoint(x: 50, y: y), control1: CGPoint(x: -18, y: y + amp),
                         control2: CGPoint(x: 18, y: y - amp))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    static func drawRipples(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.setBlendMode(.normal)
        ctx.setLineCap(.round)
        let outer = NSColor(hex: 0x8EC7E6).blended(withFraction: 0.22, of: color)!
        let inner = NSColor(hex: 0xF2C6DE).blended(withFraction: 0.18, of: color)!
        ctx.setShadow(offset: .zero, blur: 6, color: outer.withAlphaComponent(0.45).cgColor)
        ctx.setStrokeColor(outer.cgColor)
        ctx.setLineWidth(4.5)
        ctx.strokeEllipse(in: CGRect(x: -40, y: -40, width: 80, height: 80))
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(inner.cgColor)
        ctx.setLineWidth(3.5)
        ctx.strokeEllipse(in: CGRect(x: -22, y: -22, width: 44, height: 44))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        ctx.fillEllipse(in: CGRect(x: 4, y: 6, width: 11, height: 11))
        ctx.restoreGState()
    }
}

private func trailPathFade(_ p: Particle, at time: Double) -> Double {
    let progress = max(0, min(1, (time - p.born) / p.life))
    let fade = 1 - progress * progress * (3 - 2 * progress)
    return fade * p.alpha
}

private func fillTaperedStreak(_ ctx: CGContext, from a: CGPoint, to b: CGPoint,
                               tailWidth: Double, headWidth: Double) {
    let tailWidth = CGFloat(tailWidth), headWidth = CGFloat(headWidth)
    let dx = b.x - a.x, dy = b.y - a.y
    let length = hypot(dx, dy)
    if length < 0.5 {
        ctx.fillEllipse(in: CGRect(x: b.x - headWidth / 2, y: b.y - headWidth / 2,
                                   width: headWidth, height: headWidth))
        return
    }
    let nx = -dy / length, ny = dx / length
    let path = CGMutablePath()
    path.move(to: CGPoint(x: a.x + nx * tailWidth / 2, y: a.y + ny * tailWidth / 2))
    path.addLine(to: CGPoint(x: b.x + nx * headWidth / 2, y: b.y + ny * headWidth / 2))
    path.addLine(to: CGPoint(x: b.x - nx * headWidth / 2, y: b.y - ny * headWidth / 2))
    path.addLine(to: CGPoint(x: a.x - nx * tailWidth / 2, y: a.y - ny * tailWidth / 2))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: a.x - tailWidth / 2, y: a.y - tailWidth / 2,
                               width: tailWidth, height: tailWidth))
    ctx.fillEllipse(in: CGRect(x: b.x - headWidth / 2, y: b.y - headWidth / 2,
                               width: headWidth, height: headWidth))
}

private func fillCardComet(_ ctx: CGContext, from a: CGPoint, control: CGPoint, to b: CGPoint,
                           tailWidth: CGFloat, headWidth: CGFloat) {
    let steps = 18
    var left: [CGPoint] = []
    var right: [CGPoint] = []
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps)
        let u = 1 - t
        let point = CGPoint(x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                            y: u * u * a.y + 2 * u * t * control.y + t * t * b.y)
        let dt = max(0.02, 1 / CGFloat(steps))
        let t0 = max(0, t - dt), t1 = min(1, t + dt)
        let u0 = 1 - t0, u1 = 1 - t1
        let p0 = CGPoint(x: u0 * u0 * a.x + 2 * u0 * t0 * control.x + t0 * t0 * b.x,
                         y: u0 * u0 * a.y + 2 * u0 * t0 * control.y + t0 * t0 * b.y)
        let p1 = CGPoint(x: u1 * u1 * a.x + 2 * u1 * t1 * control.x + t1 * t1 * b.x,
                         y: u1 * u1 * a.y + 2 * u1 * t1 * control.y + t1 * t1 * b.y)
        let tx = p1.x - p0.x, ty = p1.y - p0.y
        let len = max(0.001, hypot(tx, ty))
        let nx = -ty / len, ny = tx / len
        let width = tailWidth + (headWidth - tailWidth) * t
        left.append(CGPoint(x: point.x + nx * width / 2, y: point.y + ny * width / 2))
        right.append(CGPoint(x: point.x - nx * width / 2, y: point.y - ny * width / 2))
    }
    let path = CGMutablePath()
    path.move(to: left[0])
    for point in left.dropFirst() { path.addLine(to: point) }
    for point in right.reversed() { path.addLine(to: point) }
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: a.x - tailWidth / 2, y: a.y - tailWidth / 2,
                               width: tailWidth, height: tailWidth))
    ctx.fillEllipse(in: CGRect(x: b.x - headWidth / 2, y: b.y - headWidth / 2,
                               width: headWidth, height: headWidth))
}
