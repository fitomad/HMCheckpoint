//
//  WindowBasedAlgorithm.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Foundation

public typealias WindowBasedAction = () throws -> Void

/// For those algorithims thar works with fixed time windows.
public protocol WindowBasedAlgorithm: Algorithm {
	/// Start the timer for a given duration (time window)
	func startWindow(havingDuration seconds: Int, performing action: @escaping WindowBasedAction) -> Timer
	/// Perfomrs the reset operation when the time windo ends.
	func resetWindow() async throws
}

extension WindowBasedAlgorithm {
	public func startWindow(havingDuration seconds: Int, performing action: @escaping WindowBasedAction) -> Timer {
		let timerSeconds = Double(seconds)
		
		let timer = Timer.scheduledTimer(withTimeInterval: timerSeconds, repeats: true) { _ in
			do {
				try action()
			} catch let timerError {
				self.logging?.error("🚨 Something wrong at timer: \(timerError.localizedDescription)")
			}
		}
		
		return timer
	}
}
