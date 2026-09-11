import AppKit

enum TrailGlow {
    static func drawFirefly(_ ctx: CGContext, color: NSColor) {
        drawHalo(ctx, color: color, radius: 48, peak: 0.52)
        let inner = color.blended(withFraction: 0.55, of: .white) ?? color
        drawHalo(ctx, color: inner, radius: 18, peak: 0.8)

        ctx.setShadow(offset: .zero, blur: 4, color: color.withAlphaComponent(0.35).cgColor)
        ctx.setFillColor(color.withAlphaComponent(0.3).cgColor)
        ctx.saveGState()
        ctx.translateBy(x: -11, y: 2)
        ctx.rotate(by: 0.42)
        ctx.fillEllipse(in: CGRect(x: -12, y: -4, width: 20, height: 8))
        ctx.restoreGState()
        ctx.saveGState()
        ctx.translateBy(x: 11, y: 2)
        ctx.rotate(by: -0.42)
        ctx.fillEllipse(in: CGRect(x: -8, y: -4, width: 20, height: 8))
        ctx.restoreGState()

        ctx.setShadow(offset: .zero, blur: 6, color: NSColor.white.withAlphaComponent(0.75).cgColor)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        ctx.fillEllipse(in: CGRect(x: -6, y: -6, width: 12, height: 12))
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: -2.5, y: -1.5, width: 4, height: 5))
    }

    static func drawGalaxyStar(_ ctx: CGContext, color: NSColor) {
        drawHalo(ctx, color: color, radius: 44, peak: 0.48)
        let fill = color.blended(withFraction: 0.2, of: .white) ?? color
        ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.55).cgColor)
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(starPath(points: 5, outer: 28, inner: 11))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 3, color: NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        ctx.addPath(starPath(points: 5, outer: 11, inner: 4.2))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.fillEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8))
    }

    static func drawPixieDust(_ ctx: CGContext, color: NSColor) {
        let champagne = color.blended(withFraction: 0.38, of: NSColor(srgbRed: 1, green: 0.94, blue: 0.76, alpha: 1)) ?? color
        drawHalo(ctx, color: champagne, radius: 26, peak: 0.42)
        ctx.setShadow(offset: .zero, blur: 4, color: champagne.withAlphaComponent(0.55).cgColor)
        ctx.setFillColor(champagne.cgColor)
        ctx.addPath(starPath(points: 4, outer: 22, inner: 4.6))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 2, color: NSColor.white.withAlphaComponent(0.65).cgColor)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.94).cgColor)
        ctx.addPath(starPath(points: 4, outer: 8, inner: 1.8))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 2, color: champagne.withAlphaComponent(0.5).cgColor)
        let flecks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (16, 10, 3.4, 0.9),
            (-15, 7, 2.8, 0.75),
            (7, -17, 3.1, 0.85)
        ]
        for (x, y, size, alpha) in flecks {
            ctx.setFillColor(champagne.withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size))
        }
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: -2, y: -2, width: 4, height: 4))
    }

    static func drawSparkler(_ ctx: CGContext, color: NSColor) {
        let warm = color.blended(withFraction: 0.28, of: NSColor(srgbRed: 1, green: 0.76, blue: 0.42, alpha: 1)) ?? color
        ctx.saveGState()
        ctx.scaleBy(x: 0.2, y: 1)
        drawHalo(ctx, color: warm, radius: 42, peak: 0.5)
        ctx.restoreGState()

        ctx.setShadow(offset: .zero, blur: 8, color: warm.withAlphaComponent(0.7).cgColor)
        ctx.setFillColor(warm.cgColor)
        ctx.addPath(streakPath(halfHeight: 36, halfWidth: 5))
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 3, color: NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        ctx.addPath(streakPath(halfHeight: 28, halfWidth: 2.2))
        ctx.fillPath()

        ctx.setFillColor((color.blended(withFraction: 0.35, of: .white) ?? color).cgColor)
        let sparks: [(CGFloat, CGFloat, CGFloat)] = [(11, 13, 5), (-12, -7, 4.2), (9, -18, 3.6)]
        for (x, y, radius) in sparks {
            ctx.saveGState()
            ctx.translateBy(x: x, y: y)
            ctx.addPath(starPath(points: 4, outer: radius, inner: radius * 0.24))
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.6)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 0, y: -24))
        ctx.addLine(to: CGPoint(x: 0, y: 24))
        ctx.strokePath()
    }

    private static func drawHalo(_ ctx: CGContext, color: NSColor, radius: CGFloat, peak: CGFloat) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                color.withAlphaComponent(peak).cgColor,
                color.withAlphaComponent(peak * 0.42).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray,
            locations: [0, 0.4, 1]
        )!
        ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                               endCenter: .zero, endRadius: radius, options: [])
    }

    private static func starPath(points: Int, outer: CGFloat, inner: CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        let steps = points * 2
        for i in 0..<steps {
            let angle = -.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let radius = i.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private static func streakPath(halfHeight: CGFloat, halfWidth: CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: halfHeight))
        path.addQuadCurve(to: CGPoint(x: 0, y: -halfHeight), control: CGPoint(x: halfWidth * 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: halfHeight), control: CGPoint(x: -halfWidth * 2, y: 0))
        path.closeSubpath()
        return path
    }
}
