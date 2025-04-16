//
//  PrizeResponse.swift
//  TotoScanner
//
//  Created by Muhua on 13/1/25.
//

import Foundation

/// The top-level response has one field: 'd'
struct OuterResponse: Codable {
    let d: String
}

/// The nested JSON has three fields:
/// "Prizes", "WinningNumbers", and "AdditionalNumber".
struct NestedResponse: Codable {
    let Prizes: [Prize]
    let WinningNumbers: [String]
    let AdditionalNumber: String
}

/// A Prize object with the fields shown in your example
struct Prize: Codable {
    let GroupNumber: Int
    let NumberOfSharesWon: Int
    let ShareAmount: Int
    let Total: Int
    let TotalNumberOfParts: Int
    let NumberOfPartsPurchased: Int
}
