import UIKit

/// Draws the GTA-style player arrow (white chevron with a dark outline and soft glow).
/// The image points north; the map layer rotates it to the travel bearing.
enum PlayerBlip {
    static func image(size: CGFloat = 40) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            let cg = ctx.cgContext
            let s = size
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: s * 0.5, y: s * 0.12))   // tip
            arrow.addLine(to: CGPoint(x: s * 0.80, y: s * 0.86))
            arrow.addLine(to: CGPoint(x: s * 0.5, y: s * 0.68)) // notch
            arrow.addLine(to: CGPoint(x: s * 0.20, y: s * 0.86))
            arrow.close()
            arrow.lineJoin = .round

            cg.setShadow(offset: .zero, blur: s * 0.15, color: UIColor.white.withAlphaComponent(0.6).cgColor)
            UIColor.white.setFill()
            arrow.fill()

            cg.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor(white: 0.05, alpha: 1).setStroke()
            arrow.lineWidth = s * 0.06
            arrow.stroke()
        }
    }
}
