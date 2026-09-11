#if DEBUG
import Foundation
import SwiftData

/// Development data only. Seeds a realistic month relative to today so the app
/// opens in a working state instead of an empty shell. Never ships in Release.
enum SampleData {

    static func seedIfEmpty(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Expense>())) ?? 0
        guard existing == 0 else { return }

        let cal = Ledger.calendar
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now)) ?? .now
        }

        let ravi  = Person(name: "Ravi",  upiID: "ravi@upi")
        let meera = Person(name: "Meera", upiID: "meera@upi")
        let arjun = Person(name: "Arjun", upiID: "arjun@upi")
        let sam   = Person(name: "Sam",   upiID: "sam@upi")
        [ravi, meera, arjun, sam].forEach(context.insert)

        func add(
            _ paise: Int,
            _ note: String,
            _ offset: Int,
            essential: Bool = false,
            payer: Person? = nil,
            shares: [Share] = []
        ) {
            let expense = Expense(
                amountPaise: paise,
                note: note,
                spentAt: day(offset),
                isEssential: essential,
                payer: payer
            )
            context.insert(expense)
            shares.forEach(context.insert)
            if !shares.isEmpty { expense.shares = shares }
        }

        // Arjun fronted the cab; my ₹320 is still outstanding.
        add(64_000, "cab to airport", -11, payer: arjun, shares: [
            Share(amountPaise: 32_000),
            Share(amountPaise: 32_000, person: arjun, settledAt: day(-11)),
        ])

        // I paid ₹2,448 four ways. Ravi and Arjun have squared up; Meera hasn't.
        add(244_800, "Toit, dinner", -10, shares: [
            Share(amountPaise: 61_200),
            Share(amountPaise: 61_200, person: meera),
            Share(amountPaise: 61_200, person: ravi,  settledAt: day(-8)),
            Share(amountPaise: 61_200, person: arjun, settledAt: day(-8)),
        ])

        add(38_000,  "chai + samosa", -8)
        add(70_000,  "movie",         -7)
        add(115_000, "dinner",        -7)

        // Goa hotel five ways. Only Ravi is still outstanding.
        add(420_000, "Goa — hotel", -6, shares: [
            Share(amountPaise: 84_000),
            Share(amountPaise: 84_000, person: ravi),
            Share(amountPaise: 84_000, person: meera, settledAt: day(-4)),
            Share(amountPaise: 84_000, person: arjun, settledAt: day(-4)),
            Share(amountPaise: 84_000, person: sam,   settledAt: day(-4)),
        ])

        add(22_000, "auto",      -5)
        add(40_000, "groceries", -5, essential: true)

        // Days -4 to -1 have nothing on them. Today is all essentials.
        add(84_000, "groceries", 0, essential: true)
        add(18_000, "auto",      0, essential: true)
        add(22_000, "medicines", 0, essential: true)

        try? context.save()
    }
}
#endif
