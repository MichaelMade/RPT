//
//  AppearanceProbe.swift
//  RPT
//
//  Debug-only accessibility probe used by UI tests to verify the effective
//  environment color scheme rather than only the persisted setting.
//

#if DEBUG
import SwiftUI

struct AppearanceProbe: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Appearance")
            .font(.system(size: 1))
            .foregroundStyle(.clear)
            .frame(width: 2, height: 2)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Effective appearance")
            .accessibilityIdentifier("appearance-probe")
            .accessibilityValue(colorScheme == .dark ? "dark" : "light")
    }
}
#endif
