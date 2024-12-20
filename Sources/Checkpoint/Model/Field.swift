//
//  Field.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//


//
//  Field.swift
//  
//
//  Created by Adolfo Vera Blasco on 17/6/24.
//

import Foundation

public enum Field: Sendable {
	case header(key: String)
	case queryItem(key: String)
	case noField
}