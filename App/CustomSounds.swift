import AVFoundation
import Foundation

/// The person's own alarm sounds: a song or a recording from the phone, turned into the same files the built-in sounds use
/// (see App/AlarmSoundGenerator.py) and kept in Library/Sounds, which is where the system looks for custom alarm sounds.
struct CustomSound: Codable, Identifiable, Equatable {
    /// "custom-" and a UUID; this is what an alarm stores.
    let id: String
    var name: String
    var file: String { AlarmSounds.file(for: id) }
}

enum CustomSoundError: LocalizedError {
    case unreadable
    var errorDescription: String? { AppLanguage.text("Could not read this audio file.") }
}

enum CustomSounds {
    private static let key = "customSounds.v1"
    /// Only this much of a long song is used; it then repeats like every other sound.
    static let maxSeconds = 30.0
    static let ringSeconds = [10, 15, 20, 30, 40, 50]
    static let notificationSeconds: [(label: String, seconds: Double)] = [("n10", 10), ("n15", 15), ("n20", 20), ("n29", 29.5)]
    private static let tailSeconds = 300

    static var entries: [CustomSound] {
        guard let data = UserDefaults.standard.data(forKey: key), let list = try? JSONDecoder().decode([CustomSound].self, from: data) else { return [] }
        return list
    }

    private static func save(_ list: [CustomSound]) {
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }

    static var directory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        return library
    }

    /// The file for a sound base name and suffix, such as ("Custom_ABC", "_15s"), if it exists.
    static func url(file base: String, suffix: String = "") -> URL? {
        let url = directory.appendingPathComponent(base + suffix + ".wav")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func exists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(fileName).path)
    }

    // MARK: Import and remove

    @discardableResult
    static func importSound(from source: URL, name: String) async throws -> CustomSound {
        let entry = CustomSound(id: "custom-" + UUID().uuidString, name: name)
        let base = entry.file
        let directory = Self.directory
        try await Task.detached(priority: .userInitiated) {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            let clip22 = try decode(source, rate: 22_050)
            let clip8 = try decode(source, rate: 8_000)
            guard clip22.count > 2_000, clip8.count > 800 else { throw CustomSoundError.unreadable }
            try pcmWAV(clip22, rate: 22_050).write(to: directory.appendingPathComponent(base + ".wav"))
            for seconds in ringSeconds {
                try alarmKitWAV(looped(clip8, rate: 8_000, seconds: Double(seconds)), rate: 8_000)
                    .write(to: directory.appendingPathComponent("\(base)_\(seconds)s.wav"))
            }
            for piece in notificationSeconds {
                try pcmWAV(looped(clip22, rate: 22_050, seconds: piece.seconds), rate: 22_050)
                    .write(to: directory.appendingPathComponent("\(base)_\(piece.label)s.wav"))
            }
        }.value
        save(entries + [entry])
        return entry
    }

    static func remove(_ sound: CustomSound) {
        let names = ([""] + ringSeconds.map { "_\($0)s" } + notificationSeconds.map { "_\($0.label)s" }).map { sound.file + $0 + ".wav" }
        for name in names { try? FileManager.default.removeItem(at: directory.appendingPathComponent(name)) }
        save(entries.filter { $0.id != sound.id })
    }

    // MARK: Audio (pure functions, tested)

    /// The file as mono 16-bit samples at `rate`, at most `maxSeconds` long.
    static func decode(_ url: URL, rate: Double) throws -> [Int16] {
        let file = try AVAudioFile(forReading: url)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: rate, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: file.processingFormat, to: target),
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8_192),
              let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 8_192) else { throw CustomSoundError.unreadable }
        var samples: [Int16] = []
        let limit = Int(rate * maxSeconds)
        var finished = false
        while samples.count < limit {
            output.frameLength = 0
            var failure: NSError?
            let status = converter.convert(to: output, error: &failure) { _, inputStatus in
                if finished { inputStatus.pointee = .endOfStream; return nil }
                do { try file.read(into: input) } catch { finished = true; inputStatus.pointee = .endOfStream; return nil }
                if input.frameLength == 0 { finished = true; inputStatus.pointee = .endOfStream; return nil }
                inputStatus.pointee = .haveData
                return input
            }
            if failure != nil || status == .error { throw CustomSoundError.unreadable }
            if output.frameLength > 0, let channel = output.int16ChannelData {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
            }
            if status == .endOfStream || (finished && output.frameLength == 0) { break }
        }
        return Array(samples.prefix(limit))
    }

    /// The clip repeated until `seconds`, with a gap after each copy, ending on a short fade.
    static func looped(_ clip: [Int16], rate: Int, seconds: Double) -> [Int16] {
        guard !clip.isEmpty else { return [] }
        let gap = Int(Double(rate) * (clip.count < rate * 5 ? 1.6 : 0.8))
        let total = Int(Double(rate) * seconds)
        var out = [Int16]()
        out.reserveCapacity(total)
        while out.count < total {
            out.append(contentsOf: clip)
            out.append(contentsOf: [Int16](repeating: 0, count: gap))
        }
        out = Array(out.prefix(total))
        let fade = min(Int(Double(rate) * 0.3), total)
        for index in 0..<fade {
            let position = total - 1 - index
            out[position] = Int16(Double(out[position]) * Double(index) / Double(fade))
        }
        return out
    }

    /// G.711 mu-law, as the AlarmKit sound files use.
    static func mulaw(_ sample: Int16) -> UInt8 {
        let bias = 0x84, clip = 32_635
        var value = Int(sample)
        let sign = (value >> 8) & 0x80
        if sign != 0 { value = -value }
        if value > clip { value = clip }
        value += bias
        var exponent = 7
        var mask = 0x4000
        while exponent > 0 && (value & mask) == 0 { exponent -= 1; mask >>= 1 }
        let mantissa = (value >> (exponent + 3)) & 0x0F
        return UInt8(~(sign | (exponent << 4) | mantissa) & 0xFF)
    }

    private static func le32(_ value: Int) -> Data { withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) } }
    private static func le16(_ value: Int) -> Data { withUnsafeBytes(of: UInt16(value).littleEndian) { Data($0) } }

    /// Mu-law, 8 kHz, mono: the tone, then silence up to five minutes, so the alarm sound ends by itself after the tone.
    static func alarmKitWAV(_ samples: [Int16], rate: Int) -> Data {
        var audio = Data(samples.map(mulaw))
        let total = rate * tailSeconds
        if audio.count < total { audio.append(Data(repeating: mulaw(0), count: total - audio.count)) }
        var format = Data()
        format.append(le16(7)); format.append(le16(1)); format.append(le32(rate)); format.append(le32(rate))
        format.append(le16(1)); format.append(le16(8)); format.append(le16(0))
        var body = Data("WAVE".utf8)
        body.append(Data("fmt ".utf8)); body.append(le32(format.count)); body.append(format)
        body.append(Data("fact".utf8)); body.append(le32(4)); body.append(le32(audio.count))
        body.append(Data("data".utf8)); body.append(le32(audio.count)); body.append(audio)
        var file = Data("RIFF".utf8)
        file.append(le32(body.count)); file.append(body)
        return file
    }

    /// 16-bit PCM mono, for notification sounds and the preview.
    static func pcmWAV(_ samples: [Int16], rate: Int) -> Data {
        var audio = Data()
        audio.reserveCapacity(samples.count * 2)
        for sample in samples { audio.append(le16(Int(UInt16(bitPattern: sample)))) }
        var file = Data("RIFF".utf8)
        file.append(le32(36 + audio.count))
        file.append(Data("WAVEfmt ".utf8)); file.append(le32(16)); file.append(le16(1)); file.append(le16(1))
        file.append(le32(rate)); file.append(le32(rate * 2)); file.append(le16(2)); file.append(le16(16))
        file.append(Data("data".utf8)); file.append(le32(audio.count)); file.append(audio)
        return file
    }
}


