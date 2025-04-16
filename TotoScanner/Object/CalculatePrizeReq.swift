//
//  CalculatePrizeRer.swift
//  TotoScanner
//
//  Created by Muhua on 13/1/25.
//

import Foundation

struct CalculatePrizeReq : Codable {
    let numbers: String
    let drawNumber: String
    let isHalfBet: Bool = false
    let totalNumberOfParts: Int = 1
    let partsPurchased: Int = 1
}

