import SwiftUI

struct AirPodsBatteryHUD: View {
    let event: HUDEvent

    var body: some View {
        HStack(spacing: 14) {
            Spacer()
            Image(systemName: "airpodspro")
                .font(.system(size: 16))
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                if let left = eachLabel(index: 0) { cell(symbol: "l.circle.fill", label: left) }
                if let right = eachLabel(index: 1) { cell(symbol: "r.circle.fill", label: right) }
                if let caseP = eachLabel(index: 2) { cell(symbol: "capsule.portrait.fill", label: caseP) }
                if eachLabel(index: 0) == nil, eachLabel(index: 1) == nil, eachLabel(index: 2) == nil,
                   let single = eachLabel(index: 3) {
                    cell(symbol: "earbuds", label: single)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    private func eachLabel(index: Int) -> String? {
        guard event.auxValues.indices.contains(index) else { return nil }
        let v = event.auxValues[index]
        if v < 0 { return nil }
        return "\(Int(v))%"
    }

    private func cell(symbol: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
