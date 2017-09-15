//
//  Session.swift
//  Squirrel
//
//  Created by Filip Klembara on 9/14/17.
//

import Foundation
import SquirrelJSONEncoding
import PathKit
import SquirrelConfig

public protocol SessionProtocol {
    var sessionID: String { get }
    var expiry: Date { get }

    subscript(key: String) -> JSON? { get set }
}

struct Session: SessionProtocol {

    private var data: [String: JSON] = [:]

    var sessionID: String

    var expiry: Date

    init(id: String, expiry: Date, data: [String: JSON] = [:]) {
        self.sessionID = id
        self.expiry = expiry
        self.data = data
    }

    func store() -> Bool {
        let file: Path = SessionConfig.storage + "\(sessionID).session"
        let json = JSON(from: data).serialized
        try file.write(json)
    }

    deinit {
        <#statements#>
    }

    subscript(key: String) -> JSON? {
        get {
            return data[key]
        }
        set(value) {
            data[key] = value
        }
    }

}

protocol SessionBuilder {
    func new(for request: Request) -> SessionProtocol?

    func get(for request: Request) -> SessionProtocol?
}

struct SessionConfig {
    static let sessionName = "SquirrelSession"

    static let defaultExpiry = 60.0 * 60.0 * 24.0 * 7.0

    static let userAgent = "user-agent"

    static let storage = squirrelConfig.session
}

struct SessionManager: SessionBuilder {


    func new(for request: Request) -> SessionProtocol? {
        guard let userAgent = request.getHeader(for: SessionConfig.userAgent) else {
            return nil
        }
        let id = randomString()

        return Session(id: id, expiry: Date().addingTimeInterval(SessionConfig.defaultExpiry))
    }

    func get(for request: Request) -> SessionProtocol? {
        guard let userAgent = request.getHeader(for: SessionConfig.userAgent) else {
            return nil
        }
        guard let id = request.getCookie(for: SessionConfig.sessionName) else {
            return nil
        }
        return Session(id: id, expiry: Date().addingTimeInterval(SessionConfig.defaultExpiry))
    }
}

public struct SessionMiddleware: Middleware {
    private let sessionManager: SessionBuilder = SessionManager()
    public func respond(to request: Request, next: (Request) throws -> Any) throws -> Any {
        let session: SessionProtocol
        if let sess = sessionManager.get(for: request) {
            // Session.isValid
            session = sess
        } else {
            guard let sess = sessionManager.new(for: request) else {
                return HTTPError(status: .badRequest, description: "Missing \(SessionConfig.userAgent) header")
            }
            session = sess
        }
        request.session = session
        let res = try next(request)
        let response = try Response.parseAnyResponse(any: res)
        response.cookies[SessionConfig.sessionName] = "\(session.sessionID); Path=\"/\"; HTTPOnly"
        return response
    }

    public init() {
        
    }
}

/// Random string generator thanks to Fattie
///
/// Taken from
/// [stack overflow](https://stackoverflow.com/questions/26845307/generate-random-alphanumeric-string-in-swift)
///
/// - Parameter length: Generated string lenght
/// - Returns: Random string
func randomString(length: Int = 32) -> String {
    enum s {
        static let c = Array("abcdefghjklmnopqrstuvwxyz012345789")
        static let k = UInt32(c.count)
    }

    var result = [Character](repeating: "a", count: length)

    for i in 0..<length {
        let r = Int(arc4random_uniform(s.k))
        result[i] = s.c[r]
    }

    return String(result)
}