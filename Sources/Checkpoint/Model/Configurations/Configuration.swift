//
//  Configuration.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

public protocol Configuration: Sendable {
	var appliedField: Field { get }
	var scope: Scope { get }
}
