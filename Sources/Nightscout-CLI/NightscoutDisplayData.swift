//
//  NightscoutDisplayData.swift
//  Nightscout-CLI
//
//  Created by Michael Pangburn on 3/21/18.
//

import Foundation
import NightscoutKit


struct NightscoutDisplayData {
    let entries: [NightscoutEntry]?
    let treatments: [NightscoutTreatment]?
    let deviceStatuses: [NightscoutDeviceStatus]?
}

extension Nightscout {
    func fetchDisplayData(withOptions options: Options, completion: (NightscoutResult<NightscoutDisplayData>) -> Void) {
        var entries: [NightscoutEntry]?
        var treatments: [NightscoutTreatment]?
        var deviceStatuses: [NightscoutDeviceStatus]?
        var error: NightscoutError?

        let fetchGroup = DispatchGroup()

        if let entryCount = options.entryCount {
            fetchGroup.enter()
            // fetch one more than the requested count so we can provide information
            // on the blood glucose delta for each entry
            fetchMostRecentEntries(count: entryCount + 1) { result in
                switch result {
                case .success(let nsEntries):
                    entries = nsEntries
                case .failure(let nsError):
                    error = nsError
                }
                fetchGroup.leave()
            }
        }

        if let treatmentCount = options.treatmentCount {
            fetchGroup.enter()
            fetchMostRecentTreatments(count: treatmentCount) { result in
                switch result {
                case .success(let nsTreatments):
                    treatments = nsTreatments
                case .failure(let nsError):
                    error = nsError
                }
                fetchGroup.leave()
            }
        }

        if options.displayDeviceStatuses {
            fetchGroup.enter()
            fetchMostRecentDeviceStatuses() { result in
                switch result {
                case .success(let nsDeviceStatuses):
                    deviceStatuses = nsDeviceStatuses
                case .failure(let nsError):
                    error = nsError
                }
                fetchGroup.leave()
            }
        }

        fetchGroup.wait()

        guard error == nil else {
            completion(.failure(error!))
            return
        }

        let displayData = NightscoutDisplayData(entries: entries, treatments: treatments, deviceStatuses: deviceStatuses)
        completion(.success(displayData))
    }
}

// MARK: - Pretty printing

func prettyPrintNightscoutDisplayData(_ displayData: NightscoutDisplayData) {
    displayData.entries.map(prettyPrintEntries)
    displayData.treatments.map {
        if displayData.entries != nil { print() }
        prettyPrintTreatments($0)
    }
    displayData.deviceStatuses.map {
        if displayData.entries != nil || displayData.treatments != nil { print() }
        prettyPrintDeviceStatuses($0)
    }
}

func prettyPrintNightscoutError(_ error: NightscoutError) {
    let message: String = {
        switch error {
        case .invalidURL:
            return "invalid Nightscout URL"
        case .missingAPISecret:
            return "missing API secret"
        case .fetchError(let error):
            return "fetch error: \(error)"
        case .uploadError(let error):
            return "upload error: \(error)"
        case .notAnHTTPURLResponse:
            return "not an HTTP URL response"
        case .missingData:
            return "missing data in URL response"
        case .unauthorized:
            return "unauthorized"
        case .httpError(statusCode: let statusCode, body: let body):
            return "unexpected HTTP response: \(statusCode) \(body)"
        case .jsonParsingError(let error):
            return "JSON parsing error: \(error)"
        case .dataParsingFailure(_):
            return "data parsing failure; see https://github.com/mpangburn/NightscoutKit/issues to submit a bug report"
        }
    }()

    printError(message: message)
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM dd HH:mm"
    return formatter
}()

