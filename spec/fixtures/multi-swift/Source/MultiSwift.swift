import Foundation


public protocol Animal {
    static var favoriteFood: String { get }
}

public struct Cat: Animal {
    public static var favoriteFood: String {
        return "Kibbles"
    }
}
