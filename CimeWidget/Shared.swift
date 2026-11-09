//
//  Shared.swift
//  Cime
//
//  Created by Daniel Pappalardo on 07/11/2026.
//

import Foundation

nonisolated enum Shared {
    static let appGroup = "group.club.cime"            // must match the capability
    static let defaults = UserDefaults(suiteName: appGroup)
    static let dayKey = "widget.day"
    static let countKey = "widget.count"

    static func todayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
