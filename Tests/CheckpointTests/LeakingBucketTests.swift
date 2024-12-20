//
//  LeakingBucketTests.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 13/12/24.
//

import Hummingbird
import HummingbirdTesting
import HummingbirdRedis
import Logging
import RediStack

import Testing
import HTTPTypes

@testable import Checkpoint

@Suite("Leaking Bucket tests suite.")
struct LeakingBucketTests {
	@Test("", .tags(.leakingBucket))
	func testLeakingBucket() throws {
		let leakingBucketConfiguration = LeakingBucketConfiguration(bucketSize: 10,
																	removingRate: 5,
																	removingTimeInterval: .minutes(count: 1))
		
		let leakingBucket = try makeLeakingBucketWith(configuration: leakingBucketConfiguration)
		let checkpoint = Checkpoint(using: leakingBucket)
		
		let router = Router()
		router.add(middleware: checkpoint)
		
		router.get(Constants.endpointRouterPath) { _, context in
			return "I'm not a teapot (yet)"
		}
		
		let app = Application(router: router)
		
		(0...20).forEach { index in
			Task {
				try await app.test(.router) { client in
					try await client.execute(
						uri: Constants.endpoint,
						method: .get,
						headers: [:],
						body: nil
					) { response in
						if index < 10 {
							#expect(response.status == .ok)
						} else {
							#expect(response.status == .tooManyRequests)
						}
					}
				}
			}
		}
	}
	
	@Test("HTTP Header", .tags(.leakingBucket))
	func testLeakingBucketWithHeader() throws {
		let leakingBucketConfiguration = LeakingBucketConfiguration(bucketSize: 10,
																	removingRate: 5,
																	removingTimeInterval: .minutes(count: 1),
																	appliedTo: .header(key: "X-ApiKey"))
		
		let leakingBucket = try makeLeakingBucketWith(configuration: leakingBucketConfiguration)
		let checkpoint = Checkpoint(using: leakingBucket)
		
		let router = Router()
		router.add(middleware: checkpoint)
		
		router.get(Constants.endpointRouterPath) { _, context in
			return "I'm not a teapot (yet)"
		}
		
		let app = Application(router: router)
		
		(0...20).forEach { index in
			Task {
				try await app.test(.router) { client in
					try await client.execute(
						uri: Constants.endpoint,
						method: .get,
						headers: makeRateLimitHeader(),
						body: nil
					) { response in
						if index < 10 {
							#expect(response.status == .ok)
						} else {
							#expect(response.status == .tooManyRequests)
						}
					}
				}
			}
		}
	}
	
	@Test("HTTP Header using Scope", .tags(.leakingBucket))
	func testLeakingBucketWithScopeApiHeader() throws {
		let leakingBucketConfiguration = LeakingBucketConfiguration(bucketSize: 10,
																	removingRate: 5,
																	removingTimeInterval: .minutes(count: 1),
																	appliedTo: .header(key: "X-ApiKey"),
																	inside :.endpoint)
		
		let leakingBucket = try makeLeakingBucketWith(configuration: leakingBucketConfiguration)
		let checkpoint = Checkpoint(using: leakingBucket)
		
		let router = Router()
		router.add(middleware: checkpoint)
		
		router.get(Constants.endpointRouterPath) { _, context in
			return "I'm not a teapot (yet)"
		}
		
		let app = Application(router: router)
		
		(0...20).forEach { index in
			Task {
				try await app.test(.router) { client in
					try await client.execute(
						uri: Constants.endpoint,
						method: .get,
						headers: makeRateLimitHeader(),
						body: nil
					) { response in
						if index < 10 {
							#expect(response.status == .ok)
						} else {
							#expect(response.status == .tooManyRequests)
						}
					}
				}
			}
		}
	}
	
	@Test("", .tags(.leakingBucket))
	func testLeakingBucketResponse() throws {
		let leakingBucketConfiguration = LeakingBucketConfiguration(bucketSize: 10,
																	removingRate: 5,
																	removingTimeInterval: .minutes(count: 1),
																	appliedTo: .header(key: "X-ApiKey"),
																	inside :.endpoint)
		
		let leakingBucket = try makeLeakingBucketWith(configuration: leakingBucketConfiguration)
		let checkpoint = Checkpoint(using: leakingBucket)
		
		let router = Router()
		router.add(middleware: checkpoint)
		
		router.get(Constants.endpointRouterPath) { _, context in
			return "I'm not a teapot (yet)"
		}
		
		let app = Application(router: router)
		
		(0...20).forEach { index in
			Task {
				try await app.test(.router) { client in
					let requiredRateLimitHeader = try #require(HTTPField.Name("X-RateLimit"))
					
					try await client.execute(
						uri: Constants.endpoint,
						method: .get,
						headers: makeRateLimitHeader(),
						body: nil
					) { response in
						if index < 10 {
							#expect(response.headers.contains(requiredRateLimitHeader) == false)
						} else {
							#expect(response.headers.contains(requiredRateLimitHeader))
						}
					}
				}
			}
		}
	}
	
	@Test("", .tags(.leakingBucket))
	func testLeakingBucketWithScopeHeader() throws {
		let leakingBucketConfiguration = LeakingBucketConfiguration(bucketSize: 10,
																	removingRate: 5,
																	removingTimeInterval: .minutes(count: 1),
																	inside: .endpoint)
		let leakingBucket = try makeLeakingBucketWith(configuration: leakingBucketConfiguration)
		let checkpoint = Checkpoint(using: leakingBucket)
		
		let router = Router()
		router.add(middleware: checkpoint)
		
		router.get(Constants.endpointRouterPath) { _, context in
			return "I'm not a teapot (yet)"
		}
		
		let app = Application(router: router)
		
		(0...20).forEach { index in
			Task {
				try await app.test(.router) { client in
					try await client.execute(
						uri: Constants.endpoint,
						method: .get,
						headers: makeRateLimitHeader(),
						body: nil
					) { response in
						if index < 10 {
							#expect(response.status == .ok)
						} else {
							#expect(response.status == .tooManyRequests)
						}
					}
				}
			}
		}
	}
}

extension Tag {
	@Tag static var leakingBucket: Tag
}

extension LeakingBucketTests {
	private func makeRateLimitHeader() throws -> HTTPFields {
		var apiHeaders = HTTPFields()
		
		let fieldName = try #require( HTTPField.Name("X-ApiKey"))
		let apiRateHeader = HTTPField(name: fieldName, value: "fitomad")
		
		apiHeaders.append(apiRateHeader)
		
		return apiHeaders
	}
	
	private func makeLeakingBucketWith(configuration: LeakingBucketConfiguration) throws -> LeakingBucket {
		let redis = try #require(
			try? RedisConnectionPoolService(
				RedisConfiguration(hostname: "localhost", port: 6379),
				logger: Logger(label: "Redis.LeakingBucketests")
			)
		)
		
		let leakingBucketAlgorithm = LeakingBucket {
			configuration
		} storage: {
			redis.pool
		} logging: {
			Logger(label: "tests./leaking_bucket")
		}
		
		return leakingBucketAlgorithm
	}
	
	enum Constants {
		static let endpoint = "checkpoint/leaking-bucket"
		static let endpointRouterPath: RouterPath = RouterPath(Constants.endpoint)
	}
}

