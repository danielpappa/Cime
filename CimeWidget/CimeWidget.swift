//
//  CimeWidget.swift
//  CimeWidget
//
//  Created by Daniel Pappalardo on 07/11/2026.
//

import WidgetKit
import SwiftUI

struct PeaksEntry: TimelineEntry { let date: Date; let count: Int }

struct PeaksProvider: TimelineProvider {
    func placeholder(in context: Context) -> PeaksEntry { PeaksEntry(date: .now, count: 2) }

    func getSnapshot(in context: Context, completion: @escaping (PeaksEntry) -> Void) {
        completion(PeaksEntry(date: .now, count: current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PeaksEntry>) -> Void) {
        let cal = Calendar.current
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        // second entry flips to 0 at midnight even if the app isn't opened
        let entries = [PeaksEntry(date: .now, count: current()), PeaksEntry(date: midnight, count: 0)]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func current() -> Int {
        guard Shared.defaults?.string(forKey: Shared.dayKey) == Shared.todayKey() else { return 0 }
        return min(3, max(0, Shared.defaults?.integer(forKey: Shared.countKey) ?? 0))
    }
}

struct PeaksWidgetView: View {
    let entry: PeaksEntry
    
    var body: some View {
        let statuses: [PeakStatus] = (0..<3).map { index in
            index < entry.count ? .done : .todo
        }
        
        LogoView(statuses: statuses, height: 90)
            .padding(2)
            .containerBackground(for: .widget) { Color(Theme.background).opacity(0.85) }
            .widgetURL(URL(string: "cime://climb"))
    }
}

struct CimeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CimeWidget", provider: PeaksProvider()) { PeaksWidgetView(entry: $0) }
            .configurationDisplayName("Today's peaks")
            .description("How many of your three peaks you've reached today.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    CimeWidget()
} timeline: {
    PeaksEntry(date: Date(), count: 0)
}
