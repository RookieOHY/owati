import Foundation

// 饮料类型 记入进度=毫升×水合系数 咖啡茶牛奶果汁都比水略低
enum DrinkType: String, CaseIterable {
    case water
    case coffee
    case tea
    case milk
    case juice

    var name: String {
        switch self {
        case .water: return "水"
        case .coffee: return "咖啡"
        case .tea: return "茶"
        case .milk: return "牛奶"
        case .juice: return "果汁"
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .coffee: return "☕"
        case .tea: return "🍵"
        case .milk: return "🥛"
        case .juice: return "🧃"
        }
    }

    var ratio: Double {
        switch self {
        case .water: return 1.0
        case .coffee: return 0.9
        case .tea: return 0.95
        case .milk: return 0.9
        case .juice: return 0.85
        }
    }
}
