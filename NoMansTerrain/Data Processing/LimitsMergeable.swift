public protocol LimitsMergeable {
    func merged(with other: Self, direction: MergeDirection) -> Self
}

public enum MergeDirection {
    case minimum
    case maximum
}

extension LimitsMergeable {
    func merge<T: Comparable>(_ lhs: T, _ rhs: T, direction: MergeDirection) -> T {
        direction == .minimum ? Swift.min(lhs, rhs) : Swift.max(lhs, rhs)
    }
    func mergeBool(_ lhs: Bool, _ rhs: Bool, direction: MergeDirection) -> Bool {
        direction == .minimum ? (lhs && rhs) : (lhs || rhs)
    }
    func mergeString(_ lhs: String, _ rhs: String, direction: MergeDirection) -> String {
        direction == .minimum ? (lhs <= rhs ? lhs : rhs) : (lhs >= rhs ? lhs : rhs)
    }
    func mergeOptionalInt(_ lhs: Int?, _ rhs: Int?, direction: MergeDirection) -> Int? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        case (let value?, nil): return value
        case (nil, let value?): return value
        case (let left?, let right?): return merge(left, right, direction: direction)
        }
    }
    func mergeEnum<T: RawRepresentable>(_ lhs: T, _ rhs: T, direction: MergeDirection) -> T
    where T.RawValue: Comparable {
        let left = lhs.rawValue
        let right = rhs.rawValue
        let chosen = direction == .minimum ? Swift.min(left, right) : Swift.max(left, right)
        return T(rawValue: chosen) ?? lhs
    }
}

// the vado grande
