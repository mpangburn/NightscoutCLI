//
//  TextStyle.swift
//  Nightscout-CLI
//
//  Created by Michael Pangburn on 3/18/18.
//

enum TextStyle {
    static func boldAndRed(_ string: String) -> String {
        return "\u{001B}[1;31m\(string)"
    }

    static func `default`(_ string: String) -> String {
        return "\u{001B}[0;0m\(string)"
    }
}

func printError(_ error: Error) {
    printError(message: String(describing: error))
}

func printError(message: String) {
    print(TextStyle.boldAndRed("error: ") + TextStyle.default(message))
}
