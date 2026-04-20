import SwiftUI

struct IslandRootView: View {
    @EnvironmentObject var controller: IslandPanelController
    @EnvironmentObject var spotify: SpotifyService
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var router: WidgetRouter
    @EnvironmentObject var accessibility: AccessibilityPreferences
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack(alignment: .top) {
            PillBackground()
                .padding(.top, IslandPanelController.contentTopPadding(for: controller.state))
            content
                .padding(.horizontal, 10)
                .padding(.top, IslandPanelController.contentTopPadding(for: controller.state) + 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(accessibility.morphAnimation, value: controller.state)
        .animation(accessibility.morphAnimation, value: router.activeWidget)
        .onReceive(NotificationCenter.default.publisher(for: .islandOpenSettings)) { _ in
            openSettings()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state {
        case .compact:
            CompactView()
        case .expanded:
            ExpandedView()
        case .transientHUD(let hud):
            HUDView(event: hud)
        case .hidden:
            Color.clear
        }
    }
}

struct PillBackground: View {
    @EnvironmentObject var accessibility: AccessibilityPreferences

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(backgroundStyle)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(accessibility.reduceTransparency ? 0 : 0.35),
                    radius: 16, x: 0, y: 6)
    }

    private var backgroundStyle: some ShapeStyle {
        if accessibility.reduceTransparency {
            return AnyShapeStyle(Color.black.opacity(0.95))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
