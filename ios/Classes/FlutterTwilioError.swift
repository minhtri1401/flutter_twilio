import Foundation
import Flutter
import TwilioVoice

/// Single source of truth for wire-format errors sent to Dart via Pigeon.
/// Throw the returned FlutterError from a VoiceHostApi method; it lands as a
/// PlatformException on the Dart side with a stable `code`.
enum FlutterTwilioError {
    static func of(_ code: String, _ message: String, _ details: [String: Any?] = [:]) -> FlutterError {
        FlutterError(code: code, message: message, details: details)
    }

    static func fromTwilio(_ err: Error) -> FlutterError {
        let ns = err as NSError
        let twilioCode = ns.userInfo["TVErrorCodeKey"] as? Int ?? ns.code
        return FlutterError(
            code: "twilio_sdk_error",
            message: ns.localizedDescription,
            details: [
                "twilioCode": twilioCode,
                "twilioDomain": ns.domain,
                "nativeMessage": ns.localizedDescription,
            ]
        )
    }

    static func unknown(_ err: Error) -> FlutterError {
        let ns = err as NSError
        return FlutterError(
            code: "unknown",
            message: ns.localizedDescription,
            details: [
                "nativeMessage": ns.localizedDescription,
                "cause": String(describing: type(of: err)),
            ]
        )
    }
}
