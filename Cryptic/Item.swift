//
//  Item.swift
//  Cryptic
//
//  Created by Swanand Tanavade on 8/26/25.
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
