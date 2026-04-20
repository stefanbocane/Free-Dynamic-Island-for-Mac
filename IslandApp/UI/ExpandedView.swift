import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var controller: IslandPanelController
    @EnvironmentObject var router: WidgetRouter
    @EnvironmentObject var spotify: SpotifyService
    @EnvironmentObject var calendar: CalendarService

    var body: some View {
        if let payload = controller.dropPayload {
            FileDropTarget(payload: payload)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        } else {
            HStack(alignment: .top, spacing: 10) {
                SpotifyRich()
                    .frame(width: 280, alignment: .top)

                Divider().frame(width: 1).overlay(Color.white.opacity(0.08))

                CalendarRich()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Divider().frame(width: 1).overlay(Color.white.opacity(0.08))

                NotesPanel()
                    .frame(width: 190)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}
