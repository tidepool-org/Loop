//
//  Metadata.swift
//  Loop
//
//  Created by Cameron Ingham on 8/11/25.
//

import Foundation

struct Metadata: Equatable, Hashable, Decodable {
    let title: String
    let author: String
    
    init?(url: URL) {
        do {
            let metadata = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
            self.title = metadata.title
            self.author = metadata.author
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}
