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
/// • We take 1 token out for each request and if there are enough tokens, then the request is processed.
/// • The request is dropped if there aren’t enough tokens.
public actor TokenBucket {
	private let configuration: TokenBucketConfiguration
	public let storage: RedisConnectionPool
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
	
	private func preparaStorageFor(key: RedisKey) async {
		do {
			try await storage.set(key, to: configuration.bucketSize).get()
		} catch {
			logging?.error("🚨 Problem setting key \(key.rawValue) to value \(configuration.bucketSize)")
		}
	}
}

extension TokenBucket: WindowBasedAlgorithm {
	public func checkRequest(_ request: Request) async throws {
		guard let requestKey = try? valueFor(field: configuration.appliedField, in: request, inside: configuration.scope) else {
			return
		}
		
		keys.insert(requestKey)
		let redisKey = RedisKey(requestKey)
		
		let keyExists = try await storage.exists(redisKey).get()
		
		if keyExists == 0 {
			await preparaStorageFor(key: redisKey)
		}
		
		// 1. New request, remove one token from the bucket
		let bucketItemsCount = try await storage.decrement(redisKey).get()
		// 2. If buckes is empty, throw an error
		if bucketItemsCount < 0 {
			throw HTTPError(.tooManyRequests)
		}
	}
	
	public func resetWindow() throws {
		keys.forEach { key in
			Task(priority: .userInitiated) {
				let redisKey = RedisKey(key)
			
				let respValue = try await storage.get(redisKey).get()
			
				var newRefillSize = 0
				
				if let currentBucketSize = respValue.int {
					switch currentBucketSize {
						case ...0:
							newRefillSize -= currentBucketSize
						case configuration.bucketSize...:
							newRefillSize = configuration.bucketSize - currentBucketSize
						default:
							newRefillSize	= configuration.refillTokenRate
					}
				}
					
				_ = try await storage.increment(redisKey, by: newRefillSize).get()
			}
		}
	}
}

extension TokenBucket {
	enum Constants {
		static let KeyName = "TokenBucket-Key"
	}
}
