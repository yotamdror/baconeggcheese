//
//  BECApp.swift
//  BEC
//
//  Created by YD on 4/25/26.
//

import SwiftUI
import CoreText

@main
struct BECApp: App {
    init() {
        if let url = Bundle.main.url(forResource: "CooperBlack", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
