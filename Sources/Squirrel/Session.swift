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

/// Session protocol
public protocol SessionProtocol: Codable {
    /// Session ID
    var sessionID: String { get }
    /// Expiry of session
    var expiry: Date { get }

    func delete() -> Bool

    /// Returns data for given key from session
    ///
    /// - Parameter key: Key
    subscript(key: String) -> JSON? { get set }
}

func +=(lhs: inout SessionProtocol, rhs: [String: JSON]) {
    for (key, value) in rhs {
        lhs[key] = value
    }
}

struct Session: SessionProtocol {

    private var data: [String: JSON] = [:]

    let sessionID: String

    let expiry: Date

    let userAgent: String

    init(id: String, expiry: Date, userAgent: String) {
        self.sessionID = id
        self.expiry = expiry
        self.userAgent = userAgent
        let _ = store()
    }

    init?(id: String, userAgent: String) {
        let file = SessionConfig.storage + "\(id).session"
        guard let data: Data = try? file.read() else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let json = try? decoder.decode(Session.self, from: data) else {
            return nil
        }
        guard json.userAgent == userAgent && json.expiry > Date() else {
            try? file.delete()
            return nil
        }
        self = json
    }

    func store() -> Bool {
        let file: Path = SessionConfig.storage + "\(sessionID).session"
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            return false
        }
        return (try? file.write(data)) != nil
    }

    public func delete() -> Bool {
        let file: Path = SessionConfig.storage + "\(sessionID).session"
        return (try? file.delete()) != nil
    }

    subscript(key: String) -> JSON? {
        get {
            return data[key]
        }
        set(value) {
            data[key] = value
            let _ = store()
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

        return Session(
            id: id,
            expiry: Date().addingTimeInterval(SessionConfig.defaultExpiry),
            userAgent: userAgent)
    }

    func get(for request: Request) -> SessionProtocol? {
        guard let userAgent = request.getHeader(for: SessionConfig.userAgent) else {
            return nil
        }
        guard let id = request.getCookie(for: SessionConfig.sessionName) else {
            return nil
        }
        return Session(id: id, userAgent: userAgent)
    }
}

/// Session middleware
public struct SessionMiddleware: Middleware {

    private let sessionManager: SessionBuilder = SessionManager()

    private let dataInit: ((Request) throws -> [String: JSON])?

    /// Handle session for given request. If there is no session cookie,
    /// creates new session and put session cookie to response.
    ///
    /// - Parameters:
    ///   - request: Request
    ///   - next: Next middleware or Response handler
    /// - Returns: badRequest or Response from `next`
    /// - Throws: Custom error or parsing error
    public func respond(to request: Request, next: (Request) throws -> Any) throws -> Any {
        let session: SessionProtocol
        if let sess = sessionManager.get(for: request) {
            // Session.isValid
            session = sess
        } else {
            guard var sess = sessionManager.new(for: request) else {
                throw HTTPError(
                    status: .badRequest,
                    description: "Missing \(SessionConfig.userAgent) header")
            }
            if let dataInit = self.dataInit {
                sess += try dataInit(request)
            }
            session = sess
        }
        request.session = session
        let res = try next(request)
        let response = try Response.parseAnyResponse(any: res)
        response.cookies[SessionConfig.sessionName] = "\(session.sessionID); Path=\"/\"; HTTPOnly"
        return response
    }

    /// Constructs Session middleware
    ///
    /// - Parameter dataInit: This will init session data when new session is established
    public init(dataInit: ((Request) throws -> [String: JSON])? = nil) {
        self.dataInit = dataInit
    }
}

/// Random string generator thanks to Fattie
///
/// Taken from
/// [stack overflow](https://stackoverflow.com/questions/26845307)
///
/// - Parameter length: Generated string lenght
/// - Returns: Random string
func randomString(length: Int = 32) -> String {
    enum ValidCharacters {
        static let chars = Array("abcdefghjklmnopqrstuvwxyz012345789")
        static let count = UInt32(chars.count)
    }

    var result = [Character](repeating: "a", count: length)

    for i in 0..<length {
        let r = Int(arc4random_uniform(ValidCharacters.count))
        result[i] = ValidCharacters.chars[r]
    }

    return String(result)
}
