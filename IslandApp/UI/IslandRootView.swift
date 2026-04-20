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
            // Pill fills the entire panel so its flat top sits flush with the
            // screen edge; only content is pushed down by contentTopPadding.
            PillBackground(state: controller.state)
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
    let state: IslandState
    @EnvironmentObject var accessibility: AccessibilityPreferences

    var body: some View {
        // Flat top, rounded bottom — pill flows from the screen top like iPhone
        // Dynamic Island. Transient HUDs still float free below the menu bar, so
        // they keep the pill shape (rounded on all sides).
        let bottomRadius: CGFloat = 22
        let topRadius: CGFloat = state.isHUD ? 22 : 0
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        )
        return shape
            .fill(Color.black.opacity(accessibility.effectivePillOpacity))
    }
}
