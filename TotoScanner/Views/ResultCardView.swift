//
//  ResultCardView.swift
//  TotoScanner
//
//  Created by mu on 29/3/25.
//
import SwiftUI

struct ResultCardView: View {
    let result: TOTOParseResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Draw No. \(result.drawNumber)")
                .font(.headline)
                .bold()
                .foregroundColor(.blue)

            Text("Winning Numbers: \(result.winningNumbers.map { String($0) }.joined(separator: ", "))")
                .font(.subheadline)
                .foregroundColor(.primary)

            Text("Additional Number: \(result.additionalNumber)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
