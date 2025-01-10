//
//  Token.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 9/1/25.
//

import Foundation

struct Token: Codable {
    let timestamp = RateLimitTimestamp()
    let key = UUID().uuidString
}

extension Token: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
}

extension Token: Comparable {
    public static func <(lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
