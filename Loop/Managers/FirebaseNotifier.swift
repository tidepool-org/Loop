//
//  FirebaseNotifier.swift
//  Loop
//
//  Created by Rick Pasetto on 5/31/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import FirebaseCore
import FirebaseDatabase
import LoopCore
import LoopKit
import LoopKitUI

protocol FollowerNotifier: AlertIssuer {
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

    private var ref: DatabaseReference!

    var id: String? {
        UserDefaults.standard.shareID?.uuidString
    }
    
    var name: String? {
        UserDefaults.standard.username ?? id.map { String($0.prefix(6)) }
    }
    
    init() {
        // HACKORAMA
        ref = Database.database().reference()
    }
    
    // HACKORAMA
    // ICK ICK ICK ICK this stores ALL data so it ALL can be published at once.
    private var cache: [AnyHashable : Any] = [:]
    private func sendToFirebase(_ new: [AnyHashable : Any]) {
        guard let id = id else {
            return
        }
        DispatchQueue.main.async { [self] in
            cache.merge(new) { (_, new) in new }
            ref.child("followees").child(id).updateChildValues(cache)
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
                
                // Unfortunately, we only have an image here.  We can't really introspect it, so here we hack away!
                let badge: String? = {
                    switch cgmStatusBadge?.image?.accessibilityIdentifier {
                    case "drop.circle.fill": return "calibration"
                    case "battery.circle.fill": return "battery"
                    case .some(let thing): return thing
                    default: return nil
                    }
                }()
                sendToFirebase([
                    "name": name as Any,
                    "date": dateFormatter.string(from: lastGlucose.date),
                    "glucose": lastGlucose.quantity.doubleValue(for: .milligramsPerDeciliter, withRounding: true),
                    "glucoseCategory": glucoseDisplayFunc(lastGlucose.quantitySample)?.glucoseRangeCategory?.glucoseCategoryColor.rawValue as Any,
                    "trendCategory": glucoseDisplayFunc(lastGlucose.quantitySample)?.glucoseRangeCategory?.trendCategoryColor.rawValue as Any,
                    "trend": glucoseDisplayFunc(lastGlucose.quantitySample)?.trendType?.arrows as Any,
                    "badge": badge as Any
                ])
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
                let reservoirVolume = doseStore.lastReservoirValue?.unitVolume
                let activeCarbs = carbsOnBoard.map { $0.quantity.doubleValue(for: .gram(), withRounding: true) } ?? 0
                self.sendToFirebase([
                    "name": self.name as Any,
                    "isClosedLoop": isClosedLoop as Any,
                    "loopCompletionFreshness": LoopCompletionFreshness(lastCompletion: lastLoopCompleted).description,
                    "netBasalRate": netBasal.map { $0.rate } as Any,
                    "netBasalPercent": netBasal.map { $0.percent } as Any,
                    "activeCarbs": activeCarbs,
                    "reservoir": reservoirVolume as Any,
                    "activeInsulin": activeInsulin
                ])
            }
        }
    }
}

extension FirebaseNotifier: AlertIssuer {
    func issueAlert(_ alert: Alert) {
        if let title = (alert.foregroundContent ?? alert.backgroundContent)?.title, alert.trigger == .immediate {
            sendToFirebase([
                "alert": title
            ])
        }
    }
    
    func retractAlert(identifier: Alert.Identifier) {
        sendToFirebase([
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


//    export interface Followee {
//      name: string
//      glucose: number
//      badge: string | null
//      unit: string
//      date: string
//      trend: string
//      glucoseCategory: string
//      trendCategory: string
//      reservoir: number
//      netBasalRate: number
//      netBasalPercent: number
//      loopCompletionFreshness: string | null
//      isClosedLoop: boolean
//      activeCarbs: number
//      activeInsulin: number
//      alert: string | null | undefined
//      id: string
//    }

struct FolloweeData: Codable {
    let name: String
    let glucose: Double
    let badge: String?
    let unit: String?
    let date: String
    let trend: String
    let glucoseCategory: String
    let trendCategory: String
    let reservoir: Double
    let netBasalRate: Double
    let netBasalPercent: Double
    let loopCompletionFreshness: String?
    let isClosedLoop: Bool
    let activeCarbs: Double
    let activeInsulin: Double
    let alert: String?
    let id: String
}
