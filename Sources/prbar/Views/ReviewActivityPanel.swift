import Charts
import PRBarCore
import SwiftUI

/// The review histogram, shown in place of the list rather than in a popover — a popover
/// anchored inside a `MenuBarExtra` window fights the panel for focus.
struct ReviewActivityPanel: View {
    let model: AppModel

    @State private var span = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            chart
            summary
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text("PRs reviewed")
                .font(.headline)
            Spacer()
            Picker("", selection: $span) {
                Text("7 days").tag(7)
                Text("30 days").tag(AppModel.activityWindow)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var chart: some View {
        let counts = model.dailyCounts(days: span)
        let peak = counts.map(\.count).max() ?? 0
        return Chart(counts) { day in
            BarMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("PRs", day.count)
            )
            .foregroundStyle(.tint)
            .cornerRadius(2)
            .annotation(position: .top, spacing: 2) {
                if span <= 7, day.count > 0 {
                    Text("\(day.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYScale(domain: 0...max(peak, 1))
        .chartYAxis {
            AxisMarks(format: IntegerFormatStyle<Int>())
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: span <= 7 ? 1 : 5)) { _ in
                AxisGridLine()
                AxisValueLabel(
                    format: span <= 7
                        ? .dateTime.weekday(.abbreviated)
                        : .dateTime.day().month(.defaultDigits)
                )
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var summary: some View {
        let counts = model.dailyCounts(days: span)
        let total = counts.reduce(0) { $0 + $1.count }
        let busiest = counts.map(\.count).max() ?? 0
        return Text("\(total) in \(span) days · busiest \(busiest) · \(model.reviewedToday) today")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
