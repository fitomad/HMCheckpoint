//
//  ErrorMetadata.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 3/1/25.
//

import Foundation
import HTTPTypes

public final class ErrorMetadata {
	public var headers: [String : String]?
	public var reason: String?
	
	var httpHeaders: HTTPFields {
		var httpHeaders = HTTPFields()
		
		guard let headers else {
			return httpHeaders
		}
		
		for (key, content) in headers {
			if let headerName = HTTPField.Name(key) {
				let newHeader = HTTPField(name: headerName, value: content)
				httpHeaders.append(newHeader)
			}
		}
		
		return httpHeaders
	}
}
