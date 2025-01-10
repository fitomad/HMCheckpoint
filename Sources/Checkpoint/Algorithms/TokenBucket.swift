//
//  TokenBucket.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Foundation
import Logging
import Hummingbird
import RediStack


/// For example, the token bucket capacity is 4 above.
/// Every second, the refiller adds 1 token to the bucket.
/// Extra tokens will overflow once the bucket is full.
///
/// 1. We take 1 token out for each request and if there are enough tokens, then the request is processed.
/// 2. The request is dropped if there aren’t enough tokens.
public actor TokenBucket {
	private let configuration: TokenBucketConfiguration
	public let storage: any PersistDriver
	public let logging: Logger?
	
	private var timer: Timer?
	private var keys = Set<String>()
	
	public init(configuration: () -> TokenBucketConfiguration, storage: StorageAction, logging: LoggerAction? = nil) {
		self.configuration = configuration()
		self.storage = storage()
		self.logging = logging?()
		
		self.timer = startWindow(havingDuration: self.configuration.refillTimeInterval.inSeconds,
									   performing: resetWindow)
	}
	
	deinit {
		timer?.invalidate()
	}
}

extension TokenBucket: WindowBasedAlgorithm {
	public func checkRequest(_ request: Request) async throws {
		guard let requestKey = try? valueFor(field: configuration.appliedField, in: request, inside: configuration.scope) else {
			return
		}
		
		keys.insert(requestKey)
		
		var tokenList = try await storage.get(key: requestKey, as: TokenList.self)
		
		if tokenList == nil {
			tokenList = TokenList(elementsCount: configuration.bucketSize)
		}
		
		// 1. New request, remove one token from the bucket
		await tokenList?.pop()
		// 2. If buckes is empty, throw an error
		if let tokenList, await tokenList.isEmpty {
			throw HTTPError(.tooManyRequests)
		}
		
		// Save the bucket with the current status
		try await storage.set(key: requestKey, value: tokenList)
	}
	
	public func resetWindow() throws {
		keys.forEach { key in
			Task(priority: .userInitiated) {
				let tokenList = try await storage.get(key: key, as: TokenList.self)
				let tokensCount = await tokenList?.count ?? 0
				
				
				
				let newRefillSize = switch tokensCount {
					case ...0:
						0 - tokensCount
					case configuration.bucketSize...:
						configuration.bucketSize - tokensCount
					default:
						configuration.refillTokenRate
				}

				
				let refillTokens = [Token](repeating: Token(), count: newRefillSize)
				await tokenList?.appendTokens(refillTokens)
				
				try await storage.set(key: key, value: tokenList)
			}
		}
	}
}

extension TokenBucket {
	enum Constants {
		static let KeyName = "TokenBucket-Key"
	}
}
