//
//  ResultsView.swift
//  TotoScanner
//
//  Created by mu on 22/3/25.
//
import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var viewModel: TOTOViewModel
    @State private var drawNumberToWinningNumber = [String:TOTOParseResult]()
    @State private var didLoad = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let latestWinningNumber = viewModel.latestWinningNumber {
                    VStack {
                        if let drawNumber = latestWinningNumber.drawNumber {
                            Text("Latest Draw No. \( drawNumber)")
                                .font(.title3)
                                .bold()
                        }
                        
                        
                        Text("Winning Numbers")
                        Text("\(latestWinningNumber.winningNumbers.map { String($0) }.joined(separator: ", "))")
                        
                        
                        Text("Additional Number")
                        if let additionalNumber = latestWinningNumber.additionalNumber {
                            Text("\( additionalNumber)")
                        }
                        
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2)))
                } else {
                    ProgressView("Fetching latest results...")
                }
                
                if let error = viewModel.errorMessage {
                    Text("Error: \\(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("TOTO Results")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetchAndParseTOTOResults { _ in }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh Results") // Optional hover tooltip on Mac
                    }
                }
                .onAppear {
                    if !didLoad {
                        viewModel.fetchAndParseTOTOResults { _ in }
                        didLoad = true
                    }
                }
        }
    }
    
    // Example helper function to parse draw number text like "Draw No. 3701"
    func extractDrawNumber(from text: String?) -> String? {
        guard let text = text else { return nil }
        return String(text.suffix(4))
    }
    
    func extractDrawDate(from text: String?) -> String? {
        guard let text = text else { return nil }
    
        let weekday = text.prefix(3)
        let date = text.split(separator: ", ")[1].split(separator: " Draw No.")[0]
        return date + " " + weekday
    }
    
    func extractWinningNumber(from text: String?) -> [Int] {
        guard let text = text else { return [] }
        let numbers = text.split(separator: "Winning Numbers ")[0].split(separator: " ")
        return numbers.map { Int($0)!}
    }
    
    func extractAdditionalNumber(from text: String?) -> Int? {
        guard let text = text else { return nil }
        return Int(text.split(separator: "Additional Number ")[0])
    }
    
}
