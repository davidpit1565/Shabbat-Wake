import SwiftUI

struct JewishCalendarScreen: View {
    @State private var selectedDate = Date.now
    private var hebrewCalendar: Calendar {
        var calendar = Calendar(identifier: .hebrew)
        calendar.locale = Locale(identifier: "he")
        calendar.timeZone = .current
        return calendar
    }
    private var hebrewDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he")
        formatter.calendar = hebrewCalendar
        formatter.timeZone = .current
        formatter.dateFormat = "EEEE, d MMMM y"
        return formatter.string(from: selectedDate)
    }
    private var gregorianDate: String {
        selectedDate.formatted(date: .complete, time: .omitted)
    }
    private var nextShabbat: Date {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: selectedDate)
        let daysUntilSaturday = (7 - weekday) % 7
        let days = daysUntilSaturday == 0 ? 7 : daysUntilSaturday
        return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: selectedDate)) ?? selectedDate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Hebrew date", systemImage: "calendar")
                            .font(.headline).foregroundStyle(.secondary)
                        Text(hebrewDate)
                            .font(.system(.title, design: .rounded, weight: .semibold))
                        Text(gregorianDate)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))

                    DatePicker("Choose a date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Next Shabbat", systemImage: "sun.horizon.fill")
                            .font(.headline)
                        Text(nextShabbat.formatted(date: .complete, time: .omitted))
                            .font(.title3.weight(.semibold))
                        Text("This is a calendar date only. Candle-lighting, havdalah and halachic zmanim are not calculated here yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                }
                .padding(18)
            }
            .navigationTitle("Jewish calendar")
        }
    }
}
