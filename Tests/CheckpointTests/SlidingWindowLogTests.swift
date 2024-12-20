//
//  SlidingWindowLogTests.swift
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

@Suite("Sliding Window Log tests suite.")
struct SlidingWindowLogTests {
	@Test("", .tags(.slidingWindowLog))
	func testSlidingWindowLog() throws {
		let slidingWindowLogConfiguration = SlidingWindowLogConfiguration(requestPerWindow: 10,
																		  windowDuration: .minutes(count: 2))
		
		let slidingWindowLog = try makeSlidingWindowLogWith(configuration: slidingWindowLogConfiguration)
		let checkpoint = Checkpoint(using: slidingWindowLog)
		
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
	
	@Test("HTTP Header", .tags(.slidingWindowLog))
	func testSlidingWindowLogWithHeader() throws {
		let slidingWindowLogConfiguration = SlidingWindowLogConfiguration(requestPerWindow: 10,
																		  windowDuration: .minutes(count: 2),
																		  appliedTo: .header(key: "X-ApiKey"))
		
		let slidingWindowLog = try makeSlidingWindowLogWith(configuration: slidingWindowLogConfiguration)
		let checkpoint = Checkpoint(using: slidingWindowLog)
		
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
	
	@Test("", .tags(.slidingWindowLog))
	func testSlidingWindowLogScopeApiWithHeader() throws {
		let slidingWindowLogConfiguration = SlidingWindowLogConfiguration(requestPerWindow: 10,
																		  windowDuration: .minutes(count: 2),
																		  appliedTo: .header(key: "X-ApiKey"),
																		  inside: .endpoint)
		
		let slidingWindowLog = try makeSlidingWindowLogWith(configuration: slidingWindowLogConfiguration)
		let checkpoint = Checkpoint(using: slidingWindowLog)
		
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
	
	@Test("", .tags(.slidingWindowLog))
	func testSlidingWindowLogResponse() throws {
		let slidingWindowLogConfiguration = SlidingWindowLogConfiguration(requestPerWindow: 10,
																		  windowDuration: .minutes(count: 2),
																		  appliedTo: .header(key: "X-ApiKey"),
																		  inside: .endpoint)
		
		let slidingWindowLog = try makeSlidingWindowLogWith(configuration: slidingWindowLogConfiguration)
		let checkpoint = Checkpoint(using: slidingWindowLog)
		
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
	
	@Test("", .tags(.slidingWindowLog))
	func testSlidingWindowLogWithScopeHeader() throws {
		let slidingWindowLogConfiguration = SlidingWindowLogConfiguration(requestPerWindow: 10,
																		  windowDuration: .minutes(count: 2),
																		  inside: .endpoint)
		let slidingWindowLog = try makeSlidingWindowLogWith(configuration: slidingWindowLogConfiguration)
		let checkpoint = Checkpoint(using: slidingWindowLog)
		
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
	@Tag static var slidingWindowLog: Tag
}

extension SlidingWindowLogTests {
	private func makeRateLimitHeader() throws -> HTTPFields {
		var apiHeaders = HTTPFields()
		
		let fieldName = try #require( HTTPField.Name("X-ApiKey"))
		let apiRateHeader = HTTPField(name: fieldName, value: "fitomad")
		
		apiHeaders.append(apiRateHeader)
		
		return apiHeaders
	}
	
	private func makeSlidingWindowLogWith(configuration: SlidingWindowLogConfiguration) throws -> SlidingWindowLog {
		let redis = try #require(
			try? RedisConnectionPoolService(
				RedisConfiguration(hostname: "localhost", port: 6379),
				logger: Logger(label: "Redis.SlidingWindowLogTests")
			)
		)
		
		let slidingWindowLogAlgorithm = SlidingWindowLog {
			configuration
		} storage: {
			redis.pool
		} logging: {
			Logger(label: "tests./sliding_window_log")
		}
		
		return slidingWindowLogAlgorithm
	}
	
	enum Constants {
		static let endpoint = "checkpoint/sliding-window-log"
		static let endpointRouterPath: RouterPath = RouterPath(Constants.endpoint)
	}
}
