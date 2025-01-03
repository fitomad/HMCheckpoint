//
//  HTTPErrorDescription.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 3/1/25.
//


enum HTTPErrorDescription {
		static let unauthorized = "X-Api-Key header not available in the request"
		static let rateLimitReached = "You have exceed your ApiKey network requests rate"
	}