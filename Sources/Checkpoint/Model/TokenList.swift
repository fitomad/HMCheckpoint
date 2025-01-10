//
//  TokenList.swift
//  Checkpoint
//
//  Created by Adolfo Vera Blasco on 9/1/25.
//


actor TokenList: @preconcurrency Codable, Sendable {
	private var elements: [Token]
    
    var isEmpty: Bool {
        elements.isEmpty
    }
    
    var count: Int {
        elements.count
    }
	
	init() {
		elements = [Token]()
	}
	
	init(elementsCount: Int) {
		elements = [Token](repeating: Token(), count: elementsCount)
	}
    
    func addToken() {
        let newToken = Token()
        elements.append(newToken)
    }
	
	func appendTokens(_ newTokens: [Token]) {
		elements.append(contentsOf: newTokens)
	}
    
    func pop() {
		guard elements.isEmpty == false else {
			return
		}
		
        elements.remove(at: 0)
    }
    
    func removeTokensPrevious(to timeWindow: TimeWindow) {
        elements.removeAll(where: { token in 
            token.timestamp.isPrevious(to: timeWindow)
        })
    }
	
	func removeTokens(count: Int) {
		guard count < elements.count else {
			return
		}
		
		elements.removeSubrange(0 ..< count)
	}
    
    func removeAll() {
        elements.removeAll()
    }
}
