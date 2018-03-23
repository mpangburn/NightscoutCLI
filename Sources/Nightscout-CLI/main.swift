import Foundation
import NightscoutKit


func printUsage() {
    let flagFormDescriptions = OptionFlag.all.map { flag in
        "  \(flag.longFormFlag)" + (flag.shortFormFlag.map({ ", \($0)" }) ?? "")
    }
    let spacingBetweenFlagAndEffect = 2
    let flagLength = flagFormDescriptions.maxElementCount()! + spacingBetweenFlagAndEffect
    let optionDescriptions = zip(OptionFlag.all, flagFormDescriptions).map { flag, formsDescription in
        formsDescription.leftAligned(inFieldOfLength: flagLength) + flag.effectDescription
    }.joined(separator: "\n")

    print("""
    OVERVIEW: Display recent Nightscout entries, treatments, and device statuses

    USAGE: \(CommandLine.executableName) [url] [options]
      If no url is specified, the environment variable \(EnvironmentKey.nightscoutSite)
      will be checked for the Nightscout URL.
      If no options are specified, \(Options.default.entryCount) blood glucose entries will be displayed.

    OPTIONS:
    \(optionDescriptions)
    """)
}

// MARK: - Script

let options: Options
do {
    options = try Options()
} catch {
    printError(error)
    exit(EXIT_FAILURE)
}

guard !options.displayHelp else {
    printUsage()
    exit(EXIT_SUCCESS)
}

let nightscout = Nightscout(baseURL: options.siteURL)
let fetchGroup = DispatchGroup()
fetchGroup.enter()
nightscout.fetchDisplayData(withOptions: options) { result in
    switch result {
    case .success(let displayData):
        prettyPrintNightscoutDisplayData(displayData)
    case .failure(let error):
        prettyPrintNightscoutError(error)
        exit(EXIT_FAILURE)
    }
    fetchGroup.leave()
}

fetchGroup.wait()
exit(EXIT_SUCCESS)
