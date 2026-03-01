//
//  TimerButtonGroupView.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 23.05.25.
//
import SwiftUI

struct TimerButtonGroupView: View {
    let times: [TimeParser.ParsedTime]
    let selectTimer: (Int) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(Array(times.enumerated()), id: \.1.id) { index, parsed in
                Button(action: {
                    selectTimer(parsed.minutes)
                }) {
                    HStack(spacing: 4) {
                        Text("\(index + 1): \(parsed.minutes) min")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                        Image(systemName: "timer")
                            .foregroundColor(.blue)
                    }
                    .padding(4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(minWidth: 100)
    }
}
