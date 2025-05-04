//  ContentView.swift
//  TotoScanner
//
//  Created by Muhua on 6/1/25.

import SwiftUI
import SwiftSoup
import Vision

struct MainView: View {
    @StateObject private var viewModel = TOTOViewModel()
    var body: some View {
        TabView {
            ResultsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Results")
                }
            
            ScanTicketView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Scan Ticket")
                }
            
            ManualEntryView()
                .tabItem {
                    Image(systemName: "keyboard.fill")
                    Text("Manual Entry")
                }
        }
        .environmentObject(viewModel)
    }
}


func checkOrdinaryTotoResult(
    winningNumbers: [Int],
    additionalNumber: Int,
    userNumbers: [Int]
) -> Int? {
    // Count how many of the user's numbers appear in the winning numbers
    let matchedCount = userNumbers.filter { winningNumbers.contains($0) }.count

    // Check if the user has the additional number
    let hasAdditional = userNumbers.contains(additionalNumber)

    // Use the TOTO prize group logic
    switch (matchedCount, hasAdditional) {
    case (6, _):
        // All 6 winning numbers matched => Group 1 (Jackpot)
        return 1
    case (5, true):
        // 5 winning numbers + additional => Group 2
        return 2
    case (5, false):
        // 5 winning numbers => Group 3
        return 3
    case (4, true):
        // 4 winning numbers + additional => Group 4
        return 4
    case (4, false):
        // 4 winning numbers => Group 5
        return 5
    case (3, true):
        // 3 winning numbers + additional => Group 6
        return 6
    case (3, false):
        // 3 winning numbers => Group 7
        return 7
    default:
        // Matched fewer than 3 => No Prize
        return nil
    }
}

func checkSystem7TotoResult(
    winningNumbers: [Int],
    additionalNumber: Int,
    userNumbers: [Int]
) -> Int? {
    guard userNumbers.count == 7 else {
        return nil // Not a valid System 7 entry
    }

    let combinations = generateCombinations(of: userNumbers, choose: 6)
    var bestPrize: Int? = nil

    for combo in combinations {
        if let prize = checkOrdinaryTotoResult(
            winningNumbers: winningNumbers,
            additionalNumber: additionalNumber,
            userNumbers: combo
        ) {
            if let currentBest = bestPrize {
                bestPrize = min(currentBest, prize) // lower group number = better prize
            } else {
                bestPrize = prize
            }
        }
    }

    return bestPrize
}

func generateCombinations(of elements: [Int], choose k: Int) -> [[Int]] {
    guard k <= elements.count else { return [] }
    var result: [[Int]] = []
    
    func combine(_ start: Int, _ current: [Int]) {
        if current.count == k {
            result.append(current)
            return
        }
        for i in start..<elements.count {
            combine(i + 1, current + [elements[i]])
        }
    }

    combine(0, [])
    return result
}


#Preview {
    MainView()
}
