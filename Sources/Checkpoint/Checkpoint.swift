//
//  Checkpoint.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Hummingbird
import HTTPTypes

public typealias CheckpointHandler = (Request) -> Void
public typealias CheckpointRateLimitHandler = (Request, Response, ErrorMetadata) -> Void
public typealias CheckpointErrorHandler = (Request, Response, HTTPError, ErrorMetadata) -> Void

public final class Checkpoint<Context: RequestContext>: RouterMiddleware  {
	private let algorithm: any Algorithm
	
	public var willCheck: CheckpointHandler?
	public var didCheck: CheckpointHandler?
	public var didFailWithTooManyRequest: CheckpointRateLimitHandler?
	public var didFail: CheckpointErrorHandler?
	
	public init(using algorithm: some Algorithm) {
		self.algorithm = algorithm
	}
	
	public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
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
