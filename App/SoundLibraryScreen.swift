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
    var body: some View {
        List {
            Section {
                ForEach(AlarmSounds.original) { row($0) }
            } header: {
                Text("Original tones")
            } footer: {
                Text("These tones were created for Shabbat Waker. Choose one when you create an alarm.")
            }
            Section {
                ForEach(AlarmSounds.community) { row($0) }
            } header: {
                Text("More sounds")
            } footer: {
                Text("These sounds are in the public domain (CC0). Credits are in Settings under Privacy.")
            }
        }
        .navigationTitle("Sound library")
        .onDisappear { audio.stop() }
    }

    private func row(_ sound: AlarmSound) -> some View {
        HStack(spacing: 14) {
            Image(systemName: sound.symbol)
                .font(.title3)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
                .frame(width: 42, height: 42)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(sound.name)).font(.headline)
                    if sound.isPro { ProBadge() }
                }
                Text(LocalizedStringKey(sound.detail)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                audio.toggle(name: sound.name, resource: sound.file)
            } label: {
                Image(systemName: audio.playingName == sound.name ? "stop.fill" : "play.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(audio.playingName == sound.name ? Text("Stop") : Text("Preview"))
            .accessibilityValue(Text(LocalizedStringKey(sound.name)))
        }
        .padding(.vertical, 5)
    }
}
