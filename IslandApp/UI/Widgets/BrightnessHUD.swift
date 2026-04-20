import SwiftUI

struct BrightnessHUD: View {
    let event: HUDEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.yellow)
                .frame(width: 22, height: 22)
            ValueBar(value: event.primaryValue, accent: .yellow)
        }
        .padding(.horizontal, 14)
    }
}
