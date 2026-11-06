import SwiftUI
import UIKit

enum CropMaskShape {
    case circle       // 1:1 Avatar circular cutout (User & Hajimi avatar)
    case portrait3x4  // 3:4 Vertical card cutout (Full-body portrait)
}

/// Telegram / Mobile QQ style interactive Pinch-to-Zoom + Pan + Rotate Image Cropper
struct ImageCropperSheet: View {
    let rawImage: UIImage
    let maskShape: CropMaskShape
    let title: String
    let outputMaxDimension: CGFloat
    let onConfirm: (Data) -> Void
    let onCancel: () -> Void

    @State private var normalizedImage: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var gestureBaseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var gestureBaseOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    init(
        rawImage: UIImage,
        maskShape: CropMaskShape = .circle,
        title: String = "移动和缩放",
        outputMaxDimension: CGFloat = 640,
        onConfirm: @escaping (Data) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.rawImage = rawImage
        self.maskShape = maskShape
        self.title = title
        self.outputMaxDimension = outputMaxDimension
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _normalizedImage = State(initialValue: Self.fixOrientation(rawImage))
    }

    var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let cropRect = computeCropRect(in: containerSize)
            let baseImgSize = computeBaseDisplayedImageSize(for: normalizedImage.size, cropSize: cropRect.size)

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: normalizedImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: baseImgSize.width, height: baseImgSize.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .contentShape(Rectangle())
                    .gesture(makeCombinedGesture(cropSize: cropRect.size, baseImgSize: baseImgSize))
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            if scale > 1.05 {
                                scale = 1.0
                                gestureBaseScale = 1.0
                                offset = .zero
                                gestureBaseOffset = .zero
                            } else {
                                scale = 2.2
                                gestureBaseScale = 2.2
                                clampOffset(cropSize: cropRect.size, baseImgSize: baseImgSize)
                            }
                        }
                    }

                CropCutoutMaskOverlay(cropRect: cropRect, maskShape: maskShape)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("双指缩放 · 单指拖动 · 双击放大")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: onCancel) {
                            Text("取消")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                normalizedImage = Self.rotate90Clockwise(normalizedImage)
                                scale = 1.0
                                gestureBaseScale = 1.0
                                offset = .zero
                                gestureBaseOffset = .zero
                            }
                        } label: {
                            Label("旋转", systemImage: "rotate.right")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.16))
                                .clipShape(Capsule())
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                scale = 1.0
                                gestureBaseScale = 1.0
                                offset = .zero
                                gestureBaseOffset = .zero
                            }
                        } label: {
                            Text("还原")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.88))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.16))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Button {
                            HapticsHelper.lightTap()
                            if let jpeg = renderCroppedJpeg(cropSize: cropRect.size, baseImgSize: baseImgSize) {
                                onConfirm(jpeg)
                            }
                        } label: {
                            Text("完成")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.0, green: 0.60, blue: 1.0))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.84))
                }
            }
        }
    }

    private func computeCropRect(in container: CGSize) -> CGRect {
        let usableW = max(200, container.width - 44)
        let usableH = max(220, container.height - 180)
        let cropSize: CGSize
        switch maskShape {
        case .circle:
            let d = min(min(usableW, usableH), 310)
            cropSize = CGSize(width: d, height: d)
        case .portrait3x4:
            var w = min(usableW, 300)
            var h = w * (4.0 / 3.0)
            if h > usableH {
                h = usableH
                w = h * 0.75
            }
            cropSize = CGSize(width: w, height: h)
        }
        return CGRect(
            x: (container.width - cropSize.width) / 2.0,
            y: (container.height - cropSize.height) / 2.0 - 10,
            width: cropSize.width,
            height: cropSize.height
        )
    }

    private func computeBaseDisplayedImageSize(for imgSize: CGSize, cropSize: CGSize) -> CGSize {
        let iw = max(1, imgSize.width)
        let ih = max(1, imgSize.height)
        let factor = max(cropSize.width / iw, cropSize.height / ih)
        return CGSize(width: iw * factor, height: ih * factor)
    }

    private func makeCombinedGesture(cropSize: CGSize, baseImgSize: CGSize) -> some Gesture {
        let magnify = MagnificationGesture()
            .onChanged { val in
                let proposed = gestureBaseScale * val
                scale = min(max(proposed, minScale * 0.85), maxScale)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    scale = min(max(scale, minScale), maxScale)
                    gestureBaseScale = scale
                    clampOffset(cropSize: cropSize, baseImgSize: baseImgSize)
                }
            }

        let drag = DragGesture()
            .onChanged { val in
                offset = CGSize(
                    width: gestureBaseOffset.width + val.translation.width,
                    height: gestureBaseOffset.height + val.translation.height
                )
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    clampOffset(cropSize: cropSize, baseImgSize: baseImgSize)
                }
            }

        return magnify.simultaneously(with: drag)
    }

    private func clampOffset(cropSize: CGSize, baseImgSize: CGSize) {
        let scaledW = baseImgSize.width * scale
        let scaledH = baseImgSize.height * scale
        let maxX = max(0, (scaledW - cropSize.width) / 2.0)
        let maxY = max(0, (scaledH - cropSize.height) / 2.0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        gestureBaseOffset = offset
    }

    private func renderCroppedJpeg(cropSize: CGSize, baseImgSize: CGSize) -> Data? {
        clampOffset(cropSize: cropSize, baseImgSize: baseImgSize)
        let aspect = cropSize.height / max(1, cropSize.width)
        let outW: CGFloat
        let outH: CGFloat
        if aspect >= 1.0 {
            outH = outputMaxDimension
            outW = round(outputMaxDimension / aspect)
        } else {
            outW = outputMaxDimension
            outH = round(outputMaxDimension * aspect)
        }

        let ratioX = outW / cropSize.width
        let ratioY = outH / cropSize.height

        let drawW = baseImgSize.width * scale * ratioX
        let drawH = baseImgSize.height * scale * ratioY
        let drawCenterX = (outW / 2.0) + (offset.width * ratioX)
        let drawCenterY = (outH / 2.0) + (offset.height * ratioY)
        let drawRect = CGRect(
            x: drawCenterX - drawW / 2.0,
            y: drawCenterY - drawH / 2.0,
            width: drawW,
            height: drawH
        )

        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: fmt)
        let cropped = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
            normalizedImage.draw(in: drawRect)
        }
        return cropped.jpegData(compressionQuality: 0.88)
    }

    static func fixOrientation(_ img: UIImage) -> UIImage {
        if img.imageOrientation == .up { return img }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = img.scale
        return UIGraphicsImageRenderer(size: img.size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
    }

    static func rotate90Clockwise(_ img: UIImage) -> UIImage {
        let newSize = CGSize(width: img.size.height, height: img.size.width)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = img.scale
        return UIGraphicsImageRenderer(size: newSize, format: fmt).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            cg.rotate(by: .pi / 2)
            img.draw(in: CGRect(x: -img.size.width / 2, y: -img.size.height / 2, width: img.size.width, height: img.size.height))
        }
    }
}

