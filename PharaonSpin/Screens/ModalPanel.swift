import SwiftUI

/// Dimmed backdrop + the Settings panel art, for every panel the Figma file does not draw
/// (disclosure, store, info, odds, reminders). Sized in design points on the canvas.
struct ModalPanel<Content: View>: View {
    let title: String
    var titleArt: ArtName?
    var width: (portrait: CGFloat, landscape: CGFloat) = (300, 520)
    var dismiss: (() -> Void)?
    @ViewBuilder var content: (CanvasMetrics) -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture { dismiss?() }
                .accessibilityHidden(true)

            DesignCanvas { m in
                let panelWidth = m.isLandscape ? width.landscape : width.portrait
                VStack(spacing: m(m.isLandscape ? 4 : 8)) {
                    header(m)
                    content(m)
                        .padding(.horizontal, m(20))
                        .padding(.vertical, m(20))
                        .frame(width: m(panelWidth))
                        .background(PanelBackground())
                }
                .frame(maxHeight: m(m.designSize.height - 16))
                .frame(width: m(m.designSize.width), height: m(m.designSize.height))
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private func header(_ m: CanvasMetrics) -> some View {
        ZStack {
            if let titleArt {
                ArtImage(titleArt) { GoldTitle(text: title, size: m(34)) }
                    .frame(height: m(m.isLandscape ? 44 : 70))
            } else {
                GoldTitle(text: title, size: m(m.isLandscape ? 26 : 32))
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if let dismiss {
                Button(action: dismiss) {
                    ZStack {
                        GoldRimCircle(fill: [Color(red: 1, green: 0.35, blue: 0.35), Palette.spinRed])
                        Image(systemName: "xmark").font(.system(size: m(14), weight: .black)).foregroundColor(.white)
                    }
                    .frame(width: m(36), height: m(36))
                }
                .buttonStyle(PressScale())
                .padding(.trailing, m(m.isLandscape ? 150 : 28))
                .accessibilityLabel("Close")
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A plain-text row used inside panels.
struct PanelText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .semibold
    var color: Color = .white

    var body: some View {
        Text(text)
            .font(.game(size, weight))
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
