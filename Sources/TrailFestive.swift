import AppKit

enum TrailFestive {
    static func drawConfetti(_ ctx: CGContext, color: NSColor) {
        paint(ctx, color: color) { ctx, color in
            ctx.rotate(by: 18 * .pi / 180)
            let paper = CGRect(x: -19, y: -26, width: 38, height: 52)
            let body = CGPath(roundedRect: paper, cornerWidth: 5, cornerHeight: 5, transform: nil)
            ctx.addPath(body)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()

            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            let fold = color.blended(withFraction: 0.38, of: .white) ?? color
            ctx.setFillColor(fold.cgColor)
            ctx.fill(CGRect(x: -19, y: -26, width: 8, height: 52))
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.34).cgColor)
            ctx.fill(CGRect(x: -19, y: -26, width: 3, height: 52))
            let shade = color.blended(withFraction: 0.14, of: .black) ?? color
            ctx.setFillColor(shade.withAlphaComponent(0.22).cgColor)
            ctx.fill(CGRect(x: 16, y: -26, width: 3, height: 52))
            ctx.restoreGState()
        }
    }

    static func drawNote(_ ctx: CGContext, color: NSColor) {
        paint(ctx, color: color) { ctx, color in
            ctx.setFillColor(color.cgColor)

            let stem = CGPath(
                roundedRect: CGRect(x: -2.5, y: -18, width: 9, height: 50),
                cornerWidth: 4.5, cornerHeight: 4.5, transform: nil
            )
            ctx.addPath(stem)
            ctx.fillPath()

            let flag = CGMutablePath()
            flag.move(to: CGPoint(x: 5.5, y: 32))
            flag.addCurve(
                to: CGPoint(x: 32, y: 16),
                control1: CGPoint(x: 18, y: 34),
                control2: CGPoint(x: 32, y: 28)
            )
            flag.addCurve(
                to: CGPoint(x: 22, y: -1),
                control1: CGPoint(x: 32, y: 8),
                control2: CGPoint(x: 28, y: 2)
            )
            flag.addCurve(
                to: CGPoint(x: 8, y: 14),
                control1: CGPoint(x: 14, y: -4),
                control2: CGPoint(x: 12, y: 6)
            )
            flag.addQuadCurve(to: CGPoint(x: 5.5, y: 27), control: CGPoint(x: 6, y: 19))
            flag.closeSubpath()
            ctx.addPath(flag)
            ctx.fillPath()

            ctx.saveGState()
            ctx.translateBy(x: -9, y: -17)
            ctx.rotate(by: -0.38)
            ctx.fillEllipse(in: CGRect(x: -14, y: -10, width: 28, height: 20))
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.58).cgColor)
            ctx.fillEllipse(in: CGRect(x: -8, y: 0, width: 10, height: 7))
            ctx.restoreGState()
        }
    }

    static func drawMoon(_ ctx: CGContext, color: NSColor) {
        paint(ctx, color: color) { ctx, color in
            let main = CGRect(x: -24, y: -40, width: 72, height: 72)
            let cut = CGRect(x: 2, y: -22, width: 60, height: 60)

            ctx.saveGState()
            ctx.addEllipse(in: main)
            ctx.clip()
            ctx.addEllipse(in: main)
            ctx.addEllipse(in: cut)
            ctx.clip(using: .evenOdd)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: main)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: -16, y: -8, width: 16, height: 22))
            ctx.restoreGState()

            let sparkle = color.blended(withFraction: 0.32, of: .white) ?? color
            ctx.setFillColor(sparkle.cgColor)
            ctx.addPath(star(at: CGPoint(x: 29, y: 27), outer: 12, inner: 4))
            ctx.fillPath()
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.addPath(star(at: CGPoint(x: 29, y: 27), outer: 5, inner: 1.6))
            ctx.fillPath()
        }
    }

    private static func paint(_ ctx: CGContext, color: NSColor, _ draw: (CGContext, NSColor) -> Void) {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 4, color: color.withAlphaComponent(0.48).cgColor)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        draw(ctx, color)
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    private static func star(at center: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<8 {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 4
            let radius = i.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
