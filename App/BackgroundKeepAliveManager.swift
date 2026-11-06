import Foundation
import UIKit
import AVFoundation
import UserNotifications

@MainActor
final class BackgroundKeepAliveManager {
    static let shared = BackgroundKeepAliveManager()

    private var silentPlayer: AVAudioPlayer?
    private var bgTaskId: UIBackgroundTaskIdentifier = .invalid
    private var isCurrentlyInBackground: Bool = false
    private var shouldKeepAliveInBg: Bool = true
    private var interruptionObserver: NSObjectProtocol?

    private init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let typeVal = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let raw = typeVal,
                   let type = AVAudioSession.InterruptionType(rawValue: raw),
                   type == .ended,
                   self.isCurrentlyInBackground,
                   self.shouldKeepAliveInBg {
                    self.startSilentLoop()
                }
            }
        }
    }

    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func enterBackground(keepAlive: Bool, onGraceExpire: (@MainActor () -> Void)? = nil) {
        isCurrentlyInBackground = true
        shouldKeepAliveInBg = keepAlive
        beginGraceShield(onExpire: onGraceExpire)
        if keepAlive {
            startSilentLoop()
        } else {
            stopSilentLoop()
        }
    }

    func enterForeground() {
        isCurrentlyInBackground = false
        endGraceShield()
        stopSilentLoop()
    }

    func updateKeepAlivePreference(_ enabled: Bool) {
        shouldKeepAliveInBg = enabled
        if !enabled {
            stopSilentLoop()
        } else if isCurrentlyInBackground {
            startSilentLoop()
        }
    }

    func postBackgroundReplyNotification(title: String, body: String, sessionId: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(cleanBody.prefix(120))
        content.sound = .default
        content.userInfo = ["sessionId": sessionId]

        let req = UNNotificationRequest(
            identifier: "hajimi-reply-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func beginGraceShield(onExpire: (@MainActor () -> Void)?) {
        endGraceShield()
        bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "HajimiSSEGraceShield") { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.shouldKeepAliveInBg {
                    onExpire?()
                }
                self.endGraceShield()
            }
        }
    }

    private func endGraceShield() {
        if bgTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(bgTaskId)
            bgTaskId = .invalid
        }
    }

    private func startSilentLoop() {
        if let player = silentPlayer, player.isPlaying {
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])

            if silentPlayer == nil {
                let wav = Self.makeSilentWavData(durationSeconds: 2, sampleRate: 8000)
                let p = try AVAudioPlayer(data: wav, fileTypeHint: AVFileType.wav.rawValue)
                p.numberOfLoops = -1
                p.volume = 0.0
                p.prepareToPlay()
                silentPlayer = p
            }
            silentPlayer?.volume = 0.0
            silentPlayer?.play()
        } catch {}
    }

    private func stopSilentLoop() {
        silentPlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private static func makeSilentWavData(durationSeconds: UInt32, sampleRate: UInt32) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let dataSize: UInt32 = byteRate * durationSeconds
        let riffChunkSize: UInt32 = 36 + dataSize

        var data = Data(capacity: Int(44 + dataSize))
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        withUnsafeBytes(of: riffChunkSize.littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        let subchunk1Size: UInt32 = 16
        let audioFormat: UInt16 = 1
        withUnsafeBytes(of: subchunk1Size.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: audioFormat.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: numChannels.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: sampleRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: blockAlign.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bitsPerSample.littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        withUnsafeBytes(of: dataSize.littleEndian) { data.append(contentsOf: $0) }
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
