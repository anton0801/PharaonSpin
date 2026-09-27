//
//  PharaonSpinApp.swift
//  PharaonSpin
//
//  Created by Anton Danilov on 22/9/26.
//

import SwiftUI

@main
struct PharaonSpinApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.settings)
                .environmentObject(model.storeService)
                .environmentObject(model.network)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
        .onChange(of: scenePhase) { phase in
            model.scenePhaseChanged(phase)
        }
    }
}
