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

//{ "numbers": "01,02,08,09,15,22,29", "drawNumber": "4043" , "isHalfBet": "false" , "totalNumberOfParts":"1" , "partsPurchased":"1" }

