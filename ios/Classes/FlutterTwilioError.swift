import Foundation
import TwilioVoice

/// Single source of truth for wire-format errors sent to Dart via Pigeon.
///
/// Throw the returned [PigeonError] from a VoiceHostApi method; Pigeon's
/// generated `wrapError` helper serializes it as a Dart `PlatformException`
/// with a stable `code`, matching the Android `FlutterError` Kotlin class.
///
/// (Swift's `FlutterError` is Objective-C and doesn't conform to `Error`, so
/// we tunnel all typed errors through `PigeonError` which does.)
enum FlutterTwilioError {

    // MARK: - Twilio error-code groupings
    //
    // These ranges are centralised here so TVCallDelegate, TVRegistrationHandler
    // and the call-continuation logic all agree on what counts as "invalid
    // token" vs. "connection error" vs. "twilio_sdk_error".

    /// Twilio access-token related failures: invalid token, expired, malformed,
    /// wrong audience, rejected by auth service.
    /// See `TVOError.h`: 20101–20107, 20151, 20157, 51007.
    static let tokenErrorCodes: Set<Int> = [
        20101, 20102, 20103, 20104, 20105, 20106, 20107,
        20151, 20157, 51007,
    ]

    /// Transport / network / signaling level failures. The call got as far as
    /// the SDK but the underlying socket, DNS or media plane gave up.
    /// Covers 31005 (connection), 31009 (transport), 31530 (DNS),
    /// 53001 (signalling), 53405 (media connection).
    static let connectionErrorCodes: Set<Int> = [
        31005, 31009, 31530, 53001, 53405,
    ]

    static func of(_ code: String, _ message: String, _ details: [String: Any?] = [:]) -> PigeonError {
        PigeonError(code: code, message: message, details: details)
    }

    /// Maps a Twilio SDK error to a [PigeonError]. Returns an `invalid_token`
    /// or `connection_error` when the NSError code lands in the corresponding
    /// set, else falls through to `twilio_sdk_error`.
    static func fromTwilio(_ err: Error) -> PigeonError {
        let ns = err as NSError
        let twilioCode = ns.userInfo["TVErrorCodeKey"] as? Int ?? ns.code
        let code = stableCodeFor(nsError: ns, twilioCode: twilioCode)
        return PigeonError(
            code: code,
            message: ns.localizedDescription,
            details: [
                "twilioCode": twilioCode,
                "twilioDomain": ns.domain,
                "nativeMessage": ns.localizedDescription,
            ]
        )
    }

    /// Like [fromTwilio] but hard-codes the `code` to `twilio_sdk_error` — used
    /// in the rare case where we want to bypass the stable-code mapping.
    static func rawTwilio(_ err: Error) -> PigeonError {
        let ns = err as NSError
        let twilioCode = ns.userInfo["TVErrorCodeKey"] as? Int ?? ns.code
        return PigeonError(
            code: "twilio_sdk_error",
            message: ns.localizedDescription,
            details: [
                "twilioCode": twilioCode,
                "twilioDomain": ns.domain,
                "nativeMessage": ns.localizedDescription,
            ]
        )
    }

    static func unknown(_ err: Error) -> PigeonError {
        let ns = err as NSError
        return PigeonError(
            code: "unknown",
            message: ns.localizedDescription,
            details: [
                "nativeMessage": ns.localizedDescription,
                "cause": String(describing: type(of: err)),
            ]
        )
    }

    /// Shared classifier used by the Call.Delegate, RegistrationHandler and
    /// `fromTwilio(_:)` so every surface emits the same stable code for the
    /// same NSError.
    static func stableCodeFor(nsError ns: NSError, twilioCode: Int) -> String {
        if tokenErrorCodes.contains(twilioCode) {
            return "invalid_token"
        }
        if connectionErrorCodes.contains(twilioCode) {
            return "connection_error"
        }
        if ns.domain == NSURLErrorDomain {
            return "connection_error"
        }
        return "twilio_sdk_error"
    }

    /// Details map commonly attached to error events so Dart can surface the
    /// underlying Twilio diagnostics.
    static func twilioDetails(_ err: Error) -> [String: Any?] {
        let ns = err as NSError
        let twilioCode = ns.userInfo["TVErrorCodeKey"] as? Int ?? ns.code
        return [
            "twilioCode": twilioCode,
            "twilioDomain": ns.domain,
            "nativeMessage": ns.localizedDescription,
        ]
    }
}
