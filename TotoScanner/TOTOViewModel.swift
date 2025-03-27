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
    @Published var latestWinningNumber: TOTOParseResult? = nil
    @Published var errorMessage: String?

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
        guard let url = URL(string: "https://www.singaporepools.com.sg/DataFileArchive/Lottery/Output/toto_result_top_draws_en.html?v=2025y1m10d15h45m") else {
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
    
    private func parseTOTOResults(from html: String) throws {
        let doc: Document = try SwiftSoup.parse(html)
        let drawNumbers = try doc.getElementsByClass("table table-striped orange-header")
        let winningNumbers = try doc.getElementsByClass("table table-striped")
        var index = 0
        
        try drawNumbers.forEach { row in
            let drawNumber = extractDrawNumber(from: try row.text())
            let numbers = extractWinningNumber(from: try winningNumbers.get(index).text())
            let additionalNumber = extractAdditionalNumber(from: try winningNumbers.get(index+1).text())

            if index == 0 {
                latestWinningNumber = TOTOParseResult(drawNumber: drawNumber!, winningNumbers: numbers, additionalNumber: additionalNumber)
            }
            index += 2
        }
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
