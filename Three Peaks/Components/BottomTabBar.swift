import SwiftUI

struct BottomTabBar: View {
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    Text(item.title)
                        .monoCaps(11)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tab == item ? Theme.primary : Color.clear)
                        .foregroundStyle(tab == item ? Theme.primaryForeground : Theme.mutedForeground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.card.opacity(0.9))
        .overlay(Capsule().stroke(Theme.border))
        .clipShape(Capsule())
    }
}
