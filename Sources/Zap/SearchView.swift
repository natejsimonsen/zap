import SwiftUI
import ZapCore

/// The launcher card: a large search field over a scrolling, keyboard-navigable
/// list of matching apps. Sizing, accent colour, and translucency come from config.
struct SearchView: View {
    @ObservedObject var model: LauncherModel

    private var metrics: LayoutMetrics { model.config.density.metrics }
    private var cardWidth: CGFloat { metrics.cardWidth }
    private var listHeight: CGFloat { metrics.listHeight }

    private var accent: Color {
        if let c = model.config.resolvedAccent() {
            return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
        }
        return .accentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query,
                fontSize: metrics.searchFontSize,
                onMoveUp: model.moveUp,
                onMoveDown: model.moveDown,
                onSubmit: model.activate,
                onCancel: model.cancel
            )
            .padding(.horizontal, 22)
            .frame(height: metrics.searchFieldHeight)

            Divider().opacity(0.4)

            resultsArea
                .frame(width: cardWidth, height: listHeight)
        }
        .frame(width: cardWidth)
        // Fill the rounded shape directly (via `in:`) so the material/tint are clipped
        // to the corners — a plain `.background(material).clipShape(...)` leaves the
        // material's NSVisualEffectView as an unclipped square behind the rounded card.
        .background(
            Color(nsColor: .windowBackgroundColor).opacity(1 - model.config.transparency),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
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
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, app in
                            ResultRow(
                                icon: model.icon(for: app),
                                name: app.name,
                                selected: index == model.selection,
                                accent: accent,
                                iconSize: metrics.iconSize,
                                fontSize: metrics.rowFontSize,
                                verticalPadding: metrics.rowVerticalPadding
                            )
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
                    guard model.results.indices.contains(newValue) else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(model.results[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct ResultRow: View {
    let icon: NSImage
    let name: String
    let selected: Bool
    let accent: Color
    let iconSize: CGFloat
    let fontSize: CGFloat
    let verticalPadding: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(name)
                .font(.system(size: fontSize))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? accent.opacity(0.85) : .clear)
        )
        .foregroundStyle(selected ? Color.white : Color.primary)
    }
}