private func prettyPrintEntries(_ entries: [NightscoutEntry]) {
    guard entries.count > 1 else {
        // because we request count + 1 entries, we should always have at least 2 entries here
        return
    }

    let deltaRecordingEntries = entries.recordingDeltas()
    let maxDateLength = deltaRecordingEntries.maxElementCount(by: { dateFormatter.string(from: $0.date) })!
    let maxGlucoseValueLength = deltaRecordingEntries.maxElementCount(by: \.glucoseValue.valueString)!
    let maxDeltaLength = deltaRecordingEntries.maxElementCount(by: \.glucoseDeltaDisplayString)! + "()".count
    let maxTrendLength = deltaRecordingEntries.maxElementCount(by: { entry -> String? in
        guard case .sensor(trend: let trend) = entry.source else { return nil }
        return trend.symbol
    }) ?? 0
    let maxDeviceLength = deltaRecordingEntries.maxElementCount(by: \.device) ?? 0

    let interValueSpacing = 2
    let separator = String(repeating: " ", count: interValueSpacing)

    for entry in deltaRecordingEntries {
        let dateString = dateFormatter.string(from: entry.date).leftAligned(inFieldOfLength: maxDateLength)
        let glucoseString = entry.glucoseValue.valueString.rightAligned(inFieldOfLength: maxGlucoseValueLength)
        let deltaString: String = {
            guard entry.timeIntervalSincePreviousEntry < .minutes(11) else {
                // if more than one entry was missed between entries, don't print the delta
                return .spaces(maxDeltaLength)
            }
            return "(\(entry.glucoseDeltaDisplayString))".rightAligned(inFieldOfLength: maxDeltaLength)
        }()
        let sourceString: String = {
            guard case .sensor(trend: let trend) = entry.source else {
                return .spaces(maxTrendLength) // blank out the trend symbol spot
            }
            return trend.symbol
        }()
        let bgString = "\(glucoseString) \(deltaString) \(sourceString)"
        let deviceString = entry.device.leftAlignedOrSpaces(inFieldOfLength: maxDeviceLength)
        let stringPieces = [dateString, bgString, deviceString]
        print(stringPieces.joined(separator: separator))
    }
}

private func prettyPrintTreatments(_ treatments: [NightscoutTreatment]) {
    guard !treatments.isEmpty else {
        return
    }

    let durationLabel = "min"
    let insulinGivenLabel = "U"
    let carbsConsumedLabel = "g"

    let maxDateLength = treatments.maxElementCount(by: { dateFormatter.string(from: $0.date) })!
    let maxSimpleDescriptionLength = treatments.maxElementCount(by: \.eventType.simpleDescription)!
    let maxDetailDescriptionLength = treatments.maxElementCount(by: \.eventType.detailDescription) ?? 0
    let maxDurationLength: Int = {
        let nonzeroMinuteDurations = treatments.lazy.flatMap { treament -> Int? in
            let minutes = Int(treament.duration.minutes)
            guard minutes > 0 else { return nil }
            return minutes
        }
        let maxLength = nonzeroMinuteDurations.maxElementCount(by: String.init)
        return maxLength.map { $0 + durationLabel.count } ?? 0
    }()
    let maxGlucoseValueLength = treatments.lazy.flatMap({ $0.glucose?.glucoseValue.value }).maxElementCount(by: String.init) ?? 0
    let maxInsulinGivenLength: Int = {
        let maxLength = treatments.lazy.flatMap({ $0.insulinGiven }).maxElementCount(by: String.init)
        return maxLength.map { $0 + insulinGivenLabel.count } ?? 0
    }()
    let maxCarbsConsumedLength: Int = {
        let maxLength = treatments.lazy.flatMap({ $0.carbsConsumed }).maxElementCount(by: String.init)
        return maxLength.map { $0 + carbsConsumedLabel.count } ?? 0
    }()
    let maxRecorderLength = treatments.maxElementCount(by: \.recorder) ?? 0
    // let maxNotesLength = treatments.maxElementCount(by: \.notes) ?? 0

    let interValueSpacing = 2
    let separator = String(repeating: " ", count: interValueSpacing)

    for treatment in treatments {
        let dateString = dateFormatter.string(from: treatment.date).leftAligned(inFieldOfLength: maxDateLength)
        let simpleDescription = treatment.eventType.simpleDescription.leftAligned(inFieldOfLength: maxSimpleDescriptionLength)
        let detailDescription = treatment.eventType.detailDescription.leftAlignedOrSpaces(inFieldOfLength: maxDetailDescriptionLength)
        let durationString: String = {
            let effectiveDuration = treatment.duration > 0 ? Int(treatment.duration.minutes) : nil
            return effectiveDuration.map({ "\($0)\(durationLabel)" }).rightAlignedOrSpaces(inFieldOfLength: maxDurationLength)
        }()
        let glucoseValueString = treatment.glucose.map({ String($0.glucoseValue.value) }).rightAlignedOrSpaces(inFieldOfLength: maxGlucoseValueLength)
        let insulinGivenString = treatment.insulinGiven.map({ "\($0)\(insulinGivenLabel)" }).rightAlignedOrSpaces(inFieldOfLength: maxInsulinGivenLength)
        let carbsConsumedString = treatment.carbsConsumed.map({ "\($0)\(carbsConsumedLabel)" }).rightAlignedOrSpaces(inFieldOfLength: maxCarbsConsumedLength)
        let recorderString = treatment.recorder.leftAlignedOrSpaces(inFieldOfLength: maxRecorderLength)
        // let notesString = treatment.notes.leftAlignedOrSpaces(inFieldOfLength: maxNotesLength)
        let stringPieces = [
            dateString, simpleDescription, detailDescription, durationString, glucoseValueString,
            insulinGivenString, carbsConsumedString, recorderString //, notesString
        ].filter { !$0.isEmpty }
        print(stringPieces.joined(separator: separator))
    }
}

