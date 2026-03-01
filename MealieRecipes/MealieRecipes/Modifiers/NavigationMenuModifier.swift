//
//  NavigationMenuModifier.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 28.04.25.
//


//
//  NavigationMenuModifier.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 28.04.25.
//

import SwiftUI

struct NavigationMenuModifier: ViewModifier {
    @State private var isShowingMenu = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingMenu = true
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $isShowingMenu) {
                NavigationView {
                    List {
                        NavigationLink(destination: SetupView()) {
                            Label("Einstellungen", systemImage: "gear")
                        }
                        NavigationLink(destination: ShoppingListView()) {
                            Label("Einkaufsliste", systemImage: "cart")
                        }
                        NavigationLink(destination: ArchivedShoppingListsView()) {
                            Label("Archivierte Listen", systemImage: "archivebox")
                        }
                    }
                    .navigationTitle("Menü")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") {
                                isShowingMenu = false
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    func withNavigationMenu() -> some View {
        self.modifier(NavigationMenuModifier())
    }
}
