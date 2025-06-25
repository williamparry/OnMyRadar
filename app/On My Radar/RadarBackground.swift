import SwiftUI

struct RadarBackground: View {
    @State private var rotationAngle: Double = 0
    @State private var isAnimating: Bool = false
    let shouldRotate: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = min(geometry.size.width, geometry.size.height) * 0.45
            
            ZStack {
                // Radar circles
                ForEach(1..<5) { i in
                    Circle()
                        .stroke(
                            Color.green.opacity(0.15 - Double(i) * 0.025),
                            lineWidth: 1
                        )
                        .frame(
                            width: maxRadius * Double(i) / 4 * 2,
                            height: maxRadius * Double(i) / 4 * 2
                        )
                        .position(center)
                }
                
                
                // Radar sweep that rotates as one unit
                ZStack {
                    // Trailing sweep gradient
                    ForEach(0..<20, id: \.self) { i in
                        Path { path in
                            path.move(to: center)
                            
                            // Create static wedge segments - starting at 0 degrees (3 o'clock)
                            let angle = 0.0 - Double(i) * 3
                            let nextAngle = angle - 3
                            
                            path.addArc(
                                center: center,
                                radius: maxRadius,
                                startAngle: .degrees(angle),
                                endAngle: .degrees(nextAngle),
                                clockwise: true
                            )
                            path.closeSubpath()
                        }
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.12 * (1.0 - Double(i) / 20.0)),
                                    Color.clear
                                ]),
                                center: UnitPoint(x: 0.5, y: 0.5),
                                startRadius: 0,
                                endRadius: maxRadius
                            )
                        )
                    }
                    
                    // Main radar line - pointing right (3 o'clock)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + maxRadius,
                            y: center.y
                        ))
                    }
                    .stroke(Color.green.opacity(0.15), lineWidth: 2)
                }
                .rotationEffect(.degrees(rotationAngle))
                .animation(.linear(duration: 4), value: rotationAngle)
            }
        }
        .onChange(of: shouldRotate) { _, newValue in
            if newValue && !isAnimating {
                isAnimating = true
                withAnimation(.linear(duration: 4)) {
                    rotationAngle += 360
                }
                
                // Reset animation flag after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    isAnimating = false
                }
            }
        }
    }
}

struct RadarBackground_Previews: PreviewProvider {
    static var previews: some View {
        RadarBackground(shouldRotate: false)
            .frame(width: 400, height: 600)
            .background(Color.black)
    }
}