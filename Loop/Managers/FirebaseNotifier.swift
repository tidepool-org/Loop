//
//  FirebaseNotifier.swift
//  Loop
//
//  Created by Rick Pasetto on 5/31/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import FirebaseCore
import FirebaseFirestore
import LoopCore
import LoopKit
import LoopKitUI

protocol FollowerNotifier: AlertIssuer {
    func introduce()
    func tellFollowers(readingResult: CGMReadingResult,
                       cgmStatusBadge: DeviceStatusBadge?,
                       glucoseDisplayFunc: @escaping (GlucoseSampleValue?) -> GlucoseDisplayable?)
    func tellFollowers(doseStore: DoseStoreProtocol,
                       netBasal: NetBasal?,
                       carbsOnBoard: CarbValue?,
                       isClosedLoop: Bool?,
                       lastLoopCompleted: Date?)
}

final class FirebaseNotifier: FollowerNotifier {
    
    static let shared = FirebaseNotifier()

    private let db: Firestore

    // HACKORAMA: TODO: Threading is problematic, so avoid it.
    var id: String {
        set {
            UserDefaults.standard.shareID = UUID(uuidString: newValue)!
        }
        get {
            if let id = UserDefaults.standard.shareID?.uuidString {
                return id
            }
            let newValue = UUID()
            UserDefaults.standard.shareID = newValue
            return newValue.uuidString
        }
    }
    
    var name: String? {
        UserDefaults.standard.username ?? String(id.prefix(6))
    }
    
    init() {
        db = Firestore.firestore()
    }
    
    func introduce() {
        // Right now there's no way to pick a Follower by User ID, so this basically doesn't do anything.
        // Otherwise, we _could_ put the follower's ID in a list for the followee.  So the entire act of "Sharing"
        // is "Authorizing" a follower, who just keeps a list of followees
        updateFollowee([:])
    }
    
    // HACKORAMA
    
    private var followee: DocumentReference {
        db.collection("followees").document(id)
    }
    
    private var glucoseData: CollectionReference {
        followee.collection("glucose")
    }
    
    private func postGlucose(_ glucose: GlucoseData) throws {
        // TODO: Put into a transaction?
        followee.setData(["lastUpdate": lastUpdateTime], merge: true) { error in
            if let error = error {
                print("!!!!!!!!! NOPE: \(error)")
            }
        }
        // OMG this is such a hack
        var dict = try glucose.dict()
        dict["date"] = Timestamp(date: glucose.date)
        glucoseData.addDocument(data: dict)
        // TODO: predictedGlucose
        
        flush(glucose.date)
    }
    
    private var lastUpdateTime: Any {
        FieldValue.serverTimestamp()
//        Date()
    }
    
    private func updateFollowee(_ new: [String: Any]) {
        let newer = new.merging(["lastUpdate": lastUpdateTime]) { $1 }
        followee.setData(newer, merge: true) { error in
            if let error = error {
                print("!!!!!!!!! NOPE: \(error)")
            }
        }
    }
    
    // Only keep data from the last 4 hours??  For the real app this will need better thought
//    private var window = TimeInterval.hours(4)
    private var window = TimeInterval.seconds(20)
    private func flush(_ lastGlucoseDate: Date) {
        let d = Timestamp(date: lastGlucoseDate - window)
        glucoseData
            .whereField("date", isLessThan: d)
            .getDocuments { snapshot, error in
            if let error = error {
                print("########## NOPE: \(error)")
            }
            for document in snapshot!.documents {
                print("******* \(document.documentID) => \(document.data()) d=\(d)")
                self.glucoseData.document(document.documentID).delete()
            }
        }
    }
}

extension FirebaseNotifier {
        
    func tellFollowers(readingResult: CGMReadingResult,
                       cgmStatusBadge: DeviceStatusBadge?,
                       glucoseDisplayFunc: @escaping (GlucoseSampleValue?) -> GlucoseDisplayable?) {
        switch readingResult {
        case .newData(let values):
            if let lastGlucose = values.last {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .short
                let glucoseData = GlucoseData(value: lastGlucose.quantity.doubleValue(for: .milligramsPerDeciliter, withRounding: true),
                                              unit: .mgdL,
                                              date: lastGlucose.date,
                                              trendRate: lastGlucose.trendRate?.doubleValue(for: .milligramsPerDeciliterPerMinute, withRounding: true))
                try? postGlucose(glucoseData)
            }
        case .unreliableData:
            // TODO HACKORAMA
            break
        default:
            break
        }
    }
}

