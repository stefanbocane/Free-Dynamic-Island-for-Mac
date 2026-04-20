import SwiftUI

/// Wraps content so its transitions respect accessibility preferences.
/// Spring morph by default; crossfade when reduce-motion is enabled.
struct MorphContainer<Content: View>: View {
    @EnvironmentObject var accessibility: AccessibilityPreferences
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .transition(transition)
    }

    private var transition: AnyTransition {
        accessibility.reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity),
                removal: .opacity
            )
    }
}
