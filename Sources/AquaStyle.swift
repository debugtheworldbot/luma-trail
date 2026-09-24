import AppKit

// The settings mockup is drawn at 1.5× points; layouts quote its pixels and convert once here.
func dp(_ value: CGFloat) -> CGFloat { value / 1.5 }

// Places a label by the design-space centre of its glyphs; x is the leading (or trailing) glyph edge.
func place(_ field: NSTextField, x: CGFloat, centerY: CGFloat, trailing: Bool = false, width: CGFloat? = nil) {
    field.sizeToFit()
    let w = width ?? field.frame.width, h = field.frame.height
    field.frame = NSRect(x: trailing ? dp(x) - w + 2 : dp(x) - 2, y: dp(centerY) - h / 2, width: w, height: h)
}

// Shared pink Aqua drawing keeps native control tracking, keyboard actions and accessibility.
enum AquaStyle {
    static let ink = NSColor(hex: 0x251F23)
    static let soft = NSColor(hex: 0xAD94A0)
    static let line = NSColor(hex: 0xCDBFC6)
    static let rim = NSColor(hex: 0x9B8691)
    static let pinkRim = NSColor(hex: 0xAB537E)
    static let background = NSColor(hex: 0xF7F5F6)

    static let whiteGloss = gradient([0xFEFDFE, 0xF5F4F5, 0xEAE5E8, 0xEDE9EB, 0xF5F2F3, 0xFDFCFC], [0, 0.22, 0.42, 0.5, 0.72, 1])
    static let pinkGloss = gradient([0xFFE5F2, 0xFFCBE5, 0xFFB3D8, 0xFFBEDE, 0xFFD5E9, 0xFFEDF5], [0, 0.22, 0.42, 0.52, 0.75, 1])
    static let header = gradient([0xFEFEFE, 0xF7F5F6, 0xEFEBED], [0, 0.5, 1])

    static func gradient(_ colors: [Int], _ stops: [CGFloat]) -> NSGradient {
        var locations = stops
        return NSGradient(colors: colors.map { NSColor(hex: $0) }, atLocations: &locations, colorSpace: .sRGB)!
    }

    // Draws in unflipped coordinates, gloss running from the top edge down over a hairline shadow.
    static func glass(_ rect: NSRect, pink: Bool = false, pressed: Bool = false, radius: CGFloat = 4, rim border: NSColor? = nil) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = line
        shadow.shadowBlurRadius = 0; shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set(); NSColor.white.setFill(); path.fill()
        NSGraphicsContext.restoreGraphicsState()
        (pink ? pinkGloss : whiteGloss).draw(in: path, angle: -90)
        if pressed { NSColor(hex: 0x6B4A5B).withAlphaComponent(0.14).setFill(); path.fill() }
        (border ?? (pink ? pinkRim : rim)).setStroke(); path.lineWidth = 1; path.stroke()
    }

    static func jelly(_ path: NSBezierPath, flipped: Bool = false, rim border: NSColor = pinkRim) {
        pinkGloss.draw(in: path, angle: flipped ? 90 : -90)
        border.setStroke(); path.lineWidth = 1; path.stroke()
    }

    // Unflipped heart with its tip at the bottom of the rect.
    static func heart(in r: NSRect) -> NSBezierPath {
        let p = NSBezierPath(), x = r.minX, y = r.minY, w = r.width, h = r.height
        p.move(to: NSPoint(x: x + w / 2, y: y))
        p.curve(to: NSPoint(x: x, y: y + h * 0.66), controlPoint1: NSPoint(x: x + w * 0.36, y: y + h * 0.2), controlPoint2: NSPoint(x: x, y: y + h * 0.42))
        p.curve(to: NSPoint(x: x + w / 2, y: y + h * 0.8), controlPoint1: NSPoint(x: x, y: y + h * 1.04), controlPoint2: NSPoint(x: x + w * 0.44, y: y + h * 1.06))
        p.curve(to: NSPoint(x: x + w, y: y + h * 0.66), controlPoint1: NSPoint(x: x + w * 0.56, y: y + h * 1.06), controlPoint2: NSPoint(x: x + w, y: y + h * 1.04))
        p.curve(to: NSPoint(x: x + w / 2, y: y), controlPoint1: NSPoint(x: x + w, y: y + h * 0.42), controlPoint2: NSPoint(x: x + w * 0.64, y: y + h * 0.2))
        p.close(); return p
    }

    // Four-point star with concave sides, symmetric so it reads the same flipped or not.
    static func sparkle(in r: NSRect) -> NSBezierPath {
        let c = NSPoint(x: r.midX, y: r.midY), k: CGFloat = 0.4
        let tips = [NSPoint(x: c.x, y: r.maxY), NSPoint(x: r.maxX, y: c.y), NSPoint(x: c.x, y: r.minY), NSPoint(x: r.minX, y: c.y)]
        func pull(_ p: NSPoint) -> NSPoint { NSPoint(x: c.x + (p.x - c.x) * k, y: c.y + (p.y - c.y) * k) }
        let p = NSBezierPath(); p.move(to: tips[0])
        for i in 0..<4 { let a = tips[i], b = tips[(i + 1) % 4]; p.curve(to: b, controlPoint1: pull(a), controlPoint2: pull(b)) }
        p.close(); return p
    }

    static func install(in view: NSView) {
        for child in view.subviews {
            if let slider = child as? NSSlider, !(slider.cell is AquaSliderCell) {
                let value = slider.doubleValue, low = slider.minValue, high = slider.maxValue
                let target = slider.target, action = slider.action
                slider.cell = AquaSliderCell()
                slider.minValue = low; slider.maxValue = high; slider.doubleValue = value
                slider.target = target; slider.action = action; slider.isContinuous = true
            } else if let popup = child as? NSPopUpButton {
                let menu = popup.menu, selected = popup.indexOfSelectedItem
                let target = popup.target, action = popup.action
                popup.cell = AquaPopupCell(textCell: "", pullsDown: false)
                popup.menu = menu; popup.selectItem(at: selected); popup.target = target; popup.action = action
            } else if let button = child as? NSButton, type(of: button) == NSButton.self {
                // Custom-drawn NSButton subclasses keep their own appearance.
                let title = button.title, state = button.state, font = button.font
                let target = button.target, action = button.action
                let kind = button.identifier?.rawValue ?? ""
                let cell = AquaButtonCell(textCell: title)
                cell.checkbox = kind == "aquaCheckbox"
                cell.tab = kind.hasPrefix("aquaTab")
                cell.pink = kind == "aquaTabOn" || title.contains("开启") || title.contains("应用")
                cell.setButtonType(cell.checkbox ? .switch : .momentaryPushIn)
                button.cell = cell; button.title = title; button.state = state; button.font = font
                button.target = target; button.action = action
            }
            install(in: child)
        }
    }
}

