import AlarmKit
import Foundation

/// Shared by the app and the widget extension: AlarmKit needs both sides to agree on this type
/// so the extension can draw the alarm on the Lock Screen and in the Dynamic Island.
@available(iOS 26.0, *)
struct ShabbatWakeAlarmMetadata: AlarmMetadata, Codable, Hashable {
    var title: String
}
