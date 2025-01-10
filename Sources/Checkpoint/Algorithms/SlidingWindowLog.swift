//
//  SlidingWindowLog.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Foundation
import Logging
import Hummingbird
import RediStack

/// The Sliding Window Log rate-limit algorithim is based on the request count perfomed during a non fixed window time.
/// It works following this workflow:
///
/// 1. When new request comes in remove all outdated timestamps from cache. By outdated we mean timestamps that are older than window size.
/// 2. Add new timestamp to cache.
/// 3. If number of timestamps in cache is greater than limit reject request and return 429 status code.
/// 4. If lower than limit then accept request and return 200 status code.
public actor SlidingWindowLog {
	/// Configuration for the Sliding Window Log
	private let configuration: SlidingWindowLogConfiguration
	/// Redis database where we store the request timestamps
	public let storage: PersistDriver
	/// A Hummigbird logger object
	public let logging: Logger?
	
	/// Create a new Sliging Window Log with a given configuration, storage and a logger
	///
	/// - Parameters:
	/// - configuration: A `SlidingWindowLogConfiguration` object
	/// - storage: The `PersistentDriver` database instance created on Hummingbird
	/// - logging: A `Logger` object created on Hummingbird.
	public init(configuration: () -> SlidingWindowLogConfiguration, storage: StorageAction, logging: LoggerAction? = nil) {
		self.configuration = configuration()
		self.storage = storage()
		self.logging = logging?()
	}
}

extension SlidingWindowLog: Algorithm {	
	public func checkRequest(_ request: Request) async throws {
		guard let apiKey = try? valueFor(field: configuration.appliedField, in: request, inside: configuration.scope) else {
			throw HTTPError(.unauthorized, message: HTTPErrorDescription.unauthorized)
		}
		
		let tokenList = try await storage.get(key: apiKey, as: TokenList.self) ?? TokenList()
		
		// 1. Delete outdated request
		await tokenList.removeTokensPrevious(to: configuration.timeWindowDuration)
		
		// 2. Add the current request
		await tokenList.addToken()
		
		// 3. Get the number of request for this time window
		let timeWindowTokensCount = await tokenList.count
		
		// 4. If request count is greater...
		if timeWindowTokensCount > configuration.requestPerWindow {
			throw HTTPError(.tooManyRequests)
		}
	}
}