private func prettyPrintDeviceStatuses(_ deviceStatuses: [NightscoutDeviceStatus]) {
    guard !deviceStatuses.isEmpty else {
        return
    }

    let interValueSpacing = 2
    let separator = String(repeating: " ", count: interValueSpacing)

    let closedLoopDeviceStatus = deviceStatuses.first(where: { $0.closedLoopSystem?.loopStatus != nil })
    let pumpStatusDeviceStatus = deviceStatuses.first(where: { $0.closedLoopSystem?.pumpStatus != nil })
    let uploaderDeviceStatus = deviceStatuses.first(where: { $0.closedLoopSystem?.uploaderStatus != nil })

    let closedLoopDeviceString: String? = closedLoopDeviceStatus?.closedLoopSystem.map { system in
        switch system {
        case .loop(status: _):
            return "Loop"
        case .openAPS(status: _):
            return "OpenAPS"
        }
    }
    let pumpDeviceString = pumpStatusDeviceStatus.map { _ in "Pump" }
    let uploaderDeviceString = uploaderDeviceStatus.map { _ in "Uploader" }
    let deviceStrings = [closedLoopDeviceString, pumpDeviceString, uploaderDeviceString].flatMap { $0 }
    let maxDeviceStringLength = deviceStrings.maxElementCount() ?? 0

    if let closedLoopDeviceStatus = closedLoopDeviceStatus {
        let closedLoopStatus = closedLoopDeviceStatus.closedLoopSystem!.loopStatus!
        let dateString = dateFormatter.string(from: closedLoopStatus.timestamp)
        let deviceString = closedLoopDeviceString!.leftAligned(inFieldOfLength: maxDeviceStringLength)
        let insulinOnBoardString = closedLoopStatus.insulinOnBoardStatus?.insulinOnBoard.map { String(format: "%.2fU IOB", $0) }
        let carbsOnBoardString = closedLoopStatus.carbsOnBoard.map { "\($0)g COB" }
        let enactedTemporaryBasalString = closedLoopStatus.enactedTemporaryBasal.flatMap { temp -> String? in
            let timeSinceTempStart = Date().timeIntervalSince(temp.startDate)
            let tempTimeRemaining = temp.duration - timeSinceTempStart
            guard tempTimeRemaining > 0 else {
                return nil
            }
            return "enacted: \(temp.rate)U/hr, \(Int(tempTimeRemaining.minutes))min remaining"
        }

        let stringPieces = [dateString, deviceString, insulinOnBoardString, carbsOnBoardString, enactedTemporaryBasalString].flatMap { $0 }
        print(stringPieces.joined(separator: separator))
    }

    if let pumpStatusDeviceStatus = pumpStatusDeviceStatus {
        let pumpStatus = pumpStatusDeviceStatus.closedLoopSystem!.pumpStatus!
        let dateString = dateFormatter.string(from: pumpStatusDeviceStatus.date)
        let deviceString = pumpDeviceString!.leftAligned(inFieldOfLength: maxDeviceStringLength)
        let reservoirInsulinRemainingString = pumpStatus.reservoirInsulinRemaining.map { String(format: "%.1fU remaining", $0) }
        let batteryStatusString = pumpStatus.batteryStatus?.status.flatMap { $0 == .low ? "low" : nil }
        let isSuspendedString = pumpStatus.isSuspended.flatMap { $0 ? "suspended" : nil }
        let stringPieces = [dateString, deviceString, reservoirInsulinRemainingString, batteryStatusString, isSuspendedString].flatMap { $0 }
        print(stringPieces.joined(separator: separator))
    }

    // if we don't get the battery percentage, there's no reason to display the uploader status
    if let uploaderDeviceStatus = uploaderDeviceStatus,
        let batteryPercentage = uploaderDeviceStatus.closedLoopSystem!.uploaderStatus!.batteryPercentage {
        let dateString = dateFormatter.string(from: uploaderDeviceStatus.date)
        let deviceString = uploaderDeviceString!.leftAligned(inFieldOfLength: maxDeviceStringLength)
        let batteryPercentageString = "\(batteryPercentage)% remaining"
        let stringPieces = [dateString, deviceString, batteryPercentageString]
        print(stringPieces.joined(separator: separator))
    }
}

