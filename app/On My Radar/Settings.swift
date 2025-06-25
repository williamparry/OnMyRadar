//
//  Settings.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import Foundation
import SwiftData

@Model
final class Settings {
    var todoSymbol: String = "+"
    var todoLabel: String = "on me"
    var waitingSymbol: String = "."
    var waitingLabel: String = "waiting"
    var doneSymbol: String = "/"
    var doneLabel: String = "done"
    var useSymbols: Bool = false
    var inactivePanelOpacity: Double = 0.9
    
    init() {}
}

extension Settings {
    func getDisplay(for status: TaskStatus) -> String {
        if useSymbols {
            switch status {
            case .todo: return todoSymbol
            case .waiting: return waitingSymbol
            case .done: return doneSymbol
            }
        } else {
            switch status {
            case .todo: return todoLabel
            case .waiting: return waitingLabel
            case .done: return doneLabel
            }
        }
    }
    
    func getSymbol(for status: TaskStatus) -> String {
        switch status {
        case .todo: return todoSymbol
        case .waiting: return waitingSymbol
        case .done: return doneSymbol
        }
    }
}
