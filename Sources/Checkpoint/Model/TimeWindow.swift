//
//  TimeWindow.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Foundation

public enum TimeWindow: Sendable {
	case seconds(count: Int = 10)
	case minutes(count: Int = 1)
	case hours(count: Int = 1)
	
	var inSeconds: TimeInterval {
		switch self {
			case .seconds(let count):
				return Double(count)
			case .minutes(let count):
				return Double(count * 60)
			case .hours(let count):
				return Double(count * 60 * 60)
		}
	}
}
