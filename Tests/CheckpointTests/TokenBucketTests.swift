//
//  TokenBucketTests.swift
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

@Suite("Token Bucket tests")
struct TokenBucketTests {
	@Test("", .tags(.tokenBucket))
	func testTokenBucket() throws {
		let basicConfiguration = TokenBucketConfiguration(bucketSize: 10,
														  refillRate: 0,
														  refillTimeInterval: .seconds(count: 20))
		
		let tokenBucket = try makeTokenBucketWith(configuration: basicConfiguration)
		
		let router = Router()
		router.add(middleware: Checkpoint(using: tokenBucket))
		
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
	
	@Test("HTTP Header", .tags(.tokenBucket))
	func testTokenBucketWithHeader() throws {
		let headerConfiguration = TokenBucketConfiguration(bucketSize: 10,
														   refillRate: 0,
														   refillTimeInterval: .seconds(count: 20),
														   appliedTo: .header(key: "X-ApiKey"))
		
		let tokenBucket = try makeTokenBucketWith(configuration: headerConfiguration)
		
		let router = Router()
		router.add(middleware: Checkpoint(using: tokenBucket))
		
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
	
	@Test("", .tags(.tokenBucket))
	func testTokenBucketWithScopeApiHeader() throws {
		let scopedTokenConfiguration = TokenBucketConfiguration(bucketSize: 10,
																	refillRate: 0,
																	refillTimeInterval: .seconds(count: 20),
																	appliedTo: .header(key: "X-ApiKey"),
																	inside: .endpoint)
		
		let tokenBucket = try makeTokenBucketWith(configuration: scopedTokenConfiguration)
		
		let router = Router()
		router.add(middleware: Checkpoint(using: tokenBucket))
		
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
	
	@Test("", .tags(.tokenBucket))
	func testTokenBucketResponse() throws {
		let tokenConfiguration = TokenBucketConfiguration(bucketSize: 10,
														  refillRate: 0,
														  refillTimeInterval: .seconds(count: 20),
														  appliedTo: .header(key: "X-ApiKey"),
														  inside: .endpoint)
		
		
		let tokenBucket = try makeTokenBucketWith(configuration: tokenConfiguration)
		
		let checkpoint = Checkpoint<BasicRequestContext>(using: tokenBucket)
		
		checkpoint.didFailWithTooManyRequest = { (request, response, metadata) in
			metadata.headers = [
				"X-RateLimit" : "Failure for request \(request.description)"
			]
		}
		
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
	@Tag static var tokenBucket: Tag
}

extension TokenBucketTests {
	private func makeRateLimitHeader() throws -> HTTPFields {
		var apiHeaders = HTTPFields()
		
		let fieldName = try #require( HTTPField.Name("X-ApiKey"))
		let apiRateHeader = HTTPField(name: fieldName, value: "fitomad#6")
		
		apiHeaders.append(apiRateHeader)
		
		return apiHeaders
	}
	
	private func makeTokenBucketWith(configuration: TokenBucketConfiguration) throws -> TokenBucket {
		let testRedisConfiguration = try #require(try RedisConfiguration(hostname: "localhost", port: 6379))
		
		let tokenbucketAlgorithm = TokenBucket {
			configuration
		} storage: {
			let redis = RedisConnectionPoolService(
					testRedisConfiguration,
					logger: Logger(label: "Redis.TokenBucketTests")
			)
			
			return redis.pool
		} logging: {
			Logger(label: "tests./token_bucket")
		}
		
		return tokenbucketAlgorithm
	}
	
	enum Constants {
		static let endpoint = "checkpoint/token-bucket"
		static let endpointRouterPath: RouterPath = RouterPath(Constants.endpoint)
	}
}
