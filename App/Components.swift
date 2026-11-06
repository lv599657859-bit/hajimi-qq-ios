import SwiftUI
import UIKit
import CoreHaptics

@MainActor
final class RemoteImageMemoryCache {
    static let shared = RemoteImageMemoryCache()
    private var cache: [String: UIImage] = [:]

    func get(_ url: String) -> UIImage? {
        cache[url]
    }

    func set(_ url: String, image: UIImage) {
        if cache.count > 80 {
            cache.removeAll()
        }
        cache[url] = image
    }

    func clear() {
        cache.removeAll()
    }
}

struct CachedAvatarImage<Placeholder: View>: View {
    let urlString: String
    let pairKey: String
    let size: CGFloat
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var loadedUrl: String = ""

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: urlString) {
            await loadIfNeeded()
        }
    }

    private func loadIfNeeded() async {
        guard !urlString.isEmpty else { return }
        if let cached = RemoteImageMemoryCache.shared.get(urlString) {
            uiImage = cached
            loadedUrl = urlString
            return
        }
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        if !pairKey.isEmpty {
            req.setValue(pairKey, forHTTPHeaderField: "x-hajimi-key")
        }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let decoded = UIImage(data: data) {
                RemoteImageMemoryCache.shared.set(urlString, image: decoded)
                uiImage = decoded
                loadedUrl = urlString
            }
        } catch {}
    }
}

enum ImageCompressionHelper {
    static func compressToJpegBase64(_ data: Data, maxDimension: CGFloat = 1280, quality: CGFloat = 0.85) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let w = image.size.width
        let h = image.size.height
        var targetSize = image.size
        if max(w, h) > maxDimension {
            let ratio = maxDimension / max(w, h)
            targetSize = CGSize(width: round(w * ratio), height: round(h * ratio))
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
        return jpeg.base64EncodedString()
    }
}

@MainActor
final class CatgirlHapticsManager {
    static let shared = CatgirlHapticsManager()
    private var engine: CHHapticEngine?

    private func ensureEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        if let existing = engine {
            try? existing.start()
            return existing
        }
        do {
            let created = try CHHapticEngine()
            created.isAutoShutdownEnabled = true
            created.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            try created.start()
            self.engine = created
            return created
        } catch {
            return nil
        }
    }

    /// Lifelike feline purring wave for headpats & naps, crispy 3-bite crunch for dried fish treats
    func playCareHaptic(action: String) {
        guard let eng = ensureEngine() else {
            HapticsHelper.poke()
            return
        }
        do {
            var events: [CHHapticEvent] = []
            var curves: [CHHapticParameterCurve] = []

            switch action {
            case "headpat", "nap_rest":
                // Warm 0.85s purring continuous rumble
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.48)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 0.85))
                curves.append(
                    CHHapticParameterCurve(
                        parameterID: .hapticIntensityControl,
                        controlPoints: [
                            .init(relativeTime: 0.0, value: 0.25),
                            .init(relativeTime: 0.28, value: 0.85),
                            .init(relativeTime: 0.55, value: 0.45),
                            .init(relativeTime: 0.85, value: 0.15)
                        ],
                        relativeTime: 0
                    )
                )
            case "feed_fish":
                // Three crisp freeze-dried fish crunches + happy tail purr
                for (i, t) in [0.0, 0.13, 0.27].enumerated() {
                    let inten = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.68 + Double(i) * 0.08))
                    let sharp = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.72)
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [inten, sharp], relativeTime: t))
                }
                events.append(
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.36),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                        ],
                        relativeTime: 0.36,
                        duration: 0.35
                    )
                )
            default:
                // Playful pounce double-bounce
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
                ], relativeTime: 0.0))
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.88),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.62)
                ], relativeTime: 0.11))
            }

            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try eng.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            HapticsHelper.poke()
        }
    }
}

enum HapticsHelper {
    static func poke() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            let light = UIImpactFeedbackGenerator(style: .rigid)
            light.impactOccurred()
        }
    }

    @MainActor
    static func care(action: String) {
        CatgirlHapticsManager.shared.playCareHaptic(action: action)
    }

    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
