import SwiftUI

struct FileDropTarget: View {
    let payload: DropPayload
    @EnvironmentObject var controller: IslandPanelController

    var body: some View {
        HStack(spacing: 10) {
            ForEach(DropTarget.allCases) { target in
                targetCell(for: target)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .transition(.opacity)
    }

    private func targetCell(for target: DropTarget) -> some View {
        Button {
            controller.handleDrop(urls: payload.urls, target: target)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: target.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(target.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 80, height: 56)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
