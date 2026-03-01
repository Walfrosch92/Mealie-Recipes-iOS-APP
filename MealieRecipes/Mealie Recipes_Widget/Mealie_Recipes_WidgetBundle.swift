//
//  Mealie_Recipes_WidgetBundle.swift
//  Mealie Recipes_Widget
//
//  Created by Michael Haiszan on 07.12.25.
//

import WidgetKit
import SwiftUI

@main
struct Mealie_Recipes_WidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        Mealie_Recipes_Widget()
        
        // ✅ Control Widget nur für iOS 18.0+
        if #available(iOS 18.0, *) {
            Mealie_Recipes_WidgetControl()
        }
        
        // Generische Demo Live Activity (optional, kann entfernt werden)
        // Mealie_Recipes_WidgetLiveActivity()
        
        // ✅ Timer Live Activity für Rezepte (iOS 16.1+)
        if #available(iOS 16.1, *) {
            TimerLiveActivity()
        }
    }
}
