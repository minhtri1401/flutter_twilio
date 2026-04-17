import Foundation

/// Mutable state shared by all the iOS handlers. Lives on the
/// [FlutterTwilioPlugin] instance. Handlers hold a reference to it so they
/// can read / mutate call / audio state without round-tripping through the
/// plugin.
final class TVPluginState {
    var accessToken: String?

    /// Twilio identity used as a fallback when `call.from` is nil.
    var identity: String = "alice"
    /// Last-dialed address, used as a fallback when `call.to` is nil.
    var callTo: String = ""

    /// Latest outgoing-call intent. Stored here so the CallKit delegate can
    /// pick it up when `CXStartCallAction` fires.
    var callArgs: [String: AnyObject] = [:]
    /// Whether the current call is outgoing. Set true by `place(...)`, reset in `callDisconnected`.
    var callOutgoing: Bool = false
    /// Set to true when the user hangs up locally, so we don't double-report the end to CallKit.
    var userInitiatedDisconnect: Bool = false

    /// Mic / hold / speaker flags, mirrored to `CXSetMutedCallAction` / `CXSetHeldCallAction`.
    var isMuted: Bool = false
    var isOnHold: Bool = false
    var isSpeakerOn: Bool = false

    /// Start-time of the current call, captured on `callDidConnect`.
    var callStartedAtMillis: Int64 = 0
}
