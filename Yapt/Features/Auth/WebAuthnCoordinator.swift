//
//  WebAuthnCoordinator.swift
//  Yapt
//
//  Coordinates WebAuthn passkey authentication with iOS
//

import Foundation
import AuthenticationServices
import OSLog

@MainActor
class WebAuthnCoordinator: NSObject, ObservableObject {
    private var continuation: CheckedContinuation<AuthenticationResponseJSON, Error>?

    /// Perform passkey authentication
    func authenticate(options: PublicKeyCredentialRequestOptions) async throws -> AuthenticationResponseJSON {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Decode challenge
            guard let challengeData = options.challenge.base64URLDecoded() else {
                continuation.resume(throwing: WebAuthnError.invalidChallenge)
                return
            }

            let rpID = options.rpId ?? Constants.WebAuthn.rpID

            // Create the provider
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)

            // Create assertion request
            let assertionRequest = provider.createCredentialAssertionRequest(challenge: challengeData)

            // Configure user verification
            if let userVerification = options.userVerification {
                switch userVerification {
                case "required":
                    assertionRequest.userVerificationPreference = .required
                case "preferred":
                    assertionRequest.userVerificationPreference = .preferred
                case "discouraged":
                    assertionRequest.userVerificationPreference = .discouraged
                default:
                    assertionRequest.userVerificationPreference = .preferred
                }
            }

            // Create controller
            let controller = ASAuthorizationController(authorizationRequests: [assertionRequest])
            controller.delegate = self
            controller.presentationContextProvider = self

            Logger.auth.info("Starting passkey authentication for RP: \(rpID)")
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension WebAuthnCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
                continuation?.resume(throwing: WebAuthnError.invalidCredentialType)
                continuation = nil
                return
            }

            do {
                let response = try convertToAuthenticationResponse(credential)
                Logger.auth.info("Passkey authentication successful")
                continuation?.resume(returning: response)
            } catch {
                Logger.auth.error("Failed to convert credential: \(error.localizedDescription)")
                continuation?.resume(throwing: error)
            }

            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            Logger.auth.error("Passkey authentication failed: \(error.localizedDescription)")

            let authError = error as? ASAuthorizationError
            switch authError?.code {
            case .canceled:
                continuation?.resume(throwing: WebAuthnError.userCanceled)
            case .failed:
                continuation?.resume(throwing: WebAuthnError.authenticationFailed)
            case .notHandled:
                continuation?.resume(throwing: WebAuthnError.notHandled)
            default:
                continuation?.resume(throwing: WebAuthnError.unknown(error))
            }

            continuation = nil
        }
    }

    private func convertToAuthenticationResponse(
        _ credential: ASAuthorizationPlatformPublicKeyCredentialAssertion
    ) throws -> AuthenticationResponseJSON {
        let rawId = credential.credentialID.base64URLEncodedString()
        let id = rawId

        let response = AuthenticatorAssertionResponse(
            clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
            authenticatorData: credential.rawAuthenticatorData.base64URLEncodedString(),
            signature: credential.signature.base64URLEncodedString(),
            userHandle: credential.userID?.base64URLEncodedString()
        )

        return AuthenticationResponseJSON(
            id: id,
            rawId: rawId,
            response: response
        )
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension WebAuthnCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the first window scene
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene

        return scene?.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Errors
enum WebAuthnError: LocalizedError {
    case invalidChallenge
    case invalidCredentialType
    case userCanceled
    case authenticationFailed
    case notHandled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidChallenge:
            return "Invalid authentication challenge"
        case .invalidCredentialType:
            return "Invalid credential type"
        case .userCanceled:
            return "Authentication was canceled"
        case .authenticationFailed:
            return "Authentication failed"
        case .notHandled:
            return "Authentication not handled"
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}
