//
//  LeakingBucket.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 11/12/24.
//

import Foundation
import Logging
import Hummingbird
@preconcurrency import RediStack

/**
 LeakingBucket can be described as follows:
 
 1. Bucket has capacity of b tokens. Let’s say 10 tokens.
 2. When a request comes in, we add 1 token to the bucket.
 3. If the bucket is full, we reject the request and return a 429 status code.
 4. If the bucket is not full, we allow the request and add 1 token from the bucket.
 5. Tokens are removed at a fixed rate of r tokens per second. Let’s say 1 token per second.
*/
public actor LeakingBucket {
	private let configuration: LeakingBucketConfiguration
	public let storage: PersistDriver
	public let logging: Logger?
	
	private var timer: Timer?
	private var keys = Set<String>()
	
	public init(configuration: () -> LeakingBucketConfiguration, storage: StorageAction, logging: LoggerAction? = nil) {
		self.configuration = configuration()
		self.storage = storage()
		self.logging = logging?()
		self.timer = startWindow(havingDuration: self.configuration.timeWindowDuration.inSeconds,
									   performing: resetWindow)
	}
	
	deinit {
		timer?.invalidate()
	}
}

extension LeakingBucket: WindowBasedAlgorithm {
	public func checkRequest(_ request: Request) async throws {
		guard let requestKey = try? valueFor(field: configuration.appliedField, in: request, inside: configuration.scope) else {
			return
		}
		
		keys.insert(requestKey)
		
		let tokenList = try await storage.get(key: requestKey, as: TokenList.self) ?? TokenList()
		
		// 1. New request, add one token to the bucket
		await tokenList.addToken()
		
		// 2. If buckes is empty, throw an error
		if await tokenList.count > configuration.bucketSize {
			throw HTTPError(.tooManyRequests)
		} else {
			do {
				try await storage.set(key: requestKey, value: tokenList)
			} catch let persistentError {
				logging?.error("🚨 Problem setting key \(requestKey) to value \(configuration.bucketSize): \(persistentError.localizedDescription)")
			}
		}
	}
	
	public func resetWindow() throws {
		keys.forEach { key in
			Task(priority: .userInitiated) {
				let redisKey = RedisKey(key)
				
				if let tokenList = try await storage.get(key: key, as: TokenList.self) {
					var newBucketSize = 0
					let currentTokenListCount = await tokenList.count
					
					let deleteTokensCount = currentTokenListCount < configuration.tokenRemovingRate ? 0 : (currentTokenListCount - configuration.tokenRemovingRate)
					
					await tokenList.removeTokens(count: deleteTokensCount)
					try await storage.set(key: key, value: tokenList)
				}
			}
		}
	}
}
