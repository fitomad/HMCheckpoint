//
//  RateLimitTimestamp.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 9/1/25.
//

import Foundation

typealias RateLimitTimestamp = TimeInterval

extension RateLimitTimestamp {
    init() {
        self = Date().timeIntervalSince1970
    }
    
    func isPrevious(to timeWindow: TimeWindow) -> Bool {
        let timeWindowSeconds = Double(timeWindow.inSeconds)
        let mark = Date().addingTimeInterval(-timeWindowSeconds)
        
        return self < mark.timeIntervalSince1970
    }
}