/// The alarm files for the built-in sounds are made when an alarm needs them (once), from the small source sound in the app,
/// instead of shipping every length of every sound. That keeps the app small.
enum SoundFiles {
    /// The notification pieces a Shabbat alarm of this length plays, one after the other.
    static func notificationLabels(for seconds: Int) -> [String] {
        switch seconds {
        case 10: return ["n10"]
        case 15: return ["n15"]
        case 20: return ["n20"]
        case 30: return ["n29"]
        case 40: return ["n29", "n10"]
        default: return ["n29", "n20"]
        }
    }

    private static func length(of label: String) -> Double {
        switch label {
        case "n10": return 10
        case "n15": return 15
        case "n20": return 20
        default: return 29.5
        }
    }

    private static func source(_ base: String) -> URL? {
        Bundle.main.url(forResource: base, withExtension: "wav") ?? Bundle.main.url(forResource: base, withExtension: "mp3")
    }

    /// Makes the files for `soundID` at this ring length if they are not there yet. `notification` is for a Shabbat alarm.
    static func ensure(soundID: String, seconds: Int, notification: Bool) async {
        guard soundID != "system", !soundID.hasPrefix("custom-") else { return }   // own sounds are made when they are imported
        let base = AlarmSounds.file(for: soundID)
        struct Job { let name: String; let rate: Int; let seconds: Double; let alarmKit: Bool }
        var jobs: [Job] = []
        if notification {
            for label in notificationLabels(for: seconds) {
                jobs.append(Job(name: "\(base)_\(label)s.wav", rate: 22_050, seconds: length(of: label), alarmKit: false))
            }
        } else {
            jobs.append(Job(name: "\(base)_\(seconds)s.wav", rate: 8_000, seconds: Double(seconds), alarmKit: true))
        }
        jobs = jobs.filter { !CustomSounds.exists(fileName: $0.name) }
        guard !jobs.isEmpty, let url = source(base) else { return }
        let work = jobs
        await Task.detached(priority: .userInitiated) {
            for job in work {
                guard let clip = try? CustomSounds.decode(url, rate: Double(job.rate)), !clip.isEmpty else { continue }
                let samples = CustomSounds.looped(clip, rate: job.rate, seconds: job.seconds)
                let data = job.alarmKit ? CustomSounds.alarmKitWAV(samples, rate: job.rate) : CustomSounds.pcmWAV(samples, rate: job.rate)
                try? data.write(to: CustomSounds.directory.appendingPathComponent(job.name), options: .atomic)
            }
        }.value
    }
}
