//
//  TotoScannerApp.swift
//  TotoScanner
//
//  Created by Muhua on 6/1/25.
//

import SwiftUI

@main
struct TotoScannerApp: App {
    @StateObject private var viewModel = TOTOViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView() // Use MainView instead of ContentView
                .environmentObject(viewModel) // Inject ViewModel
        }
    }
}
