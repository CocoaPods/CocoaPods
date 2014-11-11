import Foundation


public struct Orange {
    public var weight: Float
    
    public init(weight: Float) {
        self.weight = weight
    }
}

public struct Glass : Equatable {
    public var volume: Float

    public init(volume: Float) {
        self.volume = volume
    }

    public static func empty() -> Glass {
        return Glass(volume: 0)
    }

    public func pour(additionalVolume: Float) -> Glass {
        return Glass(volume: self.volume + additionalVolume)
    }
}

public class Juicer {
    public required init() {}
    
    public func pressOut(fruits: [Orange]) -> Glass {
        return reduce(fruits, Glass.empty()) { (glass, fruit) in
            glass.pour(self.juiceOf(fruit))
        }
    }

    public func juiceOf(fruit: Orange) -> Float {
        return fruit.weight * 0.5;
    }
}

public func ==(lhs: Glass, rhs: Glass) -> Bool {
    return lhs.volume == rhs.volume
}
