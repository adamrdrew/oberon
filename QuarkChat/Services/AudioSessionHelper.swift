import AVFoundation

/// Centralizes iOS audio session configuration used across voice services.
enum AudioSessionHelper {

    /// Activates a shared .playAndRecord session with speaker output and ducking.
    /// No-op on macOS (audio sessions are iOS-only).
    static func activatePlaybackSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true)
        #endif
    }

    /// Deactivates the audio session, notifying other apps they can resume.
    /// No-op on macOS.
    static func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