private struct CropCutoutMaskOverlay: View {
    let cropRect: CGRect
    let maskShape: CropMaskShape

    var body: some View {
        GeometryReader { proxy in
            let full = CGRect(origin: .zero, size: proxy.size)
            ZStack {
                Path { p in
                    p.addRect(full)
                    switch maskShape {
                    case .circle:
                        p.addEllipse(in: cropRect)
                    case .portrait3x4:
                        p.addRoundedRect(in: cropRect, cornerSize: CGSize(width: 18, height: 18))
                    }
                }
                .fill(Color.black.opacity(0.64), style: FillStyle(eoFill: true))

                switch maskShape {
                case .circle:
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.8)
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                case .portrait3x4:
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.8)
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                }
            }
        }
    }
}

struct FullScreenImageViewer: View {
    let imageUrl: String
    let localData: Data?
    let pairKey: String
    let onClose: () -> Void

    @State private var loadedImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var saveToast: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { v in scale = min(max(baseScale * v, 1.0), 5.0) }
                            .onEnded { _ in
                                baseScale = scale
                                if scale <= 1.02 {
                                    withAnimation(.spring()) { offset = .zero; baseOffset = .zero }
                                }
                            }
                            .simultaneously(with:
                                DragGesture()
                                    .onChanged { v in
                                        if scale > 1.02 {
                                            offset = CGSize(width: baseOffset.width + v.translation.width, height: baseOffset.height + v.translation.height)
                                        } else if v.translation.height > 90 {
                                            onClose()
                                        }
                                    }
                                    .onEnded { _ in baseOffset = offset }
                            )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.05 {
                                scale = 1.0; baseScale = 1.0; offset = .zero; baseOffset = .zero
                            } else {
                                scale = 2.5; baseScale = 2.5
                            }
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                }
                .padding()

                Spacer()

                if !saveToast.isEmpty {
                    Text(saveToast)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                }

                if let img = loadedImage {
                    HStack {
                        Spacer()
                        Button {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                            HapticsHelper.lightTap()
                            saveToast = "✅ 已保存到手机相册"
                        } label: {
                            Label("保存到相册", systemImage: "square.and.arrow.down")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.bottom, 22)
                }
            }
        }
        .task {
            if let d = localData, let ui = UIImage(data: d) {
                loadedImage = ui
                return
            }
            if let cached = RemoteImageMemoryCache.shared.get(imageUrl) {
                loadedImage = cached
                return
            }
            guard let u = URL(string: imageUrl) else { return }
            var req = URLRequest(url: u)
            if !pairKey.isEmpty { req.setValue(pairKey, forHTTPHeaderField: "x-hajimi-key") }
            if let (d, _) = try? await URLSession.shared.data(for: req), let ui = UIImage(data: d) {
                RemoteImageMemoryCache.shared.set(imageUrl, image: ui)
                loadedImage = ui
            }
        }
    }
}
