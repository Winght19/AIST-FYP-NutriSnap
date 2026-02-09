//
//  UserProfile.swift
//  NutriSnap
//
//  Created by Tsz Wing on 17/1/2026.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var dailyCalorieTarget: Int
    var allergies: [String] // e.g. ["Peanuts", "Shellfish"]
    
    init(name: String, target: Int) {
        self.id = UUID()
        self.name = name
        self.dailyCalorieTarget = target
        self.allergies = []
    }
}//
//  UserProfile.swift
//  NutriSnap
//
//  Created by Tsz Wing on 17/1/2026.
//

