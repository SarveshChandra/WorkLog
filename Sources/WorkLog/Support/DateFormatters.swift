import Foundation

enum AppDateFormatters {
    static let monthDayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let backupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    static let statusDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func short(_ date: Date?) -> String {
        guard let date else { return "" }
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            return monthDayDate.string(from: date)
        }
        return shortDate.string(from: date)
    }

    static func range(start: Date, end: Date?) -> String {
        guard let end else {
            return short(start)
        }

        if Calendar.current.isDate(start, inSameDayAs: end) {
            return short(start)
        }

        return "\(short(start)) to \(short(end))"
    }

    static func duration(start: Date, end: Date?) -> String {
        guard let end else { return "1 day" }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let rawDays = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        let durationDays = max(rawDays + 1, 1)
        return durationDays == 1 ? "1 day" : "\(durationDays) days"
    }
}
