import SwiftUI
import ZapCore

/// The launcher card: a large search field over a scrolling, keyboard-navigable
/// list of matching apps.
struct SearchView: View {
    @ObservedObject var model: LauncherModel

    private let cardWidth: CGFloat = 640
    private let listHeight: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query,
                onMoveUp: model.moveUp,
                onMoveDown: model.moveDown,
                onSubmit: model.activate,
                onCancel: model.cancel
            )
            .padding(.horizontal, 22)
            .frame(height: 68)

            Divider().opacity(0.4)

            resultsArea
                .frame(width: cardWidth, height: listHeight)
        }
        .frame(width: cardWidth)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
    }

    @ViewBuilder
    private var resultsArea: some View {
        if model.results.isEmpty {
            VStack {
                Spacer()
                Text(model.query.isEmpty ? "No applications found" : "No matches")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(model.results.prefix(60).enumerated()), id: \.element.id) { index, app in
                            ResultRow(
                                icon: model.icon(for: app),
                                name: app.name,
                                selected: index == model.selection
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selection = index
                                model.activate()
                            }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.selection) { _, newValue in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(newValue, anchor: .center) }
                }
            }
        }
    }
}

private struct ResultRow: View {
    let icon: NSImage
    let name: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)
            Text(name)
                .font(.system(size: 16))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.85) : .clear)
        )
        .foregroundStyle(selected ? Color.white : Color.primary)
    }
}
