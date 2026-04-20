import SwiftUI

struct ChargingHUD: View {
    let event: HUDEvent

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Charging")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(Int(event.primaryValue * 100))%")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            ValueBar(value: event.primaryValue, accent: .green)
                .frame(width: 80)
        }
        .padding(.horizontal, 14)
    }
}
