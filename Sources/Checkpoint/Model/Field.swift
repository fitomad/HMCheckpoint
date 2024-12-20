//
//  Field.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Foundation

public enum Field: Sendable {
	case header(key: String)
	case queryItem(key: String)
	case noField
}
