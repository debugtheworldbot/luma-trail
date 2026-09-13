import AppKit

// Shared Aqua drawing keeps native control tracking, keyboard actions and accessibility.
enum AquaStyle {
    static let blue = NSColor(hex: 0x2879CD)
    static let ink = NSColor(hex: 0x243D54)

    static func glass(_ rect: NSRect, blue: Bool = false, pressed: Bool = false, radius: CGFloat = 9) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.23)
        shadow.shadowBlurRadius = 2; shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set(); NSColor.white.setFill(); path.fill()
        NSGraphicsContext.restoreGraphicsState()
        let colors = blue ? [0xB6EEFF, 0x439CE8, 0x176AC3, 0xD5F3FF] : [0xFFFFFF, 0xD6EEF2, 0xB2CED9, 0xFFFFFF]
        NSGradient(colors: colors.map { NSColor(hex: $0) })?.draw(in: path, angle: 90)
        if pressed { NSColor(hex: 0x174979).withAlphaComponent(0.22).setFill(); path.fill() }
        let gleam = NSBezierPath(roundedRect: NSRect(x: rect.minX + 2, y: rect.midY, width: rect.width - 4, height: rect.height / 2 - 1), xRadius: radius - 2, yRadius: radius - 2)
        NSGradient(starting: .white.withAlphaComponent(0.15), ending: .white.withAlphaComponent(0.85))?.draw(in: gleam, angle: 90)
        (blue ? NSColor(hex: 0x316AA5) : NSColor(hex: 0x8998A5)).setStroke(); path.lineWidth = 1; path.stroke()
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
            } else if let button = child as? NSButton, !(button is ThemeButton), !(button is AquaWindowButton) {
                let title = button.title, state = button.state, font = button.font
                let target = button.target, action = button.action
                let checkbox = button.identifier?.rawValue == "aquaCheckbox"
                let cell = AquaButtonCell(textCell: title)
                cell.checkbox = checkbox
                cell.setButtonType(checkbox ? .switch : .momentaryPushIn)
                button.cell = cell; button.title = title; button.state = state; button.font = font
                button.target = target; button.action = action
            }
            install(in: child)
        }
    }
}

final class AquaButtonCell: NSButtonCell {
    var checkbox = false
    override func draw(withFrame frame: NSRect, in view: NSView) {
        // Draw in an unflipped coordinate system for consistent top highlights.
        NSGraphicsContext.saveGraphicsState()
        if view.isFlipped {
            var transform = AffineTransform(translationByX: 0, byY: frame.minY + frame.maxY)
            transform.scale(x: 1, y: -1); (transform as NSAffineTransform).concat()
        }
        let rect = checkbox ? NSRect(x: frame.minX + 2, y: frame.midY - 7, width: 14, height: 14) : frame.insetBy(dx: 3, dy: 3)
        AquaStyle.glass(rect, blue: checkbox ? state == .on : title.contains("开启") || title.contains("应用"), pressed: isHighlighted, radius: checkbox ? 3 : 10)
        if checkbox && state == .on {
            let tick = NSBezierPath(); tick.move(to: NSPoint(x: rect.minX + 3, y: rect.midY)); tick.line(to: NSPoint(x: rect.minX + 6, y: rect.minY + 3)); tick.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - 3))
            NSColor(hex: 0x123E6A).setStroke(); tick.lineWidth = 2; tick.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = .white.withAlphaComponent(0.9); shadow.shadowOffset = NSSize(width: 0, height: -1)
        let attrs: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 12), .foregroundColor: isEnabled ? AquaStyle.ink : NSColor.disabledControlTextColor, .shadow: shadow]
        let text = title as NSString, size = (title as NSString).size(withAttributes: attrs)
        text.draw(at: NSPoint(x: checkbox ? frame.minX + 23 : frame.midX - size.width / 2, y: frame.midY - size.height / 2), withAttributes: attrs)
        if showsFirstResponder { NSFocusRingPlacement.only.set(); NSBezierPath(roundedRect: frame.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8).fill() }
    }
}

