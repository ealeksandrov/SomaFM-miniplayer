import SwiftUI

struct MenuHeaderView: View {
    let model: AppModel
    let trackAction: () -> Void

    @State private var hoversTrack = false
    @State private var hoversPlayback = false

    var body: some View {
        HStack(spacing: 4) {
            Button {
                model.togglePlayback()
            } label: {
                Image(systemName: isActive ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
                    .background(highlight(hoversPlayback), in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { hoversPlayback = $0 }
            .accessibilityLabel(isActive ? "Pause" : "Play")

            Button(action: trackAction) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.selectedChannel?.title ?? "SomaFM")
                        .font(.system(size: 13, weight: .semibold))
                    Text(model.currentTrack ?? model.statusDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(highlight(hoversTrack), in: RoundedRectangle(cornerRadius: 5))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(model.currentTrack == nil)
            .onHover { hoversTrack = $0 }
            .accessibilityLabel(model.currentTrack == nil ? "Playback status" : "Current track")
            .accessibilityValue(model.currentTrack ?? model.statusDescription)
            .accessibilityHint(model.currentTrack == nil ? "" : AppSettings.trackAction.title)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    /// Driven by the observable playback state rather than `wantsPlayback`, which lives on the
    /// non-observable player and would leave this view stale.
    private var isActive: Bool {
        switch model.playbackState {
        case .loading, .playing, .waiting: true
        case .failed, .idle, .paused: false
        }
    }

    private func highlight(_ hovering: Bool) -> Color {
        hovering ? Color.primary.opacity(0.1) : .clear
    }
}
