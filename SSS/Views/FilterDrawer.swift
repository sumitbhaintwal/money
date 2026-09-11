import SwiftUI
import SwiftData

/// The Money screen's filters, out of the way until asked for. Everything is
/// visible at once in here, which is what the chips could not do inline.
struct FilterDrawer: View {
    @Binding var query: ExpenseQuery
    let people: [Person]

    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    search
                    group("PERIOD") {
                        chips(ExpenseQuery.Period.allCases, selected: query.period) { query.period = $0 }
                    }
                    group("KIND") {
                        chips(ExpenseQuery.Kind.allCases, selected: query.kind) { query.kind = $0 }
                    }
                    if !people.isEmpty {
                        group("PERSON") { personChips }
                    }
                    group("SORT BY") {
                        chips(ExpenseQuery.Sort.allCases, selected: query.sort) { query.sort = $0 }
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)

            Button { dismiss() } label: {
                Text("DONE").font(Theme.F.display(19, .bold)).tracking(3)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.lit)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Theme.sheet)
    }

    private var header: some View {
        HStack {
            Label9("FILTERS", size: 14)
            Spacer()
            if query != ExpenseQuery() {
                Button { query = ExpenseQuery() } label: {
                    Label9("RESET", color: Theme.ink, size: 13)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.dim)
            TextField("search notes", text: $query.search)
                .font(Theme.F.display(18, .medium))
                .foregroundStyle(Theme.body)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !query.search.isEmpty {
                Button { query.search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.outline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .frame(height: 46)
        .padding(.horizontal, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label9(title, size: 11)
            content()
        }
    }

    private func chips<T: LabelledOption>(
        _ options: [T],
        selected: T,
        choose: @escaping (T) -> Void
    ) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                Chip(title: option.label, isOn: option == selected) { choose(option) }
            }
        }
    }

    private var personChips: some View {
        FlowLayout(spacing: 8) {
            Chip(title: "ANYONE", isOn: query.person == nil) { query.person = nil }
            ForEach(people) { person in
                Chip(
                    title: person.name.uppercased(),
                    isOn: query.person == person.persistentModelID
                ) {
                    query.person = query.person == person.persistentModelID ? nil : person.persistentModelID
                }
            }
        }
    }
}

/// Wraps chips onto as many lines as they need. The drawer has the room for it,
/// so nothing hides off the edge of a horizontal scroller.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
