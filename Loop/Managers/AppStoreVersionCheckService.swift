//
//  AppStoreVersionCheckService.swift
//  Loop
//
//  Created by Rick Pasetto on 10/4/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import LoopKit

class AppStoreVersionCheckService: VersionCheckService {
    
    var serviceDelegate: ServiceDelegate?
    
    typealias RawStateValue = [String: Any]
    var rawState: RawStateValue = [:]
    
    var isOnboarded: Bool = true
    
    static var serviceIdentifier = "AppStoreVersionCheckService"
    static var localizedTitle = "AppStoreVersionCheckService"
    
    private static var decoder = JSONDecoder()
    
    init() { }
    
    required init?(rawState: RawStateValue) {
        // n/a
    }
    
    func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate?, Error>) -> Void) {
        DispatchQueue.global().async {
            _ = self.getAppInfo { result in
                switch result {
                case .success(let info):
                    if info.version <= currentVersion {
                        completion(.success(.noneNeeded))
                    } else {
                        completion(.success(.updateNeeded))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    fileprivate enum VersionError: Error {
        case invalidBundleInfo, invalidResponse, noResults
    }
    
    private struct LookupResult: Decodable {
        let results: [AppInfo]
    }
    
    private struct AppInfo: Decodable {
        let version: String
        let trackViewUrl: String
    }
    
    private func getAppInfo(completion: @escaping (Result<AppInfo, Error>) -> Void) -> URLSessionDataTask? {
        
        guard let identifier = Bundle.main.bundleIdentifier,
              let url = URL(string: "http://itunes.apple.com/us/lookup?bundleId=\(identifier)") else {
                  completion(.failure(VersionError.invalidBundleInfo))
                  return nil
              }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            do {
                if let error = error {
                    throw error
                }
                guard let data = data else {
                    throw VersionError.invalidResponse
                }
                let result = try Self.decoder.decode(LookupResult.self, from: data)
                guard let info = result.results.first else {
                    throw VersionError.noResults
                }
                completion(.success(info))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
        return task
    }
}
