import AVFoundation

@MainActor
enum SoundEffectService {

    // MARK: - Public API

    /// Rising two-tone chirp — "you just spoke, message sent."
    static func playSent() {
        activatePlaybackSession()
        playOneShot(sentData, volume: 0.35)
    }

    /// Gentle double-ping — "your turn to speak again."
    static func playListening() {
        activatePlaybackSession()
        playOneShot(listeningData, volume: 0.3)
    }

    /// Slow-pulsing ambient loop — "we're working on it."
    /// Guarded against double-start.
    static func startThinking() {
        guard thinkingPlayer == nil else { return }
        activatePlaybackSession()
        guard let player = try? AVAudioPlayer(data: thinkingData) else { return }
        player.numberOfLoops = -1
        player.volume = 0.25
        player.prepareToPlay()
        player.play()
        thinkingPlayer = player
    }

    /// Stops the thinking loop.
    static func stopThinking() {
        thinkingPlayer?.stop()
        thinkingPlayer = nil
    }

    // MARK: - Audio Session

    private static func activatePlaybackSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true)
        #endif
    }

    // MARK: - Playback

    private static var thinkingPlayer: AVAudioPlayer?

    /// One-shot players kept alive until playback finishes.
    private static var activePlayers: [AVAudioPlayer] = []

    private static func playOneShot(_ data: Data, volume: Float) {
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = volume
        player.prepareToPlay()
        player.play()
        activePlayers.append(player)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            activePlayers.removeAll { $0 === player }
        }
    }

    // MARK: - WAV Data (generated once, cached)

    private static let sampleRate: Double = 44100

    /// Sent: rising sweep 880→920 Hz + overtone, quick fade (~180 ms)
    private static let sentData: Data = {
        let duration = 0.18
        let count = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let freq = 880.0 + 40.0 * progress
            let phase1 = sin(2.0 * .pi * freq * t)
            let phase2 = sin(2.0 * .pi * 1320.0 * t) * 0.4
            let envelope = (1.0 - progress) * (1.0 - progress)
            let value = (phase1 + phase2) * envelope * 0.9
            samples[i] = Int16(clamping: Int(value * Double(Int16.max)))
        }
        return makeWAVData(samples: samples)
    }()

    /// Listening: two gentle rising pings (C5 → E5) — friendly "your turn" (~600 ms)
    private static let listeningData: Data = {
        let duration = 0.6
        let count = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: count)
        let ping1Freq = 523.25  // C5
        let ping2Freq = 659.25  // E5
        let pingLen = 0.2       // each ping rings for 200ms
        let ping2Start = 0.3    // second ping starts after 300ms
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var value = 0.0
            // First ping — smooth sine envelope (no clicks)
            if t < pingLen {
                let env = sin(.pi * t / pingLen) // rises then falls smoothly
                value = sin(2.0 * .pi * ping1Freq * t) * env
            }
            // Second ping (higher, major third interval)
            if t >= ping2Start && t < ping2Start + pingLen {
                let local = t - ping2Start
                let env = sin(.pi * local / pingLen)
                value += sin(2.0 * .pi * ping2Freq * local) * env * 0.9
            }
            samples[i] = Int16(clamping: Int(value * 0.8 * Double(Int16.max)))
        }
        return makeWAVData(samples: samples)
    }()

    /// Thinking: repeating soft pulses — two gentle tones per 2s loop, immediately audible
    private static let thinkingData: Data = {
        let duration = 2.0
        let count = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: count)
        // Two evenly-spaced pulses per loop: centers at 0.5s and 1.5s
        let pulseLen = 0.4   // each pulse is 400ms
        let centers = [0.5, 1.5]
        let freq = 293.66    // D4 — warm, unobtrusive
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var value = 0.0
            for center in centers {
                let dist = abs(t - center)
                if dist < pulseLen / 2 {
                    // Smooth sine-shaped envelope, zero at edges, peak at center
                    let env = sin(.pi * (1.0 - dist / (pulseLen / 2)))
                    value += sin(2.0 * .pi * freq * t) * env * 0.5
                }
            }
            samples[i] = Int16(clamping: Int(value * Double(Int16.max)))
        }
        return makeWAVData(samples: samples)
    }()

    // MARK: - WAV Encoding

    private static func makeWAVData(samples: [Int16]) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        data.reserveCapacity(44 + dataSize)

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))                  // PCM
        data.appendLittleEndian(UInt16(1))                  // mono
        data.appendLittleEndian(UInt32(44100))
        data.appendLittleEndian(UInt32(44100 * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))

        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.appendLittleEndian(UInt32(dataSize))
        for sample in samples {
            data.appendLittleEndian(sample)
        }
        return data
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func appendLittleEndian(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: Int16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
