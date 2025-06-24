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

// Run the app
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
