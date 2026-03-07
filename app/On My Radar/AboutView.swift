//
//  AboutView.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import SwiftUI

struct AboutView: View {
    private var versionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        
        switch (shortVersion, build) {
        case let (shortVersion?, build?) where shortVersion != build:
            return "Version \(shortVersion) (\(build))"
        case let (shortVersion?, _):
            return "Version \(shortVersion)"
        case let (_, build?):
            return "Version \(build)"
        default:
            return "Version"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
                .padding(.top, 10)
            
            Text("On My Radar")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(versionText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("A simple, elegant task manager that lives in your menu bar.")
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Keep track of what's on your radar with quick access to your tasks, customizable status labels, and a global hotkey for instant access.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            
            if let url = URL(string: "https://onmyradar.williamparry.com") {
                Link("onmyradar.williamparry.com", destination: url)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(width: 450, height: 400)
    }
}
