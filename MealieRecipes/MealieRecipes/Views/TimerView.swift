import SwiftUI

struct TimerView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @Binding var durationMinutes: Double
    let recipeId: UUID
    @Environment(\.dismiss) var dismiss

    @State private var isEditing = false
    @State private var tempDuration: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text(LocalizedStringProvider.localized("timer_title"))
                .font(.largeTitle)
                .bold()

            if viewModel.timerActive {
                Text(remainingText())
                    .font(.title2)
                    .padding()

                if isEditing {
                    Slider(value: $tempDuration, in: 1...180, step: 1)
                    Text(String(format: LocalizedStringProvider.localized("new_duration"), Int(tempDuration)))

                    Button(LocalizedStringProvider.localized("apply")) {
                        durationMinutes = tempDuration
                        viewModel.start(durationMinutes: durationMinutes, recipeId: recipeId)
                        isEditing = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                HStack {
                    Button(LocalizedStringProvider.localized("change")) {
                        tempDuration = durationMinutes
                        isEditing = true
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Spacer()

                    Button(LocalizedStringProvider.localized("minimize")) {
                        dismiss()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Spacer()

                    Button(LocalizedStringProvider.localized("cancel")) {
                        viewModel.stop()
                        isEditing = false
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Slider(value: $durationMinutes, in: 1...180, step: 1)
                Text(String(format: LocalizedStringProvider.localized("duration"), Int(durationMinutes)))

                Button(LocalizedStringProvider.localized("start")) {
                    viewModel.start(durationMinutes: durationMinutes, recipeId: recipeId)
                    dismiss()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    private func remainingText() -> String {
        let minutes = Int(viewModel.timeRemaining) / 60
        let seconds = Int(viewModel.timeRemaining) % 60
        return String(format: LocalizedStringProvider.localized("remaining_time"), minutes, seconds)
    }
}
