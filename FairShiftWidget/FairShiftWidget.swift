import WidgetKit
import SwiftUI

// the Home Screen / Lock Screen widget. it only reads the snapshot the app wrote
// into the App Group - it never touches Core Data.

struct FortnightEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct FortnightProvider: TimelineProvider {
    func placeholder(in context: Context) -> FortnightEntry {
        FortnightEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (FortnightEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : (WidgetSnapshotStore.load() ?? .notSetUp())
        completion(FortnightEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FortnightEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.load() ?? .notSetUp(now: now)
        let entry = FortnightEntry(date: now, snapshot: snapshot)

        // the app reloads this whenever data changes; the refresh below only keeps
        // "days left" and the next-shift countdown fresh if the app isn't opened
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct FairShiftWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FortnightEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        Group {
            if !snapshot.isSetUp {
                setUpPrompt
            } else {
                switch family {
                case .accessoryCircular: circular
                case .accessoryRectangular: rectangular
                case .systemMedium: medium
                default: small
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var tint: Color { snapshot.isOverLimit ? .red : .blue }

    private func hours(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var setUpPrompt: some View {
        VStack(spacing: 4) {
            Image(systemName: "briefcase")
            Text("Add your workplace in FairShift")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hours left").font(.caption).foregroundStyle(.secondary)
            Text(hours(snapshot.hoursRemaining))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
            ProgressView(value: min(snapshot.hoursCommitted, snapshot.limitHours), total: max(snapshot.limitHours, 1))
                .tint(tint)
            Text("\(hours(snapshot.hoursCommitted)) of \(hours(snapshot.limitHours)) h")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            small
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Next shift").font(.caption).foregroundStyle(.secondary)
                if let next = snapshot.nextShift {
                    Text(next.workplaceName).font(.headline).lineLimit(1)
                    Text(next.startsAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.subheadline)
                    Text("until \(next.endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Nothing rostered").font(.subheadline)
                }
                Spacer(minLength: 0)
                Text("Fortnight ends \(snapshot.windowEnd.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Lock Screen

    private var circular: some View {
        Gauge(value: min(snapshot.hoursCommitted, snapshot.limitHours), in: 0...max(snapshot.limitHours, 1)) {
            Text("h")
        } currentValueLabel: {
            Text(hours(snapshot.hoursRemaining))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(hours(snapshot.hoursRemaining)) h left this fortnight")
                .font(.headline)
            if let next = snapshot.nextShift {
                Text("\(next.workplaceName) · \(next.startsAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                    .font(.caption)
            } else {
                Text("No upcoming shift").font(.caption)
            }
        }
    }
}

struct FairShiftWidget: Widget {
    let kind = "FairShiftFortnightHours"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FortnightProvider()) { entry in
            FairShiftWidgetView(entry: entry)
        }
        .configurationDisplayName("Fortnight hours")
        .description("See how many hours you can still work this fortnight, and your next shift.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct FairShiftWidgetBundle: WidgetBundle {
    var body: some Widget {
        FairShiftWidget()
    }
}
