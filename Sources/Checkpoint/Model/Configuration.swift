//
//  Configuration.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//


//
//  Cinfiguration.swift
//  
//
//  Created by Adolfo Vera Blasco on 19/6/24.
//


public protocol Configuration: Sendable {
	var appliedField: Field { get }
	var scope: Scope { get }
}
