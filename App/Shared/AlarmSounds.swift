import Foundation

/// Every alarm sound the app offers. The id is what an alarm stores; `file` is the base name of the generated WAV files
/// (see App/AlarmSoundGenerator.py). "system" (Apple's standard sound) is handled separately and has no entry here.
struct AlarmSound: Identifiable, Equatable {
    let id: String
    /// Key in Localizable.strings, and the English name.
    let name: String
    let file: String
    let symbol: String
    /// Key in Localizable.strings.
    let detail: String
    let isFree: Bool
    /// Credit line for sounds made by someone else (all CC0, so a courtesy), nil for the app's own tones.
    let credit: String?
    var isPro: Bool { !isFree }
}

enum AlarmSounds {
    static let original: [AlarmSound] = [
        AlarmSound(id: "classic", name: "Classic Wake", file: "ClassicWake", symbol: "bell.fill", detail: "A clearer, more insistent bell-like pattern", isFree: true, credit: nil),
        AlarmSound(id: "gentle", name: "Gentle Chime", file: "GentleChime", symbol: "sparkles", detail: "A soft, layered morning chime", isFree: true, credit: nil),
        AlarmSound(id: "sunrise", name: "Sunrise Sequence", file: "SunriseSequence", symbol: "sunrise.fill", detail: "A calm rising sequence of original notes", isFree: false, credit: nil)
    ]

    static let community: [AlarmSound] = [
        AlarmSound(id: "morningchime", name: "Morning Chime", file: "MorningChime", symbol: "bell", detail: "Bright, slow chimes", isFree: true, credit: "\"The Chime 2\" by Pro Sensory, CC0, OpenGameArt.org"),
        AlarmSound(id: "pleasingbell", name: "Pleasing Bell", file: "PleasingBell", symbol: "bell.and.waves.left.and.right", detail: "One clear bell that repeats", isFree: false, credit: "\"Pleasing Bell\" by Spring Spring, CC0, OpenGameArt.org"),
        AlarmSound(id: "musicboxlullaby", name: "Music Box Lullaby", file: "MusicBoxLullaby", symbol: "music.note", detail: "A gentle music box melody", isFree: false, credit: "\"4 Music Box Tracks\" by Aureolus_Omicron, CC0, OpenGameArt.org"),
        AlarmSound(id: "musicboxpolka", name: "Music Box Polka", file: "MusicBoxPolka", symbol: "music.quarternote.3", detail: "A light, bouncy music box tune", isFree: false, credit: "\"4 Music Box Tracks\" by Aureolus_Omicron, CC0, OpenGameArt.org"),
        AlarmSound(id: "happylullaby", name: "Happy Lullaby", file: "HappyLullaby", symbol: "moon.stars.fill", detail: "A warm, happy lullaby", isFree: false, credit: "\"Happy Lullaby (song17)\" by cynicmusic, CC0, OpenGameArt.org"),
        AlarmSound(id: "forestbirds", name: "Forest Birds", file: "ForestBirds", symbol: "bird.fill", detail: "Birdsong in the forest", isFree: false, credit: "\"Forest bird sounds\" by pauliuw, CC0, OpenGameArt.org"),
        AlarmSound(id: "meadowbirds", name: "Meadow Birds", file: "MeadowBirds", symbol: "leaf.fill", detail: "Soft birds in an open meadow", isFree: false, credit: "\"Ambient Bird Sounds\" by isaiah658, CC0, OpenGameArt.org"),
        AlarmSound(id: "windandbirds", name: "Wind and Birds", file: "WindAndBirds", symbol: "wind", detail: "Birds with a light breeze", isFree: false, credit: "\"Birds and Wind\" by Spring Spring, CC0, OpenGameArt.org"),
        AlarmSound(id: "marimbamorning", name: "Marimba Morning", file: "MarimbaMorning", symbol: "pianokeys", detail: "A cheerful marimba tune", isFree: false, credit: "\"Jungle Simple Style 1\" by Tozan, CC0, OpenGameArt.org"),
        AlarmSound(id: "softpiano", name: "Soft Piano", file: "SoftPiano", symbol: "pianokeys.inverse", detail: "A calm, quiet piano", isFree: false, credit: "\"JRPG Piano\" by Joth, CC0, OpenGameArt.org"),
        AlarmSound(id: "crowcaw", name: "Crow Caw", file: "CrowCaw", symbol: "bird", detail: "A funny one: a single crow caw", isFree: false, credit: "\"Crow caw\" by zeroisnotnull, CC0, OpenGameArt.org"),
        AlarmSound(id: "crowchorus", name: "Crow Chorus", file: "CrowChorus", symbol: "bird.circle", detail: "A funny one: crows singing together", isFree: false, credit: "\"Crows singing\" by IgnasD, CC0, OpenGameArt.org")
    ]

    static var all: [AlarmSound] { original + community }

    static func sound(id: String) -> AlarmSound? { all.first { $0.id == id } }

    /// File base name for an alarm's sound id; unknown ids fall back to the classic tone.
    static func file(for id: String) -> String {
        // The person's own sounds ("custom-" and a UUID) are made at import time; see App/CustomSounds.swift.
        if id.hasPrefix("custom-") { return "Custom_" + id.dropFirst("custom-".count) }
        return (sound(id: id) ?? original[0]).file
    }

    /// Ids a free user may choose.
    static var freeIDs: Set<String> { Set(all.filter(\.isFree).map(\.id)) }

    /// Credit lines without repeats, in catalog order.
    static var credits: [String] {
        var seen = Set<String>()
        return community.compactMap(\.credit).filter { seen.insert($0).inserted }
    }
}
