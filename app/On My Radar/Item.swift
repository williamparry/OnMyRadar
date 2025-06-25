//
//  Item.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import Foundation
import SwiftData

enum TaskStatus: String, Codable {
    case todo = "+"      // On me to do
    case waiting = "."   // Waiting on someone else
    case done = "/"      // Done
}

@Model
final class Item {
    var title: String
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date
    var order: Int
    
    init(title: String, status: TaskStatus = .todo, order: Int = 0) {
        self.title = title
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
        self.order = order
    }
}
