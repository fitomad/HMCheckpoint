//
//  FixedWindowCounterTests.swift
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

@Suite("Fixed Window Counter tests suite.")
struct FixedWindowCounterTests {
	@Test("", .tags(.fixedWindowCounter))
	func testFixedWindowCounter() async throws {
		let fixedWindowConfiguration = FixedWindowCounterConfiguration(requestPerWindow: 10,
																	   timeWindowDuration: .minutes(count: 2))
		
		
		let fixedWindowCounter = try makeFixedWindowCounterWith(configuration: fixedWindowConfiguration)
		let checkpoint = Checkpoint<BasicRequestContext>(using: fixedWindowCounter)
		
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
	
	@Test("HTTP Header", .tags(.fixedWindowCounter))
	func testFixedWindowCounterWithHeader() throws {
		let fixedConfiguration = FixedWindowCounterConfiguration(requestPerWindow: 10,
																 timeWindowDuration: .minutes(count: 2),
																 appliedTo: .header(key: "X-ApiKey"))
		
		
		let fixedWindowCounter = try makeFixedWindowCounterWith(configuration: fixedConfiguration)
		let checkpoint = Checkpoint<BasicRequestContext>(using: fixedWindowCounter)
		
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
	
	@Test("", .tags(.fixedWindowCounter))
	func testFixedWindowCounterScopeApiWithHeader() throws {
		let fixedConfiguration = FixedWindowCounterConfiguration(requestPerWindow: 10,
																 timeWindowDuration: .minutes(count: 2),
																 appliedTo: .header(key: "X-ApiKey"),
																 inside: .endpoint)
		
		
		let fixedWindowCounter = try makeFixedWindowCounterWith(configuration: fixedConfiguration)
		let checkpoint = Checkpoint<BasicRequestContext>(using: fixedWindowCounter)
		
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
	
	@Test("", .tags(.fixedWindowCounter))
	func testFixedWindowCounterResponse() throws {
		let fixedWindowConfiguration = FixedWindowCounterConfiguration(requestPerWindow: 10,
																	   timeWindowDuration: .minutes(count: 2),
																	   appliedTo: .header(key: "X-ApiKey"),
																	   inside: .endpoint)
		
		
		let fixedWindowCounter = try makeFixedWindowCounterWith(configuration: fixedWindowConfiguration)
		let checkpoint = Checkpoint<BasicRequestContext>(using: fixedWindowCounter)
		
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
	
	@Test("", .tags(.fixedWindowCounter))
	func testFixedWindowCounterWithScopeHeader() throws {
		let fixedWindowConfiguration = FixedWindowCounterConfiguration(requestPerWindow: 10,
																	   timeWindowDuration: .minutes(count: 2),
																	   inside: .endpoint)
		
		let fixedWindowCounter = try makeFixedWindowCounterWith(configuration: fixedWindowConfiguration)
		let checkpoint = Checkpoint<BasicRequestContext>(using: fixedWindowCounter)
		
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
	@Tag static var fixedWindowCounter: Tag
}

extension FixedWindowCounterTests {
	private func makeRateLimitHeader() throws -> HTTPFields {
		var apiHeaders = HTTPFields()
		
		let fieldName = try #require( HTTPField.Name("X-ApiKey"))
		let apiRateHeader = HTTPField(name: fieldName, value: "fitomad")
		
		apiHeaders.append(apiRateHeader)
		
		return apiHeaders
	}
	
	private func makeFixedWindowCounterWith(configuration: FixedWindowCounterConfiguration) throws -> FixedWindowCounter {
		let redis = try #require(
			try? RedisConnectionPoolService(
				RedisConfiguration(hostname: "localhost", port: 6379),
				logger: Logger(label: "Redis.FixedWindowCounterTests")
			)
		)
		
		let tokenbucketAlgorithm = FixedWindowCounter {
			configuration
		} storage: {
			return redis.pool
		} logging: {
			Logger(label: "tests./fixed_window_counter")
		}
		
		return tokenbucketAlgorithm
	}
	
	enum Constants {
		static let endpoint = "checkpoint/fixed-window-counter"
		static let endpointRouterPath: RouterPath = RouterPath(Constants.endpoint)
	}
}
