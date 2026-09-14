import SwiftUI

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.title)
                .font(.headline)

            Text(trip.destination)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(dateRange, systemImage: "calendar")
                Label(modeName, systemImage: modeSymbol)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var dateRange: String {
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day().year()
        return "\(trip.startDate.formatted(format)) - \(trip.endDate.formatted(format))"
    }

    private var modeName: String {
        switch trip.mode {
        case .structured:
            return "Day by day"
        case .unstructured:
            return "Flexible"
        }
    }

    private var modeSymbol: String {
        switch trip.mode {
        case .structured:
            return "calendar.day.timeline.left"
        case .unstructured:
            return "list.bullet"
        }
    }
}
