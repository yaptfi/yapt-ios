//
//  WebAuthnModels.swift
//  Yapt
//
//  WebAuthn request/response models matching @simplewebauthn spec
//

import Foundation

// MARK: - Login Request
struct LoginGenerateOptionsRequest: Codable {
    let username: String
}

// MARK: - WebAuthn Options (from server)
struct PublicKeyCredentialRequestOptions: Codable {
    let challenge: String
    let timeout: Int?
    let rpId: String?
    let allowCredentials: [PublicKeyCredentialDescriptor]?
    let userVerification: String?
}

struct PublicKeyCredentialDescriptor: Codable {
    let type: String
    let id: String  // base64url encoded
    let transports: [String]?
}

// MARK: - Authentication Response (to server)
struct AuthenticationResponseJSON: Codable {
    let id: String  // base64url
    let rawId: String  // base64url
    let response: AuthenticatorAssertionResponse
    let type: String  // "public-key"
    let clientExtensionResults: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case id, rawId, response, type, clientExtensionResults
    }

    init(id: String, rawId: String, response: AuthenticatorAssertionResponse, type: String = "public-key") {
        self.id = id
        self.rawId = rawId
        self.response = response
        self.type = type
        self.clientExtensionResults = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(rawId, forKey: .rawId)
        try container.encode(response, forKey: .response)
        try container.encode(type, forKey: .type)
    }
}

struct AuthenticatorAssertionResponse: Codable {
    let clientDataJSON: String  // base64url
    let authenticatorData: String  // base64url
    let signature: String  // base64url
    let userHandle: String?  // base64url (optional)
}

// MARK: - Base64URL Encoding
extension Data {
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension String {
    func base64URLDecoded() -> Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
