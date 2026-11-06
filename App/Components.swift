import SwiftUI
import UIKit

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

enum HapticsHelper {
    static func poke() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            let light = UIImpactFeedbackGenerator(style: .rigid)
            light.impactOccurred()
        }
    }

    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
