//
//  Item.swift
//  NutriSnap
//
//  Created by Tsz Wing on 13/1/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
