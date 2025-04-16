//
//  Untitled.swift
//  TotoScanner
//
//  Created by mu on 19/3/25.
//

import SwiftUI
import SwiftSoup
//import Vision

class TOTOViewModel: ObservableObject {
    @Published var selectedWinningNumber: TOTOParseResult? = nil
    @Published var latestWinningNumber: TOTOParseResult? = nil
    @Published var latestDrawDate: String? = nil
    @Published var errorMessage: String?
    @Published var dateToDrawNumber: [String: [String: String]] = [:]
    @Published var sortedDrawDates: [String] = []

    func fetchAndParseTOTOResults(completion: @escaping (Result<String, Error>) -> Void) {
        fetchHTML { fetchResult in
            DispatchQueue.main.async {
                switch fetchResult {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    
                case .success(let htmlString):
                    do {
                        try self.parseTOTOResults(from: htmlString)
                        completion(.success("Success"))
                    } catch {
                        self.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    
    
    
    func fetchHTML(completion: @escaping (Result<String, Error>) -> Void) {
        let baseURL = "https://www.singaporepools.com.sg/DataFileArchive/Lottery/Output/toto_result_top_draws_en.html?v="
        let finalURLString = baseURL + getCurrentDateTimeString()

        guard let url = URL(string: finalURLString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad URL"])))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                let parsingError = NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse HTML string"])
                completion(.failure(parsingError))
                return
            }
            completion(.success(htmlString))
        }
        task.resume()
    }
    
    func getCurrentDateTimeString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyy'y'MM'M'dd'd'HH'h'mm'm'"
        
        let currentDate = Date()
        let dateString = dateFormatter.string(from: currentDate)
        
        return dateString
    }
    
    func fetchDrawDates() {
        let baseURL = "https://www.singaporepools.com.sg/DataFileArchive/Lottery/Output/toto_result_draw_list_en.html?v="
        let finalURLString = baseURL + getCurrentDateTimeString()

        guard let url = URL(string: finalURLString) else {
            print("Error: Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
                    
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }

            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                print("Error: Failed to parse HTML response")
                return
            }

            // Parse HTML to extract date and draw number
            DispatchQueue.main.async {
                self.dateToDrawNumber = self.parseHTMLToMap(htmlString: htmlString)
                self.sortedDrawDates = self.dateToDrawNumber
                    .sorted { lhs, rhs in
                        let lhsDraw = Int(lhs.value["value"] ?? "") ?? 0
                        let rhsDraw = Int(rhs.value["value"] ?? "") ?? 0
                        return lhsDraw > rhsDraw
                    }
                    .map { $0.key }
                
                 print("sortedDrawDates: \(self.sortedDrawDates)")
                // print("Data fetched successfully!")
                self.objectWillChange.send()
            }
        }
        task.resume()
    }
    
    func parseHTMLToMap(htmlString: String) -> [String: [String: String]] {
        var dateToDrawInfo = [String: [String: String]]()

        // Updated regex pattern to capture sppl, value, and date
        let pattern = "<option[^>]*queryString='sppl=([^']+)'[^>]*value='(\\d+)'[^>]*>([A-Za-z]{3},\\s\\d{1,2}\\s[A-Za-z]{3}\\s\\d{4})</option>"

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = htmlString as NSString
            let results = regex.matches(in: htmlString, options: [], range: NSRange(location: 0, length: nsString.length))

            for result in results {
                if result.numberOfRanges == 4 {
                    let spplValue = nsString.substring(with: result.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = nsString.substring(with: result.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let date = nsString.substring(with: result.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if (latestDrawDate == nil) {
                        latestDrawDate = value
                    }
                    
                    // Create a dictionary with both value and sppl
                    dateToDrawInfo[date] = ["value": value, "sppl": spplValue]
                }
            }
        }
        return dateToDrawInfo
    }
    
    func fetchWinningNumber(with sppl: String, completion: @escaping (Result<String, Error>) -> Void) {
        getResult(with: sppl) { fetchResult in
            DispatchQueue.main.async {
                switch fetchResult {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    
                case .success(let htmlString):
                    do {
                        try self.parseTOTOResults(from: htmlString)
                        completion(.success("Success"))
                    } catch {
                        self.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                }
            }
        }
        
    }
    
    

    func getResult(with sppl: String, completion: @escaping (Result<String, Error>) -> Void) {
   
        
        let baseURL = "https://www.singaporepools.com.sg/en/product/sr/Pages/toto_results.aspx?sppl="
        let finalURLString = baseURL + sppl

        guard let url = URL(string: finalURLString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad URL"])))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
                    
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                let parsingError = NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse HTML string"])
                completion(.failure(parsingError))
                return
            }
            completion(.success(htmlString))
        }
        task.resume()
    }
    
    private func parseTOTOResults(from html: String) throws {
        let doc: Document = try SwiftSoup.parse(html)
        let drawSections = try doc.getElementsByClass("table table-striped orange-header")
        let winningNumbers = try doc.getElementsByClass("table table-striped")
        var index = 0
        
        for (i, row) in drawSections.enumerated() {
            let rawText = try row.text()
            let drawNumber = extractDrawNumber(from: rawText)
            let drawDate = extractDrawDate(from: rawText)
                
            let numbers = extractWinningNumber(from: try winningNumbers.get(index).text())
            let additionalNumber = extractAdditionalNumber(from: try winningNumbers.get(index + 1).text())

            let result = TOTOParseResult(
                drawNumber: drawNumber ?? "",
                drawDate: drawDate ?? "",
                winningNumbers: numbers,
                additionalNumber: additionalNumber ?? 0
            )
            
            selectedWinningNumber = result
            
   
            if latestWinningNumber == nil {
                latestWinningNumber = result
                latestDrawDate = drawDate
                print("latestDrawDate: \(latestDrawDate)")
                print("latestWinningNumber: \(latestWinningNumber)")
                
                break
            }
        }
    }
    
    func extractDrawDate(from text: String?) -> String? {
        guard let text = text else { return nil }
        let parts = text.components(separatedBy: "Draw No.")
        return parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractDrawNumber(from text: String?) -> String? {
        guard let text = text else { return nil }
        return String(text.suffix(4))
    }

    private func extractWinningNumber(from text: String?) -> [Int] {
        guard let text = text else { return [] }
        let numbers = text.split(separator: "Winning Numbers ")[0].split(separator: " ")
        return numbers.compactMap { Int($0) }
    }

    private func extractAdditionalNumber(from text: String?) -> Int? {
        guard let text = text else { return nil }
        return Int(text.split(separator: "Additional Number ")[0])
    }
}
