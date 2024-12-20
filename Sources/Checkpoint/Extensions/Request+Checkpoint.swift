//
//  Request+Checkpoint.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 12/12/24.
//

import Hummingbird

extension HTTPFields {
	public subscript(key: String) -> [HTTPFields.Element] {
		self.filter { $0.name.canonicalName ==  key.lowercased() }
	}
}

