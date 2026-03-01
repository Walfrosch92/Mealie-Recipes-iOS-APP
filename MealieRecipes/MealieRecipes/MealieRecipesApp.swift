import SwiftUI

@main
struct MealieRecipesApp: App {
    private let settings = AppSettings.shared
    @StateObject private var shoppingListVM = ShoppingListViewModel()
    @StateObject private var recipeListVM = RecipeListViewModel()
    @StateObject private var leftoverViewModel = LeftoverRecipeViewModel()
    @StateObject private var timerModel = TimerViewModel()
    @StateObject private var navigationModel = NavigationModel()
    @AppStorage("isSetupCompleted") private var isSetupCompleted = false

    init() {
        // Logging initialisieren wenn aktiviert
        if AppSettings.shared.enableLogging {
            LogManager.shared.startLogging()
            LogManager.shared.info("🚀 MealieRecipes App gestartet")
            LogManager.shared.info("📱 App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unbekannt")")
            LogManager.shared.info("📱 Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unbekannt")")
            LogManager.shared.info("📱 iOS Version: \(UIDevice.current.systemVersion)")
            LogManager.shared.info("📱 Gerät: \(UIDevice.current.model)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isSetupCompleted {
                    AppContainerView()
                        .onAppear {
                            if AppSettings.shared.enableLogging {
                                LogManager.shared.info("📱 AppContainerView geladen")
                            }
                        }
                } else {
                    SetupView()
                        .onAppear {
                            if AppSettings.shared.enableLogging {
                                LogManager.shared.info("📱 SetupView geladen")
                            }
                        }
                }
            }
            .environmentObject(settings)
            .environmentObject(shoppingListVM)
            .environmentObject(recipeListVM)
            .environmentObject(leftoverViewModel)
            .environmentObject(timerModel)
            .environmentObject(navigationModel)
            .id(settings.selectedLanguage)
            .onAppear {
                if !settings.isConfigured {
                    settings.configureAPIService()
                    if AppSettings.shared.enableLogging {
                        LogManager.shared.info("⚙️ API Service konfiguriert")
                    }
                }
            }
        }
    }
}
