import AVFoundation
import SwiftUI

@MainActor
final class AlarmTonePlayer: ObservableObject {
    static let shared = AlarmTonePlayer()
    @Published private(set) var playingName: String?
    private var player: AVAudioPlayer?

    func toggle(name: String, resource: String) {
        if playingName == name {
            player?.stop()
            player = nil
            playingName = nil
            return
        }
        player?.stop()
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            playingName = nil
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            let next = try AVAudioPlayer(contentsOf: url)
            next.prepareToPlay()
            next.play()
            player = next
            playingName = name
        } catch {
            playingName = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingName = nil
    }
}

struct SoundLibraryScreen: View {
    @StateObject private var audio = AlarmTonePlayer.shared
    private let tones: [(name: LocalizedStringKey, plainName: String, detail: LocalizedStringKey, file: String, symbol: String)] = [
        ("Gentle Chime", "Gentle Chime", "A soft, layered morning chime", "GentleChime", "sparkles"),
        ("Sunrise Sequence", "Sunrise Sequence", "A calm rising sequence of original notes", "SunriseSequence", "sunrise.fill"),
        ("Classic Wake", "Classic Wake", "A clearer, more insistent bell-like pattern", "ClassicWake", "bell.fill")
    ]

    var body: some View {
        List {
            Section {
                ForEach(tones, id: \.file) { tone in
                    HStack(spacing: 14) {
                        Image(systemName: tone.symbol)
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                            .frame(width: 42, height: 42)
                            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tone.name).font(.headline)
                            Text(tone.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            audio.toggle(name: tone.plainName, resource: tone.file)
                        } label: {
                            Image(systemName: audio.playingName == tone.plainName ? "stop.fill" : "play.fill")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(audio.playingName == tone.plainName ? Text("Stop") : Text("Preview"))
                        .accessibilityValue(Text(tone.name))
                    }
                    .padding(.vertical, 5)
                }
            } header: {
                Text("Original tones")
            } footer: {
                Text("These tones were created for Shabbat Waker. Choose one when you create an alarm.")
            }
        }
        .navigationTitle("Sound library")
        .onDisappear { audio.stop() }
    }
}
