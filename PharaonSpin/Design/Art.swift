import SwiftUI
import UIKit

/// Every raster image set exported from Figma (see Assets.md for the node of each).
enum ArtName: String, CaseIterable {
    case bgMenu = "bg_menu", bgEgypt = "bg_egypt", bgFruit = "bg_fruit", bgWheel = "bg_wheel"
    case bgLoading = "bg_loading", bgOffline = "bg_offline", bgNotifications = "bg_notifications"

    case egyptS1 = "egypt_s1", egyptS2 = "egypt_s2", egyptS3 = "egypt_s3", egyptS4 = "egypt_s4", egyptS5 = "egypt_s5"
    case egyptS6 = "egypt_s6", egyptS7 = "egypt_s7", egyptS8 = "egypt_s8", egyptS9 = "egypt_s9"
    case egyptWild = "egypt_wild", egyptScatter = "egypt_scatter"
    case fruitS1 = "fruit_s1", fruitS2 = "fruit_s2", fruitS3 = "fruit_s3", fruitS4 = "fruit_s4", fruitS5 = "fruit_s5"
    case fruitS6 = "fruit_s6", fruitS7 = "fruit_s7", fruitS8 = "fruit_s8", fruitS9 = "fruit_s9"
    case fruitWild = "fruit_wild", fruitScatter = "fruit_scatter"

    case reelFrameEgypt = "reel_frame_egypt", reelFrameFruit = "reel_frame_fruit"
    case reelGlowEgypt = "reel_glow_egypt", reelGlowFruit = "reel_glow_fruit"
    case emblemEgypt = "emblem_egypt", emblemFruit = "emblem_fruit", emblemWheel = "emblem_wheel"
    case menuEmblemEgypt = "menu_emblem_egypt", menuEmblemFruit = "menu_emblem_fruit", menuEmblemWheel = "menu_emblem_wheel"

    case wheelRing = "wheel_ring", wheelDisc = "wheel_disc", wheelPointer = "wheel_pointer", wheelGlow = "wheel_glow"

    case buttonSpin = "button_spin", buttonSpinDisabled = "button_spin_disabled"
    case buttonRoundRed = "button_round_red", buttonRoundGrey = "button_round_grey"
    case buttonMinus = "button_minus", buttonPlus = "button_plus"
    case buttonRedCircle = "button_red_circle", buttonRedBar = "button_red_bar"
    case buttonBlueBar = "button_blue_bar", buttonGreenBar = "button_green_bar"
    case buttonPlay = "button_play", buttonPlayDisabled = "button_play_disabled", menuGem = "menu_gem"
    case plateBet = "plate_bet", plateWin = "plate_win", plateBalance = "plate_balance"

    case settingsPanel = "settings_panel", settingsTitle = "settings_title"
    case toggleOn = "toggle_on", toggleOff = "toggle_off"
    case offlinePanel = "offline_panel"
    case loadingTitle = "loading_title", logo = "logo"
}

/// Decoded images, filled by the loading screen so gameplay never decodes on the main thread.
final class ArtLibrary {
    static let shared = ArtLibrary()

    private var cache: [ArtName: UIImage] = [:]
    private var missing: Set<ArtName> = []
    private let lock = NSLock()

    func image(_ name: ArtName) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        if let image = cache[name] { return image }
        if missing.contains(name) { return nil }
        guard let image = UIImage(named: name.rawValue) else {
            missing.insert(name)
            return nil
        }
        cache[name] = image
        return image
    }

    /// Loads and decodes one image off the main thread. Returns false when the set is absent.
    @discardableResult
    func preload(_ name: ArtName) -> Bool {
        guard let image = UIImage(named: name.rawValue) else {
            lock.lock()
            missing.insert(name)
            lock.unlock()
            return false
        }
        let decoded = image.preparingForDisplay() ?? image
        lock.lock()
        cache[name] = decoded
        lock.unlock()
        return true
    }
}

/// A Figma image, or a code-drawn stand-in while the image set is not in the catalog.
struct ArtImage<Fallback: View>: View {
    let name: ArtName
    var contentMode: ContentMode = .fit
    var capInsets: EdgeInsets?
    @ViewBuilder var fallback: () -> Fallback

    init(_ name: ArtName, contentMode: ContentMode = .fit, capInsets: EdgeInsets? = nil, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.name = name
        self.contentMode = contentMode
        self.capInsets = capInsets
        self.fallback = fallback
    }

    var body: some View {
        if let image = ArtLibrary.shared.image(name) {
            if let capInsets {
                Image(uiImage: image).resizable(capInsets: capInsets, resizingMode: .stretch)
            } else {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            }
        } else {
            fallback()
        }
    }
}

/// Full-bleed square background, cropped around the centre (or the bottom edge).
struct BackgroundArt: View {
    let name: ArtName
    var alignment: Alignment = .center
    var colors: [Color] = [Color(red: 0.2, green: 0.05, blue: 0.2), Color(red: 0.05, green: 0.02, blue: 0.1)]

    var body: some View {
        GeometryReader { geometry in
            let side = max(geometry.size.width, geometry.size.height)
            ArtImage(name, contentMode: .fill) {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            }
            .frame(width: side, height: side)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
            .clipped()
        }
        .ignoresSafeArea()
    }

    /// Where a rectangle given in background pixels (2400×2400) lands on screen, matching the crop above.
    static func screenRect(ofBackgroundRect rect: CGRect, in size: CGSize, alignment: Alignment) -> CGRect {
        let side = max(size.width, size.height)
        let scale = side / 2400
        let originX: CGFloat
        switch alignment.horizontal {
        case .leading: originX = 0
        case .trailing: originX = size.width - side
        default: originX = (size.width - side) / 2
        }
        let originY: CGFloat
        switch alignment.vertical {
        case .top: originY = 0
        case .bottom: originY = size.height - side
        default: originY = (size.height - side) / 2
        }
        return CGRect(x: originX + rect.minX * scale, y: originY + rect.minY * scale,
                      width: rect.width * scale, height: rect.height * scale)
    }
}
