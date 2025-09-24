//
//  WCSession.swift
//  Loop
//
//  Created by Nate Racklyeft on 9/20/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import LoopCore
import WatchConnectivity
import LoopKit
import os.log


enum MessageError: Error {
    case activation
    case decoding
    case reachability
    case send(Error)
}

enum WCSessionMessageResult<T> {
    case success(T)
    case failure(MessageError)
}

private let log = OSLog(category: "WCSession Extension")

extension WCSession {

    func fetchSettings() async throws -> LoopSettingsUserInfo {
        try await withCheckedThrowingContinuation { continuation in
            sendMessage(SettingsRequestUserInfo().rawValue) { reply in
                guard let settings = LoopSettingsUserInfo(rawValue: reply as LoopSettingsUserInfo.RawValue) else {
                    log.error("fetchSettings: could not decode reply: %{public}@", reply)
                    continuation.resume(throwing: MessageError.decoding)
                    return
                }
                continuation.resume(returning: settings)
            }
        }
    }

    func fetchBolusRecommendation(_ carbEntry: NewCarbEntry?) async throws -> WatchContext {
        let request = GetBolusRecommendationUserInfo(carbEntry: carbEntry)
        let reply = try await sendMessage(request.rawValue)
        log.debug("Requesting bolus recommendation with carbEntry: %{public}@", String(describing: carbEntry))

        guard let context = WatchContext(rawValue: reply as WatchContext.RawValue) else {
            log.error("fetchBolusRecommendation: could not decode reply: %{public}@", reply)
            throw MessageError.decoding
        }
        log.debug("fetchBolusRecommendation: recommendedBolusDose: %{public}@", String(describing: context.recommendedBolusDose))

        return context
    }

    func sendBolusMessage(_ userInfo: SetBolusUserInfo) async throws -> WatchContext {
        let reply = try await sendMessage(userInfo.rawValue)
        guard let context = WatchContext(rawValue: reply as WatchContext.RawValue) else {
            log.error("sendBolusMessage: could not decode reply: %{public}@", reply)
            throw MessageError.decoding
        }
        return context
    }

    func sendSetPreset(presetIdentifier: String?, alertIdentifier: String?) async throws {
        let _ = try await sendMessage(SetPresetUserInfo(presetIdentifier: presetIdentifier, alertIdentifier: alertIdentifier).rawValue)
    }

    func sendAcknowledgeAlert(alertIdentifier: String, managerIdentifier: String) async throws {
        let _ = try await sendMessage(AcknowledgeAlertUserInfo(alertIdentifier: alertIdentifier, managerIdentifier: managerIdentifier).rawValue)
    }

    func sendMessage(_ msg: [String : Any]) async throws -> [String : Any] {
        guard activationState == .activated else {
            throw MessageError.activation
        }
        
        guard isReachable else {
            throw MessageError.reachability
        }

        return try await withCheckedThrowingContinuation { continuation in
            sendMessage(msg, replyHandler: { result in
                continuation.resume(returning: result)
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    func sendUserSelectedNotificationActionMessage(alertIdentifier: String, managerIdentifier: String, actionIdentifier: String) async {
        let msg = NotificationActionSelection(
            alertIdentifier: alertIdentifier,
            managerIdentifier: managerIdentifier,
            actionIdentifier: actionIdentifier
        )
        
        sendMessage(msg.rawValue, replyHandler: { (reply) in
            log.error("Sent notication action selection: ${public}@", actionIdentifier)
        }, errorHandler: { (error) in
            log.error("sendUserSelectedNotificationActionMessage failed: ${public}@", String(describing: error))
        })
    }

    func sendCarbBackfillRequestMessage(_ userInfo: CarbBackfillRequestUserInfo, completionHandler: @escaping (WCSessionMessageResult<WatchHistoricalCarbs>) -> Void) {
        log.default("sendCarbBackfillRequestMessage: since %{public}@", String(describing: userInfo.startDate))

        // Backfill is optional so we ignore any errors
        guard activationState == .activated else {
            log.error("sendCarbBackfillRequestMessage failed: not activated")
            completionHandler(.failure(.activation))
            return
        }

        guard isReachable else {
            log.error("sendCarbBackfillRequestMessage failed: not reachable")
            completionHandler(.failure(.reachability))
            return
        }

        sendMessage(userInfo.rawValue,
                    replyHandler: { reply in
                        if let context = WatchHistoricalCarbs(rawValue: reply as WatchHistoricalCarbs.RawValue) {
                            log.default("sendCarbBackfillRequestMessage succeeded with %d samples", context.objects.count)
                            completionHandler(.success(context))
                        } else {
                            log.error("sendCarbBackfillRequestMessage failed: could not decode reply %{public}@", reply)
                            completionHandler(.failure(.decoding))
                        }
        },
                    errorHandler: { error in
                        log.error("sendCarbBackfillRequestMessage error: %{public}@", String(describing: error))
                        completionHandler(.failure(.send(error)))
        }
        )
    }

    func sendGlucoseBackfillRequestMessage(_ userInfo: GlucoseBackfillRequestUserInfo, completionHandler: @escaping (WCSessionMessageResult<WatchHistoricalGlucose>) -> Void) {
        log.default("sendGlucoseBackfillRequestMessage: since %{public}@", String(describing: userInfo.startDate))

        // Backfill is optional so we ignore any errors
        guard activationState == .activated else {
            log.error("sendGlucoseBackfillRequestMessage failed: not activated")
            completionHandler(.failure(.activation))
            return
        }

        guard isReachable else {
            log.error("sendGlucoseBackfillRequestMessage failed: not reachable")
            completionHandler(.failure(.reachability))
            return
        }

        sendMessage(userInfo.rawValue,
            replyHandler: { reply in
                if let context = WatchHistoricalGlucose(rawValue: reply as WatchHistoricalGlucose.RawValue) {
                    log.default("sendGlucoseBackfillRequestMessage succeeded with %d samples", context.samples.count)
                    completionHandler(.success(context))
                } else {
                    log.error("sendGlucoseBackfillRequestMessage failed: could not decode reply %{public}@", reply)
                    completionHandler(.failure(.decoding))
                }
            },
            errorHandler: { error in
                log.error("sendGlucoseBackfillRequestMessage error: %{public}@", String(describing: error))
                completionHandler(.failure(.send(error)))
            }
        )
    }
    
    func sendContextRequestMessage(_ userInfo: WatchContextRequestUserInfo, completionHandler: @escaping (Result<WatchContext,Error>) -> Void) throws {
        guard activationState == .activated else {
            throw MessageError.activation
        }

        guard isReachable else {
            throw MessageError.reachability
        }

        sendMessage(userInfo.rawValue, replyHandler: { (reply) in
            if let context = WatchContext(rawValue: reply) {
                completionHandler(.success(context))
            } else {
                completionHandler(.failure(MessageError.decoding))
            }
        }, errorHandler: { (error) in
            completionHandler(.failure(error))
        })
    }
}
