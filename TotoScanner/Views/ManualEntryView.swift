//
//  ManualEntryView.swift
//  TotoScanner
//
//  Created by mu on 22/3/25.
//

import SwiftUI

struct ManualEntryView: View {
    @EnvironmentObject var viewModel: TOTOViewModel
    @State private var userNumbers: [String] = Array(repeating: "", count: 6)
    @State private var finalResult: String? = nil
    @FocusState private var focusedIndex: Int?
    
    
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Your Numbers")
                .font(.headline)
            
            HStack {
                ForEach(0..<6, id: \ .self) { index in
                    TextField("", text: Binding(
                        get: { userNumbers[index] },
                        set: { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if let num = Int(filtered), (1...49).contains(num) {
                                userNumbers[index] = String(num)
                            } else if filtered.isEmpty {
                                userNumbers[index] = ""
                            }
                        }
                    ))
                    .frame(width: 50, height: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedIndex, equals: index)
                }
            }
            
            Button("Check Result") {
                let nums = userNumbers.compactMap { Int($0) }
                let hasDuplicates = Set(nums).count != nums.count
                
                if nums.count != 6 {
                    finalResult = "Please enter 6 valid numbers."
                } else if hasDuplicates {
                    finalResult = "Numbers must not be duplicated."
                } else {
                    let res = checkOrdinaryTotoResult(
                        winningNumbers: viewModel.selectedWinningNumber?.winningNumbers ?? [],
                        additionalNumber: viewModel.selectedWinningNumber?.additionalNumber ?? -1,
                        userNumbers: nums
                    )
                    
                    finalResult = res == nil ? "You won nothing 😢" : "You won Group \(res!) 🎉"
                }
            }
            .padding()
            
            if let finalResult = finalResult {
                Text(finalResult).font(.headline).foregroundColor(.blue)
            }
        }
        .padding()
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    UIApplication.shared.endEditing()
                }
            }
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
