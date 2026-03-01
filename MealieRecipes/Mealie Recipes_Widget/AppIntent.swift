//
//  AppIntent.swift
//  Mealie Recipes_Widget
//
//  Created by Michael Haiszan on 07.12.25.
//

import WidgetKit
import AppIntents

@available(iOS 16.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
