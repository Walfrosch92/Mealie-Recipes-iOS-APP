//
//  Recipe.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 27.04.25.
//


import Foundation

struct Recipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let image: String?
    let ingredients: [Ingredient]
    let instructions: [String]
}
