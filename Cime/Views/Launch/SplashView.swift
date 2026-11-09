//
//  SplashView.swift
//  Cime
//
//  Created by Daniel Pappalardo on 31/10/2026.
//

import Foundation
import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(Theme.background)
                .ignoresSafeArea()
            LogoView(done: [true, true, false])
                .scaleEffect(0.6)
        }
    }
}

#Preview {
    SplashView()
        .environment(CimeStore())
}
