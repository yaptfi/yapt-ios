//
//  WebAuthnCoordinator.swift
//  Yapt
//
//  Coordinates WebAuthn passkey authentication with iOS
//

import Foundation
import AuthenticationServices
import UIKit
import Combine
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
                Logger.auth.error("Failed to decode challenge from base64URL")
                continuation.resume(throwing: WebAuthnError.invalidChallenge)
                return
            }

            let rpID = options.rpId ?? Constants.WebAuthn.rpID

            // Debug logging for backend options
            Logger.auth.info("=== WebAuthn Authentication Debug ===")
            Logger.auth.info("RP ID: \(rpID)")
            Logger.auth.info("Challenge length: \(challengeData.count) bytes")
            Logger.auth.info("Timeout: \(options.timeout ?? 0) ms")
            Logger.auth.info("User verification: \(options.userVerification ?? "not specified")")

            // CRITICAL: Log allowCredentials to see if backend is filtering
            if let allowedCreds = options.allowCredentials {
                Logger.auth.info("allowCredentials count: \(allowedCreds.count)")
                for (index, cred) in allowedCreds.enumerated() {
                    Logger.auth.info("  Credential \(index): type=\(cred.type), id=\(cred.id.prefix(20))..., transports=\(cred.transports ?? [])")
                }
            } else {
                Logger.auth.info("allowCredentials: nil (any passkey allowed)")
            }
            Logger.auth.info("=====================================")

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

            Logger.auth.info("Calling ASAuthorizationController.performRequests() - passkey sheet should appear now")
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
            Logger.auth.error("=== Passkey Authentication Error ===")
            Logger.auth.error("Error: \(error.localizedDescription)")
            Logger.auth.error("Error domain: \((error as NSError).domain)")
            Logger.auth.error("Error code: \((error as NSError).code)")

            let authError = error as? ASAuthorizationError
            if let authError = authError {
                Logger.auth.error("ASAuthorizationError code: \(authError.code.rawValue)")

                switch authError.code {
                case .canceled:
                    Logger.auth.info("User canceled the passkey prompt")
                case .failed:
                    Logger.auth.error("Passkey authentication failed - possible reasons:")
                    Logger.auth.error("  - No passkeys available for this RP ID")
                    Logger.auth.error("  - Passkey provider (1Password/iCloud) not configured")
                    Logger.auth.error("  - Associated Domains not validated")
                case .notHandled:
                    Logger.auth.error("Passkey request not handled by system")
                case .unknown:
                    Logger.auth.error("Unknown passkey error")
                case .invalidResponse:
                    Logger.auth.error("Invalid response from passkey provider")
                case .notInteractive:
                    Logger.auth.error("Passkey request requires user interaction")
                case .matchedExcludedCredential:
                    Logger.auth.error("Matched excluded credential")
                @unknown default:
                    Logger.auth.error("Unrecognized ASAuthorization error: \(authError.code.rawValue)")
                }
            }
            Logger.auth.error("====================================")

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
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the first window scene
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
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
