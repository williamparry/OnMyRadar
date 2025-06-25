//
//  AboutView.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import SwiftUI

struct RadarIconView: View {
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
            
            // Radar circles
            ForEach(1..<5) { i in
                Circle()
                    .stroke(Color.green.opacity(0.8 - Double(i) * 0.2), lineWidth: 1)
                    .frame(width: CGFloat(i) * 15, height: CGFloat(i) * 15)
            }
            
            // Radar line
            Rectangle()
                .fill(Color.green.opacity(0.8))
                .frame(width: 2, height: 30)
                .offset(y: -15)
            
            // Center dot
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App icon
            Image("AppIconImage")
                .resizable()
                .frame(width: 100, height: 100)
                .padding(.top, 10)
            
            Text("On My Radar")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Version 1.0")
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
            
            Spacer()
        }
        .padding(30)
        .frame(width: 450, height: 400)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}