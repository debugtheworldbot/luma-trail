import AppKit

enum TrailNature {
    static func drawSakura(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.rotate(by: 0.34)
        ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor(color.cgColor)
        let petal = CGMutablePath()
        petal.move(to: CGPoint(x: 0, y: -40))
        petal.addCurve(to: CGPoint(x: -22, y: 24), control1: CGPoint(x: -12, y: -24), control2: CGPoint(x: -40, y: 2))
        petal.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: -26, y: 44), control2: CGPoint(x: -10, y: 32))
        petal.addCurve(to: CGPoint(x: 22, y: 24), control1: CGPoint(x: 10, y: 32), control2: CGPoint(x: 26, y: 44))
        petal.addCurve(to: CGPoint(x: 0, y: -40), control1: CGPoint(x: 40, y: 2), control2: CGPoint(x: 12, y: -24))
        petal.closeSubpath()
        ctx.addPath(petal)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(petal)
        ctx.clip()
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor((color.blended(withFraction: 0.65, of: .white) ?? color).withAlphaComponent(0.72).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16, y: -10, width: 14, height: 20))
        ctx.setStrokeColor((color.blended(withFraction: 0.3, of: NSColor(srgbRed: 0.5, green: 0.16, blue: 0.3, alpha: 1)) ?? color).withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 0, y: -28))
        ctx.addQuadCurve(to: CGPoint(x: 0.6, y: 2), control: CGPoint(x: -2.6, y: -12))
        ctx.strokePath()
        ctx.restoreGState()
        ctx.restoreGState()
    }

    static func drawMaple(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.rotate(by: -0.1)
        ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.52).cgColor)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(3.2)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 0, y: -6))
        ctx.addQuadCurve(to: CGPoint(x: 5, y: -46), control: CGPoint(x: -4, y: -28))
        ctx.strokePath()
        ctx.setFillColor(color.cgColor)
        let lobes: [(CGFloat, CGFloat, CGFloat)] = [(-1.08, 40, 19), (0, 50, 15), (1.08, 40, 19)]
        for (angle, length, width) in lobes {
            ctx.saveGState()
            ctx.rotate(by: angle)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: -4))
            path.addCurve(to: CGPoint(x: 0, y: length),
                          control1: CGPoint(x: -width, y: length * 0.2),
                          control2: CGPoint(x: -width * 0.32, y: length * 0.86))
            path.addCurve(to: CGPoint(x: 0, y: -4),
                          control1: CGPoint(x: width * 0.32, y: length * 0.86),
                          control2: CGPoint(x: width, y: length * 0.2))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.endTransparencyLayer()
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.saveGState()
        ctx.rotate(by: -1.08)
        ctx.setFillColor((color.blended(withFraction: 0.58, of: .white) ?? color).withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: CGRect(x: -8, y: 14, width: 11, height: 16))
        ctx.restoreGState()
        ctx.restoreGState()
    }

    static func drawDandelion(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.rotate(by: 0.08)
        let pale = color.blended(withFraction: 0.45, of: .white) ?? color
        ctx.setShadow(offset: .zero, blur: 4, color: color.withAlphaComponent(0.45).cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: -5, y: -50, width: 10, height: 13))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.8)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 0, y: -38))
        ctx.addLine(to: CGPoint(x: 0, y: 2))
        ctx.strokePath()
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: -2.6, y: -2.6, width: 5.2, height: 5.2))
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor((color.blended(withFraction: 0.55, of: .white) ?? color).withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: CGRect(x: -2.4, y: -47, width: 4.2, height: 5))
        ctx.setLineWidth(0.8)
        let count = 10
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let angle = Double.pi / 2 - 1.18 + t * 2.36
            let reach: CGFloat = 46
            let tip = CGPoint(x: CGFloat(cos(angle)) * reach, y: CGFloat(sin(angle)) * reach)
            let sway = (t - 0.5) * 9
            let control = CGPoint(x: CGFloat(cos(angle)) * reach * 0.42 + sway,
                                  y: CGFloat(sin(angle)) * reach * 0.55)
            ctx.setStrokeColor(pale.withAlphaComponent(0.8).cgColor)
            ctx.move(to: .zero)
            ctx.addQuadCurve(to: tip, control: control)
            ctx.strokePath()
            ctx.setFillColor((color.blended(withFraction: 0.55, of: .white) ?? color).withAlphaComponent(0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: tip.x - 1.5, y: tip.y - 1.5, width: 3, height: 3))
        }
        ctx.restoreGState()
    }

    static func drawFeather(_ ctx: CGContext, color: NSColor) {
        ctx.saveGState()
        ctx.rotate(by: 0.2)
        ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.5).cgColor)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(color.cgColor)
        for i in 0..<10 {
            let t = Double(i) / 9.0
            let y = -30 + t * 76
            let x = 2.2 * t * t
            let lenL = 10 + 18 * sin(t * .pi)
            let lenR = 7 + 12 * sin(t * .pi)
            for (side, len) in [(-1.0, lenL), (1.0, lenR)] {
                let barb = CGMutablePath()
                barb.move(to: CGPoint(x: x, y: y - 2.2))
                barb.addLine(to: CGPoint(x: x, y: y + 2.2))
                barb.addQuadCurve(to: CGPoint(x: x + side * len, y: y + 4),
                                  control: CGPoint(x: x + side * len * 0.5, y: y + 3.4))
                barb.addQuadCurve(to: CGPoint(x: x, y: y - 2.2),
                                  control: CGPoint(x: x + side * len * 0.52, y: y - 2.2))
                barb.closeSubpath()
                ctx.addPath(barb)
                ctx.fillPath()
            }
        }
        ctx.endTransparencyLayer()
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor(NSColor(srgbRed: 1, green: 0.98, blue: 0.93, alpha: 0.52).cgColor)
        for i in 0..<10 {
            let t = Double(i) / 9.0
            let y = -30 + t * 76
            let x = 2.2 * t * t
            let len = (10 + 18 * sin(t * .pi)) * 0.55
            let barb = CGMutablePath()
            barb.move(to: CGPoint(x: x - 0.2, y: y - 1.2))
            barb.addLine(to: CGPoint(x: x - 0.2, y: y + 1.4))
            barb.addQuadCurve(to: CGPoint(x: x - len, y: y + 2.8),
                              control: CGPoint(x: x - len * 0.5, y: y + 2.8))
            barb.addQuadCurve(to: CGPoint(x: x - 0.2, y: y - 1.2),
                              control: CGPoint(x: x - len * 0.5, y: y - 1.6))
            barb.closeSubpath()
            ctx.addPath(barb)
            ctx.fillPath()
        }
        let shaft = CGMutablePath()
        shaft.move(to: CGPoint(x: -2.2, y: -50))
        shaft.addQuadCurve(to: CGPoint(x: -1.0, y: 48), control: CGPoint(x: 1.6, y: 0))
        shaft.addLine(to: CGPoint(x: 1.6, y: 48))
        shaft.addQuadCurve(to: CGPoint(x: 2.2, y: -50), control: CGPoint(x: 4.2, y: 0))
        shaft.closeSubpath()
        ctx.setFillColor((color.blended(withFraction: 0.18, of: NSColor(srgbRed: 0.55, green: 0.4, blue: 0.28, alpha: 1)) ?? color).cgColor)
        ctx.addPath(shaft)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(1.05)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: -0.4, y: -42))
        ctx.addQuadCurve(to: CGPoint(x: 0.2, y: 40), control: CGPoint(x: 2.4, y: 0))
        ctx.strokePath()
        ctx.restoreGState()
    }
}