final class AquaButtonCell: NSButtonCell {
    var checkbox = false, tab = false, pink = false
    override func draw(withFrame frame: NSRect, in view: NSView) {
        // Draw in an unflipped coordinate system for consistent top highlights.
        NSGraphicsContext.saveGraphicsState()
        if view.isFlipped {
            var transform = AffineTransform(translationByX: 0, byY: frame.minY + frame.maxY)
            transform.scale(x: 1, y: -1); (transform as NSAffineTransform).concat()
        }
        let box = dp(21)
        let rect = checkbox ? NSRect(x: frame.minX + 0.5, y: frame.midY - box / 2, width: box, height: box)
            : NSRect(x: frame.minX + 0.5, y: frame.minY + 1.5, width: frame.width - 1, height: frame.height - 2)
        let on = checkbox && state == .on
        AquaStyle.glass(rect, pink: pink || on, pressed: isHighlighted, radius: checkbox ? 3 : tab ? 4 : min(12, rect.height / 2),
                        rim: checkbox ? (on ? AquaStyle.pinkRim : AquaStyle.rim) : AquaStyle.rim)
        if on {
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: rect.minX + 3.2, y: rect.midY + 0.6))
            tick.line(to: NSPoint(x: rect.minX + 6.2, y: rect.minY + 2.6))
            tick.line(to: NSPoint(x: rect.maxX - 1.4, y: rect.maxY + 1.2))
            NSColor(hex: 0x3D192B).setStroke(); tick.lineWidth = 1.6; tick.lineJoinStyle = .round; tick.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let attrs: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 12),
                                                    .foregroundColor: isEnabled ? AquaStyle.ink : NSColor.disabledControlTextColor]
        let text = title as NSString, size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: checkbox ? frame.minX + dp(33) : frame.midX - size.width / 2, y: frame.midY - size.height / 2 - (view.isFlipped ? 0.5 : -0.5)), withAttributes: attrs)
        if showsFirstResponder { NSFocusRingPlacement.only.set(); NSBezierPath(roundedRect: checkbox ? rect : frame.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill() }
    }
}

