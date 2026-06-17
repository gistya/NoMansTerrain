enum Terrain: CustomStringConvertible, Sendable, Codable {
    enum Category: String, Codable, Sendable {
        case standard = ""
        case prime = "Prime"
        case purple = "Purple"
    }
    
    enum Limit: String {
        case min = "Min"
        case max = "Max"
    }
    
    var limit: Limit {
        switch self {
        case let .alien           (_, limit): limit
        case let .alpine          (_, limit): limit
        case let .caverns         (_, limit): limit
        case let .craters         (_, limit): limit
        case let .desert          (_, limit): limit
        case let .floatingIslands (_, limit): limit
        case let .grandCanyon     (_, limit): limit
        case let .hugeArches      (_, limit): limit
        case let .lilyPad         (_, limit): limit
        case let .mountainRavines (_, limit): limit
        case let .waterWorld      (_, limit): limit
        }
    }
    
    case alien            (Category, Limit)
    case alpine           (Category, Limit)
    case caverns          (Category, Limit)
    case craters          (Category, Limit)
    case desert           (Category, Limit)
    case floatingIslands  (Category, Limit)
    case grandCanyon      (Category, Limit)
    case hugeArches       (Category, Limit)
    case lilyPad          (Category, Limit)
    case mountainRavines  (Category, Limit)
    case waterWorld       (Category, Limit)
    
    var fileName: String { description }
    
    var description: String {
        switch self {
        case .alien            (let category, let limit): "Alien\(category.rawValue)_\(limit.rawValue)"
        case .alpine           (let category, let limit): "Alpine\(category.rawValue)_\(limit.rawValue)"
        case .caverns          (let category, let limit): "Caverns\(category.rawValue)_\(limit.rawValue)"
        case .craters          (let category, let limit): "Craters\(category.rawValue)_\(limit.rawValue)"
        case .desert           (let category, let limit): "Desert\(category.rawValue)_\(limit.rawValue)"
        case .floatingIslands  (let category, let limit): "FloatingIslands\(category.rawValue)_\(limit.rawValue)"
        case .grandCanyon      (let category, let limit): "GrandCanyon\(category.rawValue)_\(limit.rawValue)"
        case .hugeArches       (let category, let limit): "HugeArches\(category.rawValue)_\(limit.rawValue)"
        case .lilyPad          (let category, let limit): "LilyPad\(category.rawValue)_\(limit.rawValue)"
        case .mountainRavines  (let category, let limit): "MountainRavines\(category.rawValue)_\(limit.rawValue)"
        case .waterWorld       (let category, let limit): "WaterWorld\(category.rawValue)_\(limit.rawValue)"
        }
    }
}

extension Terrain {
    enum CodingError: Error { case invalid(String) }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = Terrain(string: raw) else {
            throw CodingError.invalid(raw)
        }
        self = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    init?(string: String) {
        // Strip limit suffix
        let limit: Limit
        let body: Substring
        if string.hasSuffix(Limit.max.rawValue) {
            limit = .max
            body = string.dropLast(Limit.max.rawValue.count)
        } else if string.hasSuffix(Limit.min.rawValue) {
            limit = .min
            body = string.dropLast(Limit.min.rawValue.count)
        } else {
            return nil
        }

        // Strip category suffix
        let category: Category
        let name: Substring
        if body.hasSuffix(Category.prime.rawValue) {
            category = .prime
            name = body.dropLast(Category.prime.rawValue.count)
        } else if body.hasSuffix(Category.purple.rawValue) {
            category = .purple
            name = body.dropLast(Category.purple.rawValue.count)
        } else {
            category = .standard
            name = body
        }

        switch name {
        case "Alien":           self = .alien(category, limit)
        case "Alpine":          self = .alpine(category, limit)
        case "Caverns":         self = .caverns(category, limit)
        case "Craters":         self = .craters(category, limit)
        case "Desert":          self = .desert(category, limit)
        case "FloatingIslands": self = .floatingIslands(category, limit)
        case "GrandCanyon":     self = .grandCanyon(category, limit)
        case "HugeArches":      self = .hugeArches(category, limit)
        case "LilyPad":         self = .lilyPad(category, limit)
        case "MountainRavines": self = .mountainRavines(category, limit)
        case "WaterWorld":      self = .waterWorld(category, limit)
        default:                return nil
        }
    }
}