fileprivate extension NightscoutTreatment.EventType {
    var simpleDescription: String {
        switch self {
        case .bloodGlucoseCheck:
            return "BG Check"
        case .bolus(type: let type):
            return type.simpleDescription
        case .temporaryBasal(type: let type):
            return type.simpleDescription
        case .carbCorrection:
            return "Carb Correction"
        case .announcement:
            return "Announcement"
        case .note:
            return "Note"
        case .question:
            return "Question"
        case .exercise:
            return "Exercise"
        case .suspendPump:
            return "Suspend Pump"
        case .resumePump:
            return "Resume Pump"
        case .pumpSiteChange:
            return "Site Change"
        case .insulinChange:
            return "Insulin Change"
        case .sensorStart:
            return "Sensor Start"
        case .sensorChange:
            return "Sensor Change"
        case .profileSwitch(profileName: _):
            return "Profile Switch"
        case .diabeticAlertDogAlert:
            return "D.A.D. Alert"
        case .none:
            return "<none>"
        case .unknown(let description):
            return description
        }
    }

    var detailDescription: String? {
        switch self {
        case .bolus(type: .combo(totalInsulin: let totalInsulin, percentageUpFront: let percentageUpFront)):
            return String(format: "%.2fU", totalInsulin) + " \(percentageUpFront)%/\(100 - percentageUpFront)%"
        case .temporaryBasal(type: let type):
            switch type {
            case .percentage(let percentage):
                return "\(percentage)%"
            case .absolute(rate: let rate):
                return String(format: "%.3fU/hr", rate)
            case .ended:
                break
            }
        case .profileSwitch(profileName: let profileName):
            return profileName
        default:
            break
        }
        return nil
    }
}

fileprivate extension NightscoutTreatment.BolusType {
    var simpleDescription: String {
        let description: String = {
            switch self {
            case .snack:
                return "Snack"
            case .meal:
                return "Meal"
            case .correction:
                return "Correction"
            case .combo(totalInsulin: _, percentageUpFront: _):
                return "Combo"
            }
        }()
        return "\(description) Bolus"
    }
}

fileprivate extension NightscoutTreatment.TemporaryBasalType {
    var simpleDescription: String {
        switch self {
        case .percentage(_), .absolute(rate: _):
            return "Temp Basal"
        case .ended:
            return "Temp Basal Ended"
        }
    }
}
