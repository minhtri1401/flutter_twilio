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
    static func of(_ code: String, _ message: String, _ details: [String: Any?] = [:]) -> PigeonError {
        PigeonError(code: code, message: message, details: details)
    }

    static func fromTwilio(_ err: Error) -> PigeonError {
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
}
