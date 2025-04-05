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
    @State private var localDrawDates: [String] = []
    @State private var selectedDate: String?
    @State private var selectedDrawNumber: String? = nil
    @State private var selectedResult: TOTOParseResult?
    
    @State private var didLoad = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    drawPicker
                    if let displayResult = viewModel.selectedWinningNumber {
                        latestResultCard(for: displayResult)
                    } else {
                        ProgressView("Fetching latest results...")
                    }
//                    pastResultsSection
                }
                .padding()
            }
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
                    viewModel.fetchDrawDates()
                    viewModel.fetchAndParseTOTOResults { _ in }
                    didLoad = true
                }
            }
        }
    }
    
    
    
    // MARK: - Draw Picker Section
    private var drawPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Select Draw", selection: $selectedDate) {
                ForEach(localDrawDates, id: \.self) { date in
                    Text(date).tag(date as String?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
            .onChange(of: selectedDate) { newValue in
                if let draw = newValue,
                   let drawInfo = viewModel.dateToDrawNumber[draw],
                   let drawNumber = drawInfo["value"],
                   let spplValue = drawInfo["sppl"] {
                    viewModel.fetchWinningNumber(with: spplValue) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let fetchedResult):
                                print("Success")
                            case .failure(let error):
                                print("Error fetching result: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    selectedDrawNumber = drawNumber
                }
                else {
                    selectedResult = viewModel.selectedWinningNumber
                }
            }
        }
        .onChange(of: viewModel.sortedDrawDates) { newDates in
            localDrawDates = newDates
            if selectedDate == nil, let firstDate = localDrawDates.first {
                selectedDate = firstDate // Preselect the first date by default
            }
        }
    }
    
    func extractDrawDateFormatted(from text: String?) -> String? {
        guard let text = text else { return nil }

        let components = text.components(separatedBy: ", ")
        guard components.count > 1 else { return nil }

        let weekday = components[0] // "Thu"
        let rawDate = components[1].components(separatedBy: " Draw No.").first ?? ""

        // rawDate is in format "31 Oct 2024"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"

        guard let dateObj = formatter.date(from: rawDate) else { return nil }

        // Reformat to "31 Oct 2024 Thu"
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDate = formatter.string(from: dateObj)
        return "\(formattedDate) \(weekday)"
    }

    // MARK: - Latest/Selected Draw Result Card
    private func latestResultCard(for result: TOTOParseResult) -> some View {
        VStack(spacing: 12) {
            Text(selectedDrawNumber == nil ? "Latest Draw" : "Draw No. \(result.drawNumber ?? "")")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            Text("Winning Numbers: \(result.winningNumbers.map { String($0) }.joined(separator: ", "))")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Additional Number: \(result.additionalNumber ?? -1)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onAppear {
            print("selectedDrawNumber: \(selectedDrawNumber)")
        }
    }

    // MARK: - Past Results Section
//    private var pastResultsSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Past Results")
//                .font(.headline)
//                .foregroundColor(.blue)
//
//            ForEach(viewModel.pastResults(), id: \.drawNumber) { result in
//                ResultCardView(result: result)
//            }
//        }
//    }
    
    
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
