//
//  main.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import Cocoa

// Remove @main from AppDelegate and use manual app launch
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Create a minimal menu bar with Edit menu for copy/paste support
let mainMenu = NSMenu()

// Edit menu
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

let editMenuItem = NSMenuItem()
editMenuItem.submenu = editMenu
mainMenu.addItem(editMenuItem)

app.mainMenu = mainMenu

// Run the app
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
