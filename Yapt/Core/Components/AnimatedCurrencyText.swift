//
//  AnimatedCurrencyText.swift
//  Yapt
//
//  Animates currency changes using SwiftUI's animatable data support so
//  numbers count smoothly between states.
//

import SwiftUI

struct AnimatedCurrencyText: Animatable, View {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Formatters.currency.string(from: NSNumber(value: value)) ?? "$0")
            .monospacedDigit()
    }
}
