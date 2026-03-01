import SwiftUI

struct GlobalTimerBanner: View {
    @EnvironmentObject var timerModel: TimerViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    var body: some View {
        // Der Banner bleibt solange recipeId oder lastRecipeId nicht nil ist
        if (timerModel.timerActive || timerModel.showBannerAfterFinish),
           let recipeId = timerModel.recipeId ?? timerModel.lastRecipeId {

            Button(action: {
                navigationModel.navigateToRecipe(recipeId: recipeId)
                // Banner wird NUR durch Klick entfernt!
                if timerModel.showBannerAfterFinish {
                    timerModel.clearAfterFinish()
                }
            }) {
                HStack {
                    Image(systemName: "timer")
                    Text(formattedTime(timerModel.timeRemaining))
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .transition(.move(edge: .top))
            .animation(.default, value: timerModel.timeRemaining)
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        if time > 0 {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return NSLocalizedString("timer_finished", comment: "Timer abgelaufen")
        }
    }
}
