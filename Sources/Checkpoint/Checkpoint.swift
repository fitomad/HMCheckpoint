//
//  Checkpoint.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Hummingbird
import HTTPTypes

public typealias CheckpointHandler = (Request) -> Void
public typealias CheckpointRateLimitHandler = (Request, Response, Checkpoint.ErrorMetadata) -> Void
public typealias CheckpointErrorHandler = (Request, Response, HTTPError, Checkpoint.ErrorMetadata) -> Void

public typealias NextMiddlewareHandler = (Request, BasicRequestContext) async throws -> Response

public final class Checkpoint {
	private let algorithm: any Algorithm
	
	public var willCheck: CheckpointHandler?
	public var didCheck: CheckpointHandler?
	public var didFailWithTooManyRequest: CheckpointRateLimitHandler?
	public var didFail: CheckpointErrorHandler?
	
	public init(using algorithm: some Algorithm) {
		self.algorithm = algorithm
	}
}

extension Checkpoint: RouterMiddleware {
	public func handle(_ request: Request, context: BasicRequestContext, next: NextMiddlewareHandler) async throws -> Response {
		let response = try await next(request, context)
		
		do {
			willCheck?(request)
			try await checkRateLimitFor(request: request)
			didCheck?(request)
		} catch let abort as HTTPError {
			let errorMetadata = ErrorMetadata()
			
			switch abort.status {
				case .tooManyRequests:
					didFailWithTooManyRequest?(request, response, errorMetadata)
					
					throw HTTPError(.tooManyRequests,
									headers: errorMetadata.httpHeaders,
									message: errorMetadata.reason)
				default:
					didFail?(request, response, abort, errorMetadata)
					
					throw HTTPError(.badRequest,
									headers: errorMetadata.httpHeaders,
									message: errorMetadata.reason)
			}
		}

		return response
	}
	
	private func checkRateLimitFor(request: Request) async throws {
		try await algorithm.checkRequest(request)
	}
}

public extension Checkpoint {
	final class ErrorMetadata {
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
}

extension Checkpoint {
	enum HTTPErrorDescription {
		static let unauthorized = "X-Api-Key header not available in the request"
		static let rateLimitReached = "You have exceed your ApiKey network requests rate"
	}
}
