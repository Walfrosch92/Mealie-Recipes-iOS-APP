//
//  TimerLiveActivity.swift
//  MealieRecipes
//
//  Live Activity Widget für Timer
//  Wird angezeigt auf: iPhone (Dynamic Island + Lock Screen) + Apple Watch
//

import WidgetKit
import SwiftUI
import ActivityKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // MARK: - Lock Screen / Banner View (iPhone & Apple Watch)
            lockScreenView(context: context)
        } dynamicIsland: { context in
            // MARK: - Dynamic Island (nur iPhone 14 Pro+)
            DynamicIsland {
                // Expanded View (wenn Dynamic Island groß ist)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                        .font(.title2)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        if context.state.isRunning {
                            Text(context.state.endTime, style: .timer)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        } else {
                            Text("Fertig! ✓")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.recipeName)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Optionaler Progress Bar
                    if context.state.isRunning {
                        timerProgressBar(
                            endTime: context.state.endTime,
                            totalDuration: TimeInterval(context.attributes.originalDurationMinutes * 60)
                        )
                    }
                }
            } compactLeading: {
                // Compact Leading (kleines Icon links)
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                // Compact Trailing (Zeit rechts)
                if context.state.isRunning {
                    Text(context.state.endTime, style: .timer)
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } minimal: {
                // Minimal View (wenn sehr klein)
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    // MARK: - Lock Screen View
    
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimerAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(.orange)
                
                Text(context.state.recipeName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            
            HStack {
                if context.state.isRunning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verbleibende Zeit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(context.state.endTime, style: .timer)
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        
                        Text("Timer abgelaufen!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
            }
            
            // Progress Bar
            if context.state.isRunning {
                timerProgressBar(
                    endTime: context.state.endTime,
                    totalDuration: TimeInterval(context.attributes.originalDurationMinutes * 60)
                )
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.3))
        .activitySystemActionForegroundColor(.orange)
    }
    
    // MARK: - Progress Bar
    
    @ViewBuilder
    private func timerProgressBar(endTime: Date, totalDuration: TimeInterval) -> some View {
        GeometryReader { geometry in
            let remaining = max(0, endTime.timeIntervalSinceNow)
            let progress = remaining / totalDuration
            
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#Preview("Timer läuft", as: .content, using: TimerAttributes(recipeId: UUID().uuidString, originalDurationMinutes: 30)) {
    TimerLiveActivity()
} contentStates: {
    TimerAttributes.ContentState(
        endTime: Date().addingTimeInterval(600),
        recipeName: "Spaghetti Carbonara",
        remainingSeconds: 600,
        isRunning: true
    )
}

#Preview("Timer fertig", as: .content, using: TimerAttributes(recipeId: UUID().uuidString, originalDurationMinutes: 30)) {
    TimerLiveActivity()
} contentStates: {
    TimerAttributes.ContentState(
        endTime: Date(),
        recipeName: "Spaghetti Carbonara",
        remainingSeconds: 0,
        isRunning: false
    )
}
