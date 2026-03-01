import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var shoppingListVM: ShoppingListViewModel
    @EnvironmentObject var recipeListVM: RecipeListViewModel
    @EnvironmentObject var leftoverViewModel: LeftoverRecipeViewModel
    @EnvironmentObject var timerModel: TimerViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    var isiPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: isiPhone ? 22 : 32) {
                        Spacer(minLength: isiPhone ? 28 : 44)

                        Text(LocalizedStringProvider.localized("welcome_title"))
                            .font(isiPhone ? .title : .largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity)

                        VStack(spacing: isiPhone ? 18 : 24) {
                            Group {
                                SectionHeader(title: LocalizedStringProvider.localized("section_recipes"))
                                HStack(spacing: isiPhone ? 10 : 16) {
                                    WelcomeCard(
                                        icon: "book.fill",
                                        iconColor: .orange,
                                        text: LocalizedStringProvider.localized("show_recipes"),
                                        badge: recipeListVM.allRecipes.count,
                                        multiline: isiPhone,
                                        showBadgeOnIPhone: true
                                    ) {
                                        RecipeListView()
                                    }
                                    WelcomeCard(
                                        icon: "plus.circle.fill",
                                        iconColor: .blue,
                                        text: LocalizedStringProvider.localized("recipe_upload"),
                                        multiline: isiPhone
                                    ) {
                                        RecipeUploadView()
                                    }
                                }
                                .padding(.horizontal, isiPhone ? 10 : 0)
                            }

                            Group {
                                SectionHeader(title: LocalizedStringProvider.localized("section_shopping"))
                                HStack(spacing: isiPhone ? 10 : 16) {
                                    WelcomeCard(
                                        icon: "cart.fill",
                                        iconColor: .green,
                                        text: LocalizedStringProvider.localized("shopping_list"),
                                        badge: shoppingListVM.shoppingList.filter { !$0.checked }.count,
                                        multiline: isiPhone,
                                        showBadgeOnIPhone: true
                                    ) {
                                        ShoppingListView()
                                    }
                                    WelcomeCard(
                                        icon: "archivebox.fill",
                                        iconColor: .gray,
                                        text: LocalizedStringProvider.localized("archived_lists"),
                                        multiline: isiPhone
                                    ) {
                                        ArchivedShoppingListsView()
                                    }
                                }
                                .padding(.horizontal, isiPhone ? 10 : 0)
                            }

                            Group {
                                SectionHeader(title: LocalizedStringProvider.localized("section_planning"))
                                HStack(spacing: isiPhone ? 10 : 16) {
                                    WelcomeCard(
                                        icon: "calendar",
                                        iconColor: .purple,
                                        text: LocalizedStringProvider.localized("meal_plan"),
                                        multiline: isiPhone
                                    ) {
                                        MealplanView()
                                    }
                                    WelcomeCard(
                                        icon: "wand.and.stars",
                                        iconColor: .mint,
                                        text: LocalizedStringProvider.localized("leftover.title"),
                                        multiline: isiPhone
                                    ) {
                                        LeftoverRecipeFinderView(viewModel: leftoverViewModel)
                                    }
                                }
                                .padding(.horizontal, isiPhone ? 10 : 0)
                            }

                            Group {
                                SectionHeader(title: LocalizedStringProvider.localized("section_other"))
                                HStack(spacing: isiPhone ? 10 : 16) {
                                    WelcomeCard(
                                        icon: "gearshape.fill",
                                        iconColor: .secondary,
                                        text: LocalizedStringProvider.localized("settings"),
                                        multiline: isiPhone
                                    ) {
                                        SetupView(isInitialSetup: false)
                                    }
                                }
                                .padding(.horizontal, isiPhone ? 10 : 0)
                            }
                        }
                        .padding(.top, isiPhone ? 6 : 8)

                        Spacer(minLength: isiPhone ? 28 : 44)
                    }
                    .padding(.vertical, isiPhone ? 10 : 0)
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                recipeListVM.loadCachedOrFetchRecipes(batchSize: 10)
                Task {
                    await shoppingListVM.loadShoppingListFromServer()
                }
                if settings.isConfigured,
                   let url = URL(string: settings.serverURL) {
                    var headers: [String: String] = [:]
                    if settings.sendOptionalHeaders {
                        headers[settings.optionalHeaderKey1] = settings.optionalHeaderValue1
                        headers[settings.optionalHeaderKey2] = settings.optionalHeaderValue2
                        headers[settings.optionalHeaderKey3] = settings.optionalHeaderValue3
                    }
                    APIService.shared.configure(
                        baseURL: url,
                        token: settings.token,
                        optionalHeaders: headers
                    )
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { navigationModel.selectedRecipeId != nil },
                set: { newValue in
                    if !newValue {
                        navigationModel.selectedRecipeId = nil
                    }
                })
            ) {
                if let recipeId = navigationModel.selectedRecipeId {
                    RecipeDetailView(recipeId: recipeId)
                        .environmentObject(timerModel)
                }
            }
        }
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - WelcomeCard mit multiline Option und selektivem Badge

struct WelcomeCard<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let text: String
    var badge: Int? = nil
    var multiline: Bool = false
    var showBadgeOnIPhone: Bool = false
    let destination: () -> Destination

    @Environment(\.colorScheme) var colorScheme
    var isiPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var cardSize: CGFloat { isiPhone ? 36 : 44 }
    var fontSize: CGFloat { isiPhone ? 22 : 26 }
    var verticalPadding: CGFloat { isiPhone ? 26 : 16 }
    var horizontalPadding: CGFloat { isiPhone ? 16 : 20 }
    var cardCornerRadius: CGFloat { isiPhone ? 16 : 18 }
    var spacing: CGFloat { isiPhone ? 14 : 18 }
    var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.15) : Color(.systemBackground)
    }

    var body: some View {
        NavigationLink(destination: destination()) {
            Group {
                if isiPhone {
                    VStack(spacing: 6) {
                        Text(text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        if let badge, badge > 0, showBadgeOnIPhone {
                            BadgeView(count: badge)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    HStack(spacing: spacing) {
                        Image(systemName: icon)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(iconColor)
                            .frame(width: cardSize, height: cardSize)
                            .background(Circle().fill(iconColor.opacity(0.11)))
                        Text(text)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(multiline ? 2 : 1)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, 2)
                        Spacer(minLength: 8)
                        if let badge, badge > 0 {
                            BadgeView(count: badge)
                                .padding(.leading, 2)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(cardBackground)
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.25) : Color(.black).opacity(0.06), radius: isiPhone ? 4 : 5, x: 0, y: 2)
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - BadgeView

struct BadgeView: View {
    let count: Int
    @Environment(\.colorScheme) var colorScheme

    var badgeBackground: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        } else {
            return Color(.systemGray6)
        }
    }

    var body: some View {
        Text("\(count)")
            .font(.caption)
            .fontWeight(.semibold)
            .frame(width: 24, height: 24)
            .background(
                Circle().fill(badgeBackground)
            )
            .overlay(Circle().stroke(Color(.separator), lineWidth: 1.2))
            .foregroundColor(Color.accentColor)
            .shadow(color: Color(.black).opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: - NavigationModel

class NavigationModel: ObservableObject {
    @Published var selectedRecipeId: UUID?

    func navigateToRecipe(recipeId: UUID) {
        selectedRecipeId = recipeId
    }
}
