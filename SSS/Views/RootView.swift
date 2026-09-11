import SwiftUI
import SwiftData

enum AppTab: Hashable { case today, people }

struct RootView: View {
    @State private var tab: AppTab = .today
    @State private var addingExpense = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "circle.grid.3x3.fill", value: AppTab.today) {
                TodayView(showPeople: { tab = .people })
            }
            Tab("People", systemImage: "person.2.fill", value: AppTab.people) {
                PeopleView()
            }
        }
        // The bar shrinks out of the way as you read down a month.
        .tabBarMinimizeBehavior(.onScrollDown)
        // Without this the selected tab takes the system blue, which is the
        // only colour anywhere in the app.
        .tint(Theme.lit)
        .tabViewBottomAccessory {
            AddAccessory { addingExpense = true }
        }
        .sheet(isPresented: $addingExpense) {
            AddExpenseView()
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }
}

/// Lives in the tab bar's accessory slot, so logging is one tap from anywhere
/// and the bar itself carries the number you are trying to keep down.
private struct AddAccessory: View {
    @Query(sort: \Expense.spentAt, order: .reverse) private var expenses: [Expense]
    let onAdd: () -> Void

    private var todayPaise: Int {
        let cal = Ledger.calendar
        return expenses
            .filter { cal.isDateInToday($0.spentAt) }
            .reduce(0) { $0 + $1.mySharePaise }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Label9("TODAY", size: 10)
                Text(Money.rupees(todayPaise))
                    .font(.system(size: 16, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
            Button(action: onAdd) {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("ADD").font(Theme.F.display(15, .bold)).tracking(2)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.lit)
            .accessibilityLabel("Add expense")
        }
        .padding(.horizontal, 16)
    }
}