final class AquaSliderCell: NSSliderCell {
    static let knob = NSSize(width: dp(24), height: dp(30))
    override var knobThickness: CGFloat { Self.knob.width }
    private var knobTop: CGFloat { ((controlView?.bounds.height ?? Self.knob.height) - Self.knob.height) / 2 }
    override func barRect(flipped: Bool) -> NSRect {
        let bounds = controlView?.bounds ?? .zero, top = knobTop + dp(4), height = dp(10)
        return NSRect(x: bounds.minX, y: flipped ? top : bounds.height - top - height, width: bounds.width, height: height)
    }
    override func knobRect(flipped: Bool) -> NSRect {
        let bounds = controlView?.bounds ?? .zero
        let fraction = CGFloat((doubleValue - minValue) / max(0.0001, maxValue - minValue))
        let y = flipped ? knobTop : bounds.height - knobTop - Self.knob.height
        return NSRect(x: bounds.minX + fraction * (bounds.width - Self.knob.width), y: y, width: Self.knob.width, height: Self.knob.height)
    }
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: track, xRadius: track.height / 2, yRadius: track.height / 2)
        NSGradient(starting: NSColor(hex: 0xE5DFE2), ending: NSColor(hex: 0xF6F3F4))?.draw(in: path, angle: flipped ? 90 : -90)
        AquaStyle.line.setStroke(); path.lineWidth = 1; path.stroke()
    }
    override func drawKnob(_ rect: NSRect) {
        // A shield: rounded shoulders on top of the track, pointing at the tick marks.
        let flipped = controlView?.isFlipped == true, r = rect.insetBy(dx: 0.5, dy: 0.5)
        let top = flipped ? r.minY : r.maxY, down: CGFloat = flipped ? 1 : -1, corner: CGFloat = 3.5
        func point(_ x: CGFloat, _ depth: CGFloat) -> NSPoint { NSPoint(x: x, y: top + down * depth) }
        let path = NSBezierPath()
        path.move(to: point(r.midX, r.height))
        path.line(to: point(r.minX, r.height * 0.58))
        path.line(to: point(r.minX, corner))
        path.curve(to: point(r.minX + corner, 0), controlPoint1: point(r.minX, 0), controlPoint2: point(r.minX, 0))
        path.line(to: point(r.maxX - corner, 0))
        path.curve(to: point(r.maxX, corner), controlPoint1: point(r.maxX, 0), controlPoint2: point(r.maxX, 0))
        path.line(to: point(r.maxX, r.height * 0.58))
        path.close(); path.lineJoinStyle = .round
        AquaStyle.jelly(path, flipped: flipped)
        if isHighlighted { NSColor(hex: 0x6B4A5B).withAlphaComponent(0.12).setFill(); path.fill() }
    }
}

final class AquaPopupCell: NSPopUpButtonCell {
    override func drawBezel(withFrame frame: NSRect, in view: NSView) {
        NSGraphicsContext.saveGraphicsState()
        if view.isFlipped {
            var transform = AffineTransform(translationByX: 0, byY: frame.minY + frame.maxY)
            transform.scale(x: 1, y: -1); (transform as NSAffineTransform).concat()
        }
        AquaStyle.glass(NSRect(x: frame.minX + 2.5, y: frame.minY + 3.5, width: frame.width - 5, height: frame.height - 7), pressed: isHighlighted, radius: 5)
        NSGraphicsContext.restoreGraphicsState()
    }
}

// White rounded panel; a title adds the glossy header strip with a pink sparkle.
final class AquaGroup: NSView {
    static let headerHeight = dp(41)
    let titled: Bool
    init(title: String? = nil) {
        titled = title != nil
        super.init(frame: .zero)
        if let title {
            let heading = label(title, 10.5)
            place(heading, x: 46, centerY: 20.5); addSubview(heading)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        NSColor.white.setFill(); path.fill()
        if titled {
            NSGraphicsContext.saveGraphicsState(); path.addClip()
            AquaStyle.header.draw(in: NSRect(x: 0, y: 0, width: bounds.width, height: Self.headerHeight), angle: 90)
            AquaStyle.line.setFill(); NSRect(x: 0, y: Self.headerHeight, width: bounds.width, height: dp(1)).fill()
            NSGraphicsContext.restoreGraphicsState()
            let star = AquaStyle.sparkle(in: NSRect(x: dp(15), y: dp(11), width: dp(20), height: dp(20)))
            AquaStyle.jelly(star, flipped: true, rim: NSColor(hex: 0xD0679F))
        }
        AquaStyle.line.setStroke(); path.lineWidth = 1; path.stroke()
    }
}
