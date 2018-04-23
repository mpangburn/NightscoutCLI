//
//  Extensions.swift
//  Nightscout-CLI
//
//  Created by Michael Pangburn on 3/21/18.
//

import Foundation


extension CommandLine {
    static var executableName: String {
        return arguments.first!
    }

    static var argumentsExcludingExecutableName: [String] {
        return Array(arguments.dropFirst())
    }
}

extension String {
    static func spaces(_ count: Int) -> String {
        return String(repeating: " ", count: count)
    }

    func leftAligned(inFieldOfLength length: Int) -> String {
        return paddingRight(toLength: length)
    }

    func rightAligned(inFieldOfLength length: Int) -> String {
        return paddingLeft(toLength: length)
    }

    private func paddingRight(toLength length: Int) -> String {
        return padding(toLength: length, withPad: " ", startingAt: 0)
    }

    private func paddingLeft(toLength length: Int) -> String {
        let count = self.count
        if count < length {
            return .spaces(length - count) + self
        } else {
            return String(dropLast(count - length))
        }
    }
}

extension Optional where Wrapped == String {
    func leftAlignedOrSpaces(inFieldOfLength length: Int) -> String {
        return self?.leftAligned(inFieldOfLength: length) ?? .spaces(length)
    }

    func rightAlignedOrSpaces(inFieldOfLength length: Int) -> String {
        return self?.rightAligned(inFieldOfLength: length) ?? .spaces(length)
    }
}

extension TimeInterval {
    static func minutes(_ minutes: Double) -> TimeInterval {
        return minutes * 60
    }

    var minutes: Double {
        return self / 60
    }
}

extension Sequence {
    func compact<T>() -> [T] where Element == T? {
        return compactMap { $0 }
    }
}

extension Collection {
    func all(satisfy predicate: (Element) -> Bool) -> Bool {
        return !contains(where: { !predicate($0) })
    }

    func maxElementCount<C: Collection>(by collectionProvider: (Element) -> C?) -> Int? {
        return lazy.compactMap(collectionProvider).map({ $0.count }).max()
    }

    func maxElementCount<C: Collection>(by collectionKeyPath: KeyPath<Element, C>) -> Int? {
        return maxElementCount(by: { $0[keyPath: collectionKeyPath] })
    }

    func maxElementCount<C: Collection>(by collectionKeyPath: KeyPath<Element, C?>) -> Int? {
        return maxElementCount(by: { $0[keyPath: collectionKeyPath] })
    }
}

extension Collection where Element: Collection {
    func maxElementCount() -> Int? {
        return maxElementCount(by: { $0 })
    }
}