final class AquaSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = NSRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6)
        let path = NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3)
        NSGradient(starting: NSColor(hex: 0x8696A5), ending: .white)?.draw(in: path, angle: flipped ? 90 : -90)
        NSColor(hex: 0x82909C).setStroke(); path.stroke()
        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
        let fill = NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY + 1, width: track.width * fraction, height: 4), xRadius: 2, yRadius: 2)
        AquaStyle.blue.setFill(); fill.fill()
    }
    override func drawKnob(_ rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        if controlView?.isFlipped == true {
            var transform = AffineTransform(translationByX: 0, byY: rect.minY + rect.maxY)
            transform.scale(x: 1, y: -1); (transform as NSAffineTransform).concat()
        }
        AquaStyle.glass(rect.insetBy(dx: 1, dy: 1), blue: true, pressed: isHighlighted, radius: rect.height / 2)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class AquaPopupCell: NSPopUpButtonCell {
    override func drawBezel(withFrame frame: NSRect, in view: NSView) {
        NSGraphicsContext.saveGraphicsState()
        if view.isFlipped {
            var transform = AffineTransform(translationByX: 0, byY: frame.minY + frame.maxY)
            transform.scale(x: 1, y: -1); (transform as NSAffineTransform).concat()
        }
        AquaStyle.glass(frame.insetBy(dx: 2, dy: 3), pressed: isHighlighted, radius: 6)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class AquaGroup: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9)
        NSGradient(starting: NSColor(hex: 0xF5FDFF).withAlphaComponent(0.8), ending: NSColor(hex: 0xD9EDF0).withAlphaComponent(0.8))?.draw(in: path, angle: 90)
        NSColor(hex: 0xA1AFBC).setStroke(); path.stroke()
        let inset = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        NSColor.white.setStroke(); inset.stroke()
    }
}

// Procedural scenery adds an early Aero atmosphere without image assets or timers.
enum AeroScenery {
    static func bubble(_ rect: NSRect) {
        let circle = NSBezierPath(ovalIn: rect)
        NSGradient(starting: NSColor.white.withAlphaComponent(0.03), ending: NSColor.white.withAlphaComponent(0.45))?.draw(in: circle, angle: 90)
        NSColor.white.withAlphaComponent(0.75).setStroke(); circle.lineWidth = 1; circle.stroke()
        let shine = NSBezierPath()
        shine.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY), radius: rect.width * 0.39, startAngle: 55, endAngle: 135)
        NSColor.white.withAlphaComponent(0.9).setStroke(); shine.lineWidth = 2; shine.stroke()
    }

    static func landscape(in bounds: NSRect) {
        let w = bounds.width, h = bounds.height
        let sun = NSRect(x: w * 0.68, y: h * 0.59, width: h * 0.7, height: h * 0.7)
        NSGradient(starting: NSColor.white.withAlphaComponent(0.75), ending: NSColor.white.withAlphaComponent(0))?.draw(in: NSBezierPath(ovalIn: sun), relativeCenterPosition: .zero)
        for (offset, color) in [(CGFloat(0.12), 0x9DD369), (CGFloat(0.02), 0x66B65E)] {
            let hill = NSBezierPath(); hill.move(to: .zero)
            hill.line(to: NSPoint(x: 0, y: h * (0.16 + offset)))
            hill.curve(to: NSPoint(x: w, y: h * (0.13 + offset)), controlPoint1: NSPoint(x: w * 0.38, y: h * (0.52 + offset)), controlPoint2: NSPoint(x: w * 0.65, y: -h * 0.08))
            hill.line(to: NSPoint(x: w, y: 0)); hill.close()
            NSGradient(starting: NSColor(hex: color).withAlphaComponent(0.5), ending: NSColor(hex: 0xDDF4BB).withAlphaComponent(0.85))?.draw(in: hill, angle: 90)
        }
        bubble(NSRect(x: w * 0.81, y: h * 0.48, width: 37, height: 37))
        bubble(NSRect(x: w * 0.9, y: h * 0.7, width: 18, height: 18))
    }
}
