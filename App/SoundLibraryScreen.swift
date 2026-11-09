import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

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
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") ?? CustomSounds.url(file: resource) else {
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
    @EnvironmentObject private var pro: ProStore
    @State private var customSounds = CustomSounds.entries
    @State private var importing = false
    @State private var isWorking = false
    @State private var importFailed = false
    @State private var showPaywall = false
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
                addOwnButton
                ForEach(customSounds) { sound in
                    HStack(spacing: 14) {
                        Image(systemName: "waveform")
                            .font(.title3).foregroundStyle(.blue)
                            .accessibilityHidden(true)
                            .frame(width: 42, height: 42)
                            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        Text(verbatim: sound.name).font(.headline)
                        Spacer()
                        Button {
                            audio.toggle(name: sound.name, resource: sound.file)
                        } label: {
                            Image(systemName: audio.playingName == sound.name ? "stop.fill" : "play.fill").frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(audio.playingName == sound.name ? Text("Stop") : Text("Preview"))
                    }
                    .padding(.vertical, 5)
                    .swipeActions {
                        Button(role: .destructive) {
                            audio.stop()
                            CustomSounds.remove(sound)
                            customSounds = CustomSounds.entries
                        } label: { Label("Remove", systemImage: "trash") }
                    }
                }
                ForEach(AlarmSounds.community) { row($0) }
            } header: {
                Text("More sounds")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Use a song or recording from your phone. The first 30 seconds are used, and it repeats.")
                    Text("These sounds are in the public domain (CC0). Credits are in Settings under Privacy.")
                }
            }
        }
        .navigationTitle("Sound library")
        .onDisappear { audio.stop() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            isWorking = true
            Task {
                do {
                    try await CustomSounds.importSound(from: url, name: url.deletingPathExtension().lastPathComponent)
                    customSounds = CustomSounds.entries
                } catch {
                    importFailed = true
                }
                isWorking = false
            }
        }
        .alert("Could not read this audio file.", isPresented: $importFailed) { Button("OK", role: .cancel) {} }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .sounds) }
    }

    /// First row of "More sounds", so it is the fourth sound in the list after the original tones.
    private var addOwnButton: some View {
        Button {
            if ProPolicy.canImportCustomSound(hasPro: pro.hasPro) { importing = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3).foregroundStyle(.blue)
                    .accessibilityHidden(true)
                    .frame(width: 42, height: 42)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Text("Add my own sound").font(.headline)
                ProBadge()
                Spacer()
                if isWorking { ProgressView() }
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
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
