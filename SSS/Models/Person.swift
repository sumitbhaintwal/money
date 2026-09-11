import Foundation
import SwiftData

@Model
final class Person {
    var name: String
    var upiID: String?
    var createdAt: Date

    init(name: String, upiID: String? = nil, createdAt: Date = .now) {
        self.name = name
        self.upiID = upiID
        self.createdAt = createdAt
    }

    var initial: String { String(name.prefix(1)) }
}