extension FirebaseNotifier {
    
    func tellFollowers(doseStore: DoseStoreProtocol, netBasal: NetBasal?, carbsOnBoard: CarbValue?, isClosedLoop: Bool?, lastLoopCompleted: Date?) {
        doseStore.insulinOnBoard(at: Date()) { (result) in
            if case .success(let iobValue) = result {
                let activeInsulin = iobValue.value
                let activeCarbs = carbsOnBoard.map { $0.quantity.doubleValue(for: .gram(), withRounding: true) } ?? 0
                self.updateFollowee([
                    "name": self.name as Any,
                    "isClosedLoop": isClosedLoop as Any,
                    "lastLoopCompleted": lastLoopCompleted as Any,
                    "netBasalRate": netBasal.map { $0.rate } as Any,
                    "activeCarbs": activeCarbs,
                    "activeInsulin": activeInsulin
                ])
            }
        }
    }
}

extension FirebaseNotifier: AlertIssuer {
    func issueAlert(_ alert: Alert) {
        if let title = (alert.foregroundContent ?? alert.backgroundContent)?.title, alert.trigger == .immediate {
            updateFollowee([
                "alert": title
            ])
        }
    }
    
    func retractAlert(identifier: Alert.Identifier) {
        updateFollowee([
            "alert": ""
        ])
    }
}

extension UserDefaults {

    private enum Key: String {
        case shareID = "com.loopkit.Loop.ShareID"
        case username = "com.loopkit.Loop.ShareUserName"
    }

    var shareID: UUID? {
        get {
            return string(forKey: Key.shareID.rawValue).flatMap { UUID(uuidString: $0) }
        }
        set {
            set(newValue?.uuidString, forKey: Key.shareID.rawValue)
        }
    }

    var username: String? {
        get {
            return string(forKey: Key.username.rawValue)
        }
        set {
            set(newValue, forKey: Key.username.rawValue)
        }
    }

}

struct Followee {
    typealias Id = String
    // Followee Share ID & Name
    // (Can/should these come from some identity database? From Tidepool Service?  Or...?)
    let id: Id
    let name: String
    let data: FolloweeData
}
enum GlucoseUnit: Int, Codable {
    case mgdL = 0, mmolL
}
enum CarbUnit: Int, Codable {
    case g
}

struct FolloweeData: Codable {
    let lastUpdate: Date?
    // This one is tricky: LoopDataManager has basalDeliveryState (which, I *think* comes from
    // PumpManagerStatus via DeviceManager...sigh), which has `getNetBasal()` function on it,
    // which provides these (double sigh)
    let netBasalRate: Double? // U/hr
    // This comes from a policy implemented in a separate functional class, LoopCompletionFreshness,
    // which computes it based on `lastLoopCompleted` (which comes from LoopDataManager)
    let lastLoopCompleted: Date?
    // This is directly from LoopDataManager.automaticDosingStatus.isClosedLoop:
    let isClosedLoop: Bool

    let activeInsulin: Double // DoseStore.insulinOnBoard (at: now)
    let lastBolus: Date?

    let activeCarbs: Double // LoopDataManager.carbsOnBoard.quantity.doubleValue(for: gram(), withRounding: true)
    let lastCarbEntry: Date?

    // From AlertIssuer
    let alert: String?
}

// From GlucoseStore: (?)
struct GlucoseData: Codable {
    let value: Double // StoredGlucoseSample.quantity.doubleValue
    let unit: GlucoseUnit//String? // StoredGlucoseSample.quantity.unit
    let date: Date//String // StoredGlucoseSample.startDate
    let trendRate: Double?//String // StoredGlucoseSample.trend
}

struct Follower: Codable {
    let followees: [Followee.Id]
    let settings: FollowerSettings
}

struct FollowerSettings: Codable {
    let glucoseUnit: GlucoseUnit
    let carbUnit: CarbUnit
    
    struct Notifications {
        struct Threshold {
            let enabled: Bool
            let limit: Double
            let repeatFrequency: TimeInterval
            let sound: String?
        }
        let urgentLow: Threshold
        let low: Threshold
        let high: Threshold
        let fallRate: Threshold
    }
}

extension Encodable {
    func dict() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw JSONEncoderError.stringEncodingError
        }
        return dictionary
    }
}
