//
//  Options.swift
//  Nightscout-CLI
//
//  Created by Michael Pangburn on 3/17/18.
//

import Foundation


enum EnvironmentKey {
    static let nightscoutSite = "NS_SITE"
}

enum OptionFlag: String {
    case entries = "entries"
    case treatments = "treatments"
    case deviceStatuses = "devices"
    case help = "help"

    fileprivate init?(matching string: String) {
        for flag in OptionFlag.all {
            if (string == flag.shortFormFlag || string == flag.longFormFlag) {
                self = flag
                return
            }
        }
        return nil
    }

    static var all: [OptionFlag] {
        return [.entries, .treatments, .deviceStatuses, .help]
    }

    var shortFormFlag: String? {
        let shortForm: String
        switch self {
        case .entries:
            shortForm = "e"
        case .treatments:
            shortForm = "t"
        case .deviceStatuses:
            shortForm = "d"
        case .help:
            return nil
        }
        return "-\(shortForm)"
    }

    var longFormFlag: String {
        return "--\(rawValue)"
    }

    var effectDescription: String {
        switch self {
        case .entries:
            return "Display blood glucose entries [default: \(Options.defaultWithFlag.entryCount)]"
        case .treatments:
            return "Display treatments [default: \(Options.defaultWithFlag.treatmentCount)]"
        case .deviceStatuses:
            return "Display device statuses"
        case .help:
            return "Display available options"
        }
    }
}

enum OptionParsingError: Error, CustomStringConvertible {
    case noURLSpecified
    case unexpectedArgument(String)
    case invalidCountArgument(Int)

    var description: String {
        switch self {
        case .noURLSpecified:
            return "no URL specified; pass a URL as the first argument or set the \(EnvironmentKey.nightscoutSite) environment variable"
        case .unexpectedArgument(let argument):
            return "unexpected argument \(argument); use --help to list available arguments"
        case .invalidCountArgument(let count):
            return "invalid count argument \(count); count must be a positive integer"
        }
    }
}

struct Options {
    let siteURL: URL
    let entryCount: Int?
    let treatmentCount: Int?
    let displayDeviceStatuses: Bool
    let displayHelp: Bool

    /// The options to use when no argument other than the URL is specified.
    /// i.e. `ns <url>` or simply `ns` is run.
    static let `default` = (entryCount: 10, treatmentCount: nil as Int?, displayDeviceStatuses: false)

    /// The default value for a flag specified without a count argument.
    /// For example, `ns --treatments` uses the treatment count specified here.
    static let defaultWithFlag = (entryCount: Options.default.entryCount, treatmentCount: 10)

    init(arguments: [String] = CommandLine.argumentsExcludingExecutableName) throws {
        var arguments = arguments
        guard let siteURL: URL = {
            if let firstArgument = arguments.first,
                !firstArgument.hasPrefix("-"), // ensure the first argument is not an option
                let siteURL = URL(string: firstArgument) {
                    arguments = Array(arguments.dropFirst()) // drop the URL when processing the remaining arguments
                    return siteURL
            } else {
                // check the environment for the Nightscout site key
                guard let siteURL = ProcessInfo.processInfo.environment[EnvironmentKey.nightscoutSite].flatMap(URL.init(string:)) else {
                    return nil
                }
                return siteURL
            }
        }() else {
            throw OptionParsingError.noURLSpecified
        }

        guard !arguments.isEmpty else {
            // `ns <url>` or simply `ns` was run
            self.init(
                siteURL: siteURL,
                entryCount: Options.default.entryCount,
                treatmentCount: Options.default.treatmentCount,
                displayDeviceStatuses: Options.default.displayDeviceStatuses,
                displayHelp: false
            )
            return
        }

        var entryCount: Int? = nil
        var treatmentCount: Int? = nil
        var displayDeviceStatuses = false
        var displayHelp = false

        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            if let flag = OptionFlag(matching: argument) {
                switch flag {
                case .entries, .treatments:
                    // check for the optional count of entries or treatments
                    let count = (index < arguments.endIndex - 1) ? Int(arguments[index + 1]) : nil
                    if let count = count, count <= 0 {
                        throw OptionParsingError.invalidCountArgument(count)
                    }
                    switch flag {
                    case .entries:
                        entryCount = count ?? Options.defaultWithFlag.entryCount
                    case .treatments:
                        treatmentCount = count ?? Options.defaultWithFlag.treatmentCount
                    case .deviceStatuses, .help:
                        fatalError("Unreachable case: \(#file), line \(#line)")
                    }

                    if count != nil {
                        index += 1 // ensure the count isn't processed as a flag argument
                    }
                case .deviceStatuses:
                    displayDeviceStatuses = true
                case .help:
                    displayHelp = true
                }
            } else if argument.hasPrefix("-") {
                // check for combined flags, e.g. -etd
                let individualFlags = argument.dropFirst().map { "-\($0)" }
                guard individualFlags.all(satisfy: { OptionFlag(matching: $0) != nil }) else {
                    throw OptionParsingError.unexpectedArgument(argument)
                }
                arguments.append(contentsOf: individualFlags) // let the flags be processed individually later in the loop
            } else {
                throw OptionParsingError.unexpectedArgument(argument)
            }

            index += 1
        }

        self.init(siteURL: siteURL, entryCount: entryCount, treatmentCount: treatmentCount, displayDeviceStatuses: displayDeviceStatuses, displayHelp: displayHelp)
    }

    private init(siteURL: URL, entryCount: Int?, treatmentCount: Int?, displayDeviceStatuses: Bool, displayHelp: Bool) {
        self.siteURL = siteURL
        self.entryCount = entryCount
        self.treatmentCount = treatmentCount
        self.displayDeviceStatuses = displayDeviceStatuses
        self.displayHelp = displayHelp
    }
}
