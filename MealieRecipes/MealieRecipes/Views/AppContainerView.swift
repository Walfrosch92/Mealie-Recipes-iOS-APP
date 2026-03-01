import SwiftUI

struct AppContainerView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var shoppingListVM: ShoppingListViewModel
    @EnvironmentObject var recipeListVM: RecipeListViewModel
    @EnvironmentObject var leftoverViewModel: LeftoverRecipeViewModel
    @EnvironmentObject var timerModel: TimerViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                WelcomeView()
                if timerModel.timerActive || timerModel.showBannerAfterFinish {
                    GlobalTimerBanner()
                        .padding(.top, geometry.safeAreaInsets.top + 8) // Automatisch unter der Navigation Bar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: timerModel.timerActive)
        // ⬇️ HIER Callback Zuweisung, immer aktuell:
        .onAppear {
            timerModel.onAutoNavigateToRecipe = { recipeId in
                navigationModel.navigateToRecipe(recipeId: recipeId)
                // Optional: timerModel.clearAfterFinish() falls Banner gleich weg soll
            }
        }
    }
}
