//
//  CrypticApp.swift
//  Cryptic
//
//  Created by Swanand Tanavade on 8/26/25.
//

import SwiftUI
import SwiftData

@main
struct CrypticApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Draft.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .autosaveModelContext()
        }
        .modelContainer(sharedModelContainer)
    }
}
