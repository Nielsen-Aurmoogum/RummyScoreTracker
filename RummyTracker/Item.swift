//
//  Item.swift
//  RummyTracker
//
//  Created by Nielsen Aurmoogum on 05/04/2026.
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
